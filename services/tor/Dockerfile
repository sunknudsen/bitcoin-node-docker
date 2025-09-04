FROM debian:bookworm-slim
RUN apt-get update \
  && apt-get install --yes curl gnupg \
  && curl -fsSL https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor > /usr/share/keyrings/tor.gpg \
  && echo "deb [arch=arm64 signed-by=/usr/share/keyrings/tor.gpg] https://deb.torproject.org/torproject.org bookworm main" > /etc/apt/sources.list.d/tor.list \
  && echo "deb-src [arch=arm64 signed-by=/usr/share/keyrings/tor.gpg] https://deb.torproject.org/torproject.org bookworm main" >> /etc/apt/sources.list.d/tor.list \
  && apt update \
  && apt install -y tor
RUN addgroup tor \
  && adduser --disabled-password --gecos "" --ingroup tor tor
RUN chown tor:tor /var/lib/tor
# See https://2019.www.torproject.org/docs/tor-manual.html.en
RUN cat > /etc/tor/torrc <<EOF
CookieAuthentication 1
ControlPort 172.18.0.2:9051
DataDirectory /var/lib/tor
SocksPolicy accept 172.18.0.3, reject *
SocksPort 172.18.0.2:9050
EOF