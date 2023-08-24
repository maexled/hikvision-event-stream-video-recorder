#!/bin/bash

# List of environment variables to check
ENV_VARS="ADDRESS USERNAME PASSWORD"

# Flag to indicate if all variables are set
all_vars_set=true

# Loop through the list of variables and check if all are set
for var_name in $ENV_VARS; do
    if [ -z "$(eval echo \$"$var_name")" ]; then
        echo "Error: Variable '$var_name' is not set."
        all_vars_set=false
    fi
done

# Exit the script with an error if not all variables are set
if [ "$all_vars_set" == false ]; then
    exit 1
fi

alertStream="http://$ADDRESS/ISAPI/Event/notification/alertStream"
STREAM_PORT=${STREAM_PORT:-554}
STREAMING_CHANNEL=${STREAMING_CHANNEL:-1}
RECORDING_FOLDER=${RECORDING_FOLDER:-"/app/recordings"}

mkdir -p "$RECORDING_FOLDER"

streamURL=rtsp://$USERNAME:$PASSWORD@$ADDRESS:$STREAM_PORT//Streaming/Channels/1

START_OF_BLOCK_MARKER='<EventNotificationAlert'
END_OF_BLOCK_MARKER='</EventNotificationAlert>'
HEARTBEAT_EVENT_TYPE='videoloss'
HEARBEAT_EVENT_STATE='inactive'

LAST_ACTION=0
RECORDING=false

XMLNS='http://www.hikvision.com/ver20/XMLSchema'
beginsWith() { case $2 in "$1"*) true;; *) false;; esac; }
log() {
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local log_level="$1"
    local message="$2"
    echo "[$timestamp] [$log_level] $message"
}
# Function to handle recording
handle_recording() {
    local output_file="$1"
    local recording_start_time="$2"
    local last_action="$3"

    duration=$((last_action - recording_start_time + 3))
    mv "$output_file" "$output_file".tmp && {
        # Process the recording using the local output_file
        ffmpeg -nostdin -i "$output_file.tmp" -t $duration -c copy "$output_file"
        rm "$output_file.tmp"
        log "DEBUG" "Reduced current output video $output_file to $duration seconds"
    } &
}

log "INFO" "Save recordings in folder $RECORDING_FOLDER"
log "INFO" "Stream-URL: $streamURL"

# Initialize a variable to hold the accumulated event block
event_block=""

# Establish the connection and continuously read data
curl -u "$USERNAME:$PASSWORD" --digest -N "$alertStream" 2>/dev/null | while IFS= read -r line; do
    cleaned_line=$line
    cleaned_line="${cleaned_line#"${cleaned_line%%[![:space:]]*}"}"
    cleaned_line="${cleaned_line%"${cleaned_line##*[![:space:]]}"}"

    if [[ "$cleaned_line" == "$END_OF_BLOCK_MARKER" ]]; then
        printf -v event_block "%s%s" "$event_block" "$cleaned_line"

        # Extract eventType using xmlstarlet
        eventType=$(echo "$event_block" | xmlstarlet sel -N ns="$XMLNS" -t -v "//ns:eventType" -)
        eventState=$(echo "$event_block" | xmlstarlet sel -N ns="$XMLNS" -t -v "//ns:eventState" -)

        # Heartbeat
        if [ "$eventType" == "$HEARTBEAT_EVENT_TYPE" ] && [ "$eventState" == "$HEARBEAT_EVENT_STATE" ]; then
            echo "Received heartbeat event" > /dev/null
        else
            log "INFO" "Received real event:"
            log "INFO" "Event Type: $eventType"
            log "INFO" "Event State: $eventState"
            echo ""

            # Check if recording should start
            current_time=$(date +%s)
            if [ "$eventState" == "active" ]; then
                LAST_ACTION=$current_time
            fi
            if [ "$RECORDING" == false ] && [ "$eventState" == "active" ]; then
                RECORDING=true
                RECORDING_START_TIME=$current_time

                DIR_DATE_NAME=$(date +'%Y/%m/%d')

                if [ ! -d "${RECORDING_FOLDER}/${DIR_DATE_NAME}" ]; then
                    mkdir -p "${RECORDING_FOLDER}/${DIR_DATE_NAME}"
                fi

                FILENAME="$(date +'%Y-%m-%d_%H-%M-%S').mp4"
                OUTPUT_FILE="${RECORDING_FOLDER}/${DIR_DATE_NAME}/${FILENAME}"
                log "INFO" "Start recording"
                ffmpeg -nostdin -rtsp_transport tcp -y -i "$streamURL" -c:v copy -c:a copy -strftime 1 "$OUTPUT_FILE" -loglevel panic &
            fi
        fi

        current_time=$(date +%s)
        if [ "$RECORDING" == true ] && [ "$((current_time - LAST_ACTION))" -gt 8 ]; then
            RECORDING=false
            pkill ffmpeg # Stop the ffmpeg process
            log "INFO" "Stop recording"
            
            # Cut the resulted video in right length
            handle_recording "$OUTPUT_FILE" "$RECORDING_START_TIME" "$LAST_ACTION"
        fi

        # Reset the accumulated event block for the next iteration
        event_block=""
    else
        # Start of XML
        if beginsWith "$START_OF_BLOCK_MARKER" "$cleaned_line"; then
            XMLNS=$(echo "$cleaned_line" | grep -o 'xmlns="[^"]*' | sed 's/xmlns="//')
            event_block=""
        fi
        printf -v event_block "%s%s" "$event_block" "$cleaned_line"
    fi
done