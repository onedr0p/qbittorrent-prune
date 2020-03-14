FROM alpine:3.11

RUN apk add --no-cache bash curl tini procps jq ca-certificates

COPY docker-entrypoint.sh /
COPY script.sh /usr/bin

ENTRYPOINT [ "/sbin/tini", "-g", "-s", "--" ]
CMD ["/docker-entrypoint.sh"]

