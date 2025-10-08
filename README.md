# bitcoin-node-docker

This [Docker Compose](https://docs.docker.com/compose/) project is used to run a Bitcoin node on Apple silicon Mac running macOS storing blockchain data on external APFS (Encrypted) volume.

One can either use [Bitcoin Core](https://bitcoincore.org/) or [Bitcoin Knots](https://bitcoinknots.org/) and route traffic over [Mullvad](https://mullvad.net/en) or [Tor](https://www.torproject.org/) for additional privacy (Docker containers do not have direct Internet access, are isolated from macOS host and run as read-only).

An [Electrs](https://github.com/romanz/electrs) server is the only exposed service to which [Electrum](https://electrum.org/) can connect on macOS via `127.0.0.1:50001`.

If you wish to support this project, please star [repo](https://github.com/sunknudsen/bitcoin-node-docker) and consider a [donation](https://sunknudsen.com/donate).

## Required hardware

- Apple silicon Mac running macOS
- External APFS (Encrypted) volume (faster is better, aluminum NVMe enclosure recommended)

If you don’t have a spare enclosure and 2TB NVMe disk, here are two great options:

**Budget option:** [sharge Disk Plus](https://sharge.com/products/disk-plus) + [2TB WD_BLACK SN7100 M.2 2280 NVMe](https://shop.sandisk.com/en-us/products/ssd/internal-ssd/wd-black-sn7100-nvme-internal-ssd?sku=WDS200T4X0E-00CJA0)

**Performance option:** [OWC Express 1M2](https://www.owc.com/solutions/express-1m2) + [2TB SAMSUNG 990 PRO M.2 2280 NVMe](https://www.samsung.com/us/computing/memory-storage/solid-state-drives/990-pro-pcie-4-0-nvme-ssd-2tb-mz-v9p2t0b-am/)

Both of these options can usually be purchased on Amazon (preferrably shipped and sold by Amazon for warranty).

When using a Mac with passive cooling, running [utilities/monitor.sh](utilities/monitor.sh) is recommended. If thermal pressure isn’t nominal (green), using a stand and a fan is recommended during initial block download.

## Setup

### Step 1: clone repo

> Heads-up: running `git` will trigger “Command Line Tools” install unless already installed.

```console
$ git clone https://github.com/sunknudsen/bitcoin-node-docker.git

$ cd bitcoin-node-docker
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

> Heads-up: [wakeful](https://github.com/sunknudsen/wakeful) is used to prevent automatic sleep, gracefully stop Docker Compose services and eject external volume before computer sleeps.

```console
$ brew install colima docker docker-compose sunknudsen/tap/wakeful
```

### Step 5: configure [Docker](https://docs.docker.com/)

```console
$ mkdir -p $HOME/.docker

$ cp config.json.sample $HOME/.docker/config.json
```

### Step 6: configure [Colima](https://github.com/abiosoft/colima)

> Heads-up: replace `Docker` with external volume name and adjust `cpu` and `memory` if hardware can handle heavier workloads (defaults are optimized for Apple silicon MacBook Air computers with 8GB of memory and passive cooling).

```console
$ export COLIMA_HOME=/Volumes/Docker

$ mkdir -p ${COLIMA_HOME}/bitcoin-node

$ cp colima.yaml.sample ${COLIMA_HOME}/bitcoin-node/colima.yaml

$ colima --profile bitcoin-node start \
  --cpu 2 \
  --disk 2048 \
  --memory 4
```

### Step 7: configure `.env`

> Heads-up: use `BITCOIND_DB_CACHE` to set database cache memory allocation (defaults to `2048`).

> Heads-up: use `BITCOIND_MAX_UPLOAD_TARGET` to set daily upload target (defaults to unlimited, use `500M` for a 500MB per day upload target).

> Heads-up: use `BITCOIND_PERSIST_MEMPOOL` to set mempool persistence (defaults to non-persistent, use `1` to enable mempool persistence if node runs 24/7[<sup>1</sup>](#fee-estimates)).

```console
$ cp .env.sample .env
```

## Update

### Step 1: stop Bitcoin node using <kbd>Ctrl+C</kbd> (if running)

### Step 2: update `.env`

> Heads-up: major version updates (going from version 29 to 30 for example) may be [contentious](https://www.youtube.com/watch?v=FZ-nD9hSaeg), so it is advisable to research changes before upgrading (use `--dry-run` to display latest versions without updating .env).

```console
$ utilities/update-dotenv.sh
```

### Step 3: run Bitcoin node

> Heads-up: replace `bitcoin-knots-over-tor` with desired profile and `Docker` with external volume name (if applicable).

> Heads-up: running Bitcoin node will automatically trigger update.

```console
$ wakeful --grace-period 600 utilities/run.sh \
  --profile bitcoin-knots-over-tor  \
  --volume /Volumes/Docker
```

### Step 4: remove dangling images

```console
$ docker image prune
```

## Caveats

### Fee estimates

When Bitcoin node does not run 24/7 or mempool persistence is disabled and node restarts, mempool is stale and, as a result, fee estimates are not consistent with network averages.

Before broadcasting transactions, it is recommended to allow node to sync to tip, wait a few hours for mempool to calibrate and confirm fee estimates using public mempool explorer such as [https://mempool.space/](https://mempool.space/).

## Usage

Using Mullvad profile is recommended during initial block download to considerably speed things up (initial block download is expected to take about 48-72 hours using defaults on fast Internet connection and using wired Ethernet connection is recommended).

Using Tor outbound-only profile is recommended when running node on the go over cellular networks (**warning:** block download can still use considerable bandwidth so syncing node beforehand is recommended).

**Using Tor profile is recommended after initial block download has completed.**

**Use <kbd>Ctrl+C</kbd> to stop node and eject volume.**

### Run Bitcoin Core and route traffic over Mullvad

> Heads-up: replace `Docker` with external volume name (if applicable).

> Heads-up: requires Mullvad [app](https://mullvad.net/en/download/vpn/macos) and [plan](https://mullvad.net/en/pricing).

```console
$ mullvad connect

$ wakeful --grace-period 600 utilities/run.sh \
  --profile bitcoin-core-over-mullvad \
  --volume /Volumes/Docker
```

### Run Bitcoin Core and route traffic over Tor

> Heads-up: replace `Docker` with external volume name (if applicable).

```console
$ wakeful --grace-period 600 utilities/run.sh \
  --profile bitcoin-core-over-tor  \
  --volume /Volumes/Docker
```

### Run Bitcoin Core and route traffic over Tor (outbound-only)

> Heads-up: replace `Docker` with external volume name (if applicable).

```console
$ wakeful --grace-period 600 utilities/run.sh \
  --profile bitcoin-core-over-tor-outbound-only  \
  --volume /Volumes/Docker
```

### Run Bitcoin Knots and route traffic over Mullvad

> Heads-up: replace `Docker` with external volume name (if applicable).

> Heads-up: requires Mullvad [app](https://mullvad.net/en/download/vpn/macos) and [plan](https://mullvad.net/en/pricing).

```console
$ mullvad connect

$ wakeful --grace-period 600 utilities/run.sh \
  --profile bitcoin-knots-over-mullvad  \
  --volume /Volumes/Docker
```

### Run Bitcoin Knots and route traffic over Tor

> Heads-up: replace `Docker` with external volume name (if applicable).

```console
$ wakeful --grace-period 600 utilities/run.sh \
  --profile bitcoin-knots-over-tor  \
  --volume /Volumes/Docker
```

### Run Bitcoin Knots and route traffic over Tor (outbound-only)

> Heads-up: replace `Docker` with external volume name (if applicable).

```console
$ wakeful --grace-period 600 utilities/run.sh \
  --profile bitcoin-knots-over-tor-outbound-only  \
  --volume /Volumes/Docker
```

### Run Electrum

> Heads-up: requires Electrum [app](https://electrum.org/#download).

> Heads-up: run script used to start Electrum without data persistence using RAM disk.

```console
$ electrum/run.sh
```

## Extras

### Create aliases

> Heads-up: replace `$HOME/bitcoin-node-docker` with path to bitcoin-node-docker folder, `bitcoin-knots-over-tor` with desired profile and `Docker` with external volume name (if applicable).

Once aliases have been created, one can run `bitcoin-node` to start Bitcoin node and `electrum` to start Electrum without data persistence.

**Use <kbd>Ctrl+C</kbd> to stop Bitcoin node and eject volume.**

```console
$ cat << 'EOF' >> $HOME/.zshrc
# Set bitcoin-node-docker aliases
alias bitcoin-node="wakeful --grace-period 600 $HOME/bitcoin-node-docker/utilities/run.sh --profile bitcoin-knots-over-tor --volume /Volumes/Docker"
alias electrum="$HOME/Code/sunknudsen/bitcoin-node-docker/electrum/run.sh"
EOF

$ source $HOME/.zshrc
```