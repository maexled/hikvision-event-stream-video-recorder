# Hikvision Event Stream Video Recorder

This script observes Hikvision camera events and captures video accordingly.

## Requirements

- `bash`
- `curl`
- `ffmpeg`
- `xmlstarlet`

Make sure these dependencies are installed in your environment before running the script.

## Usage

Follow the instructions below to run the script:

1. Clone this repository to your local machine:

   ```bash
   git clone https://github.com/maexled/hikvision-event-stream-video-recorder.git
   ```

2. Navigate to the directory containing the script:

   ```bash
   cd hikvision-event-stream-video-recorder
   ```

3. Set the required environment variables: ADDRESS, USERNAME, and PASSWORD.

   ```bash
   bash event_stream_recorder.sh
   ```

## Environment Variables

Before running the script, you need to set the following environment variables:

- `ADDRESS`: The IP address of your camera.
- `USERNAME`: The username for accessing the camera.
- `PASSWORD`: The password for accessing the camera.
- `STREAM_PORT`: The port for the rtsp stream (optional, by default 554)
- `STREAMING_CHANNEL`: The streaming channel (optional, by default 1)
- `RECORDING_FOLDER`: The root folder where the recordings are saved into (optional, by default /app/recordings)
- `TZ`: The timezone (optional, but prefered to adapt to your timezone)

Alternatively, you can set them directly in the terminal before running the script.

## Running the Script in a Docker Container

   ```bash
   docker container run \
    -e ADDRESS=your_camera_ip \
    -e USERNAME=your_camera_username \
    -e PASSWORD=your_camera_password \
    -e TZ=Europe/Berlin \
    -v $(pwd)/recordings:/app/recordings \
    --name event-stream-recorder \
    ghcr.io/maexled/hikvision-event-stream-video-recorder
   ```

## License

This project is licensed under the MIT license.
