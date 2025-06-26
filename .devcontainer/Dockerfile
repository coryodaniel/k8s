FROM elixir:1.14

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --yes build-essential inotify-tools \
    && mix local.hex --force \
    && mix local.rebar --force

WORKDIR /app
