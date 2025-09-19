#!/bin/sh

bold=$(tput bold)
red=$(tput setaf 1)
normal=$(tput sgr0)

default_volume="/Volumes/Docker"
default_profile="bitcoin-knots-over-tor"
volume="$default_volume"
profile="$default_profile"

project_directory=$(cd "$(dirname "$0")" && cd ../ && pwd)

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  cat << EOF
Usage: run.sh [OPTIONS]

Start Bitcoin node using Colima and Docker Compose.

OPTIONS:
  -p, --profile PROFILE   Docker Compose profile to use
                          (default: $default_profile)
  -v, --volume VOLUME     Volume to use for COLIMA_HOME
                          (default: $default_volume)
  -h, --help              Show this help message

DESCRIPTION:
  This script starts a Bitcoin node by:
  1. Checking if the specified volume is mounted
  2. Provisioning Colima firewall rules based on the specified profile
  3. Starting Colima using bitcoin-node profile
  4. Running Docker Compose using the specified profile
  5. Stopping Colima and ejecting the volume when done

  The script will keep the system awake during operation using caffeinate.
  
  Available profiles:
  - bitcoin-core-over-mullvad: Bitcoin Core over Mullvad VPN
  - bitcoin-core-over-tor: Bitcoin Core over Tor network
  - bitcoin-core-over-tor-outbound-only: Bitcoin Core over Tor network
    (outbound-only)
  - bitcoin-knots-over-mullvad: Bitcoin Knots over Mullvad VPN  
  - bitcoin-knots-over-tor: Bitcoin Knots over Tor network
  - bitcoin-knots-over-tor-outbound-only: Bitcoin Knots over Tor network
    (outbound-only)
EOF
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--profile)
      if [[ -n "$2" && ! "$2" =~ ^- ]]; then
        profile="$2"
        shift
      else
        echo "Error: --profile requires a profile name argument" >&2
        exit 1
      fi
      shift
      ;;
    -v|--volume)
      if [[ -n "$2" && ! "$2" =~ ^- ]]; then
        volume="$2"
        shift
      else
        echo "Error: --volume requires a path argument" >&2
        exit 1
      fi
      shift
      ;;
    -h|--help)
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

export COLIMA_HOME="$volume"

if ! mount | grep -q "on $COLIMA_HOME"; then
  echo "Error: Please connect $COLIMA_HOME" >&2
  exit 1
fi

colima --profile bitcoin-node stop

if [[ "$profile" == *"mullvad"* ]]; then
  sed -i '' 's/ip daddr 172\.18\.0\.2 tcp dport {9050,9051}/ip daddr 10.64.0.1 tcp dport 1080/' "${COLIMA_HOME}/bitcoin-node/colima.yaml"
elif [[ "$profile" == *"tor"* ]]; then
  sed -i '' 's/ip daddr 10\.64\.0\.1 tcp dport 1080/ip daddr 172.18.0.2 tcp dport {9050,9051}/' "${COLIMA_HOME}/bitcoin-node/colima.yaml"
fi

colima --profile bitcoin-node start

caffeinate docker compose \
  --profile "$profile" \
  --project-directory "$project_directory" \
  up

colima --profile bitcoin-node stop

diskutil eject "$COLIMA_HOME"