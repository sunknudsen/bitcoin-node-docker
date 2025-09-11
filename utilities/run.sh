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
  2. Starting Colima with bitcoin-node profile
  3. Running Docker Compose with the specified profile
  4. Stopping Colima and ejecting the volume when done

The script will keep the system awake during operation using caffeinate.
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

if [[ "$profile" == *"mullvad"* ]]; then
  cp "$project_directory/colima-mullvad.yaml.sample" "${COLIMA_HOME}/bitcoin-node/colima.yaml"
elif [[ "$profile" == *"tor"* ]]; then
  cp "$project_directory/colima-tor.yaml.sample" "${COLIMA_HOME}/bitcoin-node/colima.yaml"
fi

colima --profile bitcoin-node stop

colima --profile bitcoin-node start

caffeinate docker compose \
  --profile "$profile" \
  --project-directory "$project_directory" \
  up

colima --profile bitcoin-node stop

diskutil eject "$COLIMA_HOME"