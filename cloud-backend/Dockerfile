FROM rust:1-slim-bookworm AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*
COPY . .
RUN cargo build --release

FROM debian:bookworm-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/bloom-cloud-backend /app/server
EXPOSE 8000
ENV DJANGORS_PORT=8000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/healthz || exit 1
CMD ["/app/server"]
