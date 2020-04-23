FROM alpine:3.11
RUN apk add --no-cache bash curl tini jq ca-certificates
COPY qbittorrent-prune.sh /usr/local/bin/qbittorrent-prune
ENTRYPOINT [ "/sbin/tini", "--" ]
CMD ["qbittorrent-prune"]
