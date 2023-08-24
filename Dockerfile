FROM alpine:latest

LABEL maintainer="maexled <max@maexled.de>"

ENV LANG=C.UTF-8

RUN apk update && \
    apk add --no-cache \
    bash \
    curl \
    ffmpeg \
    tzdata \
    xmlstarlet && \
    rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

WORKDIR /app

COPY event_stream_recorder.sh /app/event_stream_recorder.sh

RUN chmod +x /app/event_stream_recorder.sh

VOLUME /app/recordings

CMD ["bash", "/app/event_stream_recorder.sh"]