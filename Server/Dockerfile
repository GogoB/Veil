FROM swift:6.1-noble AS build

WORKDIR /workspace
COPY Shared ./Shared
COPY Server ./Server
WORKDIR /workspace/Server
RUN swift build -c release --static-swift-stdlib

FROM ubuntu:noble
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl libjemalloc2 libvips-tools tzdata \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /workspace/Server/.build/release/VeilServer /usr/local/bin/VeilServer
COPY Server/docker-entrypoint.sh /usr/local/bin/veil-entrypoint
RUN chmod +x /usr/local/bin/veil-entrypoint \
    && mkdir -p /app/Public/uploads /app/.tmp-images

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/veil-entrypoint"]
