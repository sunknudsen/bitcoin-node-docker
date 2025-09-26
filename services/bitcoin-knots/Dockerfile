FROM debian:bookworm-slim AS build
ARG BITCOIN_KNOTS_VERSION
RUN apt-get update \
  && apt-get install --yes curl git gnupg \
  && curl --fail --remote-name https://bitcoinknots.org/files/${BITCOIN_KNOTS_VERSION%%.*}.x/${BITCOIN_KNOTS_VERSION}/SHA256SUMS \
  && curl --fail --remote-name https://bitcoinknots.org/files/${BITCOIN_KNOTS_VERSION%%.*}.x/${BITCOIN_KNOTS_VERSION}/SHA256SUMS.asc \
  && curl --fail --remote-name https://bitcoinknots.org/files/${BITCOIN_KNOTS_VERSION%%.*}.x/${BITCOIN_KNOTS_VERSION}/bitcoin-${BITCOIN_KNOTS_VERSION}-aarch64-linux-gnu.tar.gz \
  && git clone https://github.com/bitcoinknots/guix.sigs.git \
  && gpg --import guix.sigs/builder-keys/*.gpg \
  && gpg --verify SHA256SUMS.asc \
  && shasum --algorithm 256 --check SHA256SUMS --ignore-missing \
  && tar --extract --gzip --file bitcoin-${BITCOIN_KNOTS_VERSION}-aarch64-linux-gnu.tar.gz

FROM debian:bookworm-slim
ARG BITCOIN_KNOTS_VERSION
COPY --from=build bitcoin-${BITCOIN_KNOTS_VERSION}/bin/bitcoin-cli /usr/local/bin/bitcoin-cli
COPY --from=build bitcoin-${BITCOIN_KNOTS_VERSION}/bin/bitcoind /usr/local/bin/bitcoind
RUN addgroup bitcoin \
  && adduser --disabled-password --gecos "" --ingroup bitcoin bitcoin
RUN mkdir -p /var/lib/bitcoind \
  && chown bitcoin:bitcoin /var/lib/bitcoind