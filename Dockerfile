FROM alpine:latest

RUN apk add --no-cache bash wget

WORKDIR /app

COPY --chmod=+x . .

ENTRYPOINT ["./osm-diff-state.sh"]
