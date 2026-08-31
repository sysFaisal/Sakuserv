FROM debian:bookworm-slim
WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY nyobarust ./nyobarust
COPY .env ./.env

RUN chmod +x /app/nyobarust

ENV HOST=0.0.0.0
EXPOSE 2736

CMD ["./nyobarust"]
