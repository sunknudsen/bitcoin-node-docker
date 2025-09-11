# bitcoin-node-docker

This [Docker Compose](https://docs.docker.com/compose/) template is used to run a Bitcoin full node on Apple silicon Mac running macOS storing blockchain data on external APFS (Encrypted) volume.

One can either use [Bitcoin Core](https://bitcoincore.org/) or [Bitcoin Knots](https://bitcoinknots.org/) and route traffic over Mullvad or Tor for additional privacy (Docker containers do not have direct Internet access, are isolated from macOS host and run read-only).

An [Electrs](https://github.com/romanz/electrs) server is the only exposed service to which [Electrum](https://electrum.org/) can connect on macOS via `127.0.0.1:50001`.

Using Mullvad is recommended for faster initial block download while using Tor is recommended when broadcasting transactions.

## Setup

### Step 1: clone repo

```console
git clone git@github.com:sunknudsen/bitcoin-node-docker.git
```

### Step 2: install [Homebrew](https://brew.sh/)

```console
$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

$ echo 'export PATH=$PATH:/opt/homebrew/bin' >> ~/.zshrc && source ~/.zshrc
```

### Step 3: disable Homebrew analytics

```console
$ brew analytics off
```

### Step 4: install dependencies

```console
$ brew install colima docker docker-compose
```

### Step 5: configure [Docker](https://docs.docker.com/)

```console
$ mkdir -p $HOME/.docker

$ cp config.json.sample $HOME/.docker/config.json
```

### Step 6: create folders on external volume

> Heads-up: replace `Docker` with external volume name.

> Heads-up: using APFS (Encrypted) volume is recommended.

```console
$ mkdir -p /Volumes/Docker/{bitcoind,electrs}
```

### Step 7: configure [Colima](https://github.com/abiosoft/colima)

> Heads-up: replace `Docker` with external volume name.

```console
$ export COLIMA_HOME=/Volumes/Docker

$ mkdir -p ${COLIMA_HOME}/bitcoin-node

$ cp colima.yaml.sample ${COLIMA_HOME}/bitcoin-node/colima.yaml

$ colima start \
  --profile bitcoin-node \
  --cpu 2 \
  --disk 2048 \
  --memory 4
```

### Step 8: configure `.env`

> Heads-up: use `BITCOIND_DB_CACHE="2048"` to set how much memory to allocate to database cache.

```console
cp .env.sample .env
```

## Usage

### Run Bitcoin Core and route traffic over Mullvad

Make sure colima is not running using `colima stop --profile bitcoin-node` and connect external volume. 

```console
$ export COLIMA_HOME=/Volumes/Docker

$ cp colima-mullvad.yaml.sample ${COLIMA_HOME}/bitcoin-node/colima.yaml

$ colima start --profile bitcoin-node

$ docker compose --profile bitcoin-core-over-mullvad up
```

### Run Bitcoin Core and route traffic over Tor

Make sure colima is not running using `colima stop --profile bitcoin-node` and connect external volume. 

```console
$ export COLIMA_HOME=/Volumes/Docker

$ cp colima-tor.yaml.sample ${COLIMA_HOME}/bitcoin-node/colima.yaml

$ colima start --profile bitcoin-node

$ docker compose --profile bitcoin-core-over-tor up
```

### Run Bitcoin Knots and route traffic over Mullvad

Make sure colima is not running using `colima stop --profile bitcoin-node` and connect external volume. 

```console
$ export COLIMA_HOME=/Volumes/Docker

$ cp colima-mullvad.yaml.sample ${COLIMA_HOME}/bitcoin-node/colima.yaml

$ colima start --profile bitcoin-node

$ docker compose --profile bitcoin-knots-over-mullvad up
```

### Run Bitcoin Knots and route traffic over Tor

Make sure colima is not running using `colima stop --profile bitcoin-node` and connect external volume. 

```console
$ export COLIMA_HOME=/Volumes/Docker

$ cp colima-tor.yaml.sample ${COLIMA_HOME}/bitcoin-node/colima.yaml

$ colima start --profile bitcoin-node

$ docker compose --profile bitcoin-knots-over-tor up
```