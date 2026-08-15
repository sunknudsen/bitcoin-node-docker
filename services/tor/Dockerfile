FROM debian:bookworm-slim
ARG TOR_VERSION
RUN apt-get update \
  && apt-get install --yes curl gnupg \
  && curl -fsSL https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor > /usr/share/keyrings/tor.gpg \
  && echo "deb [arch=arm64 signed-by=/usr/share/keyrings/tor.gpg] https://deb.torproject.org/torproject.org bookworm main" > /etc/apt/sources.list.d/tor.list \
  && echo "deb-src [arch=arm64 signed-by=/usr/share/keyrings/tor.gpg] https://deb.torproject.org/torproject.org bookworm main" >> /etc/apt/sources.list.d/tor.list \
  && apt update \
  && apt install -y tor=${TOR_VERSION}-*
RUN addgroup tor \
  && adduser --disabled-password --gecos "" --ingroup tor tor
RUN chown tor:tor /var/lib/tor
# See https://2019.www.torproject.org/docs/tor-manual.html.en
COPY --chmod=644 torrc /etc/tor/torrc