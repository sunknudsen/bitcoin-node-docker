FROM rust:slim-bookworm AS build
ARG ELECTRS_VERSION
RUN apt-get update \
  && apt-get install --yes build-essential git libclang-dev \
  && git clone https://github.com/romanz/electrs.git \
  && cd electrs \
  && git checkout ${ELECTRS_VERSION} \
  && cargo build --locked --no-default-features --release

FROM debian:bookworm-slim
COPY --from=build electrs/target/release/electrs /usr/local/bin/electrs
RUN addgroup electrs \
  && adduser --disabled-password --gecos "" --ingroup electrs electrs