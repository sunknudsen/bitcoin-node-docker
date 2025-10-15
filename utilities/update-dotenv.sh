#!/bin/sh

bold=$(tput bold)
red=$(tput setaf 1)
normal=$(tput sgr0)

dry_run=false

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  cat << EOF
Usage: update-dotenv.sh [OPTIONS]

Update .env with latest version of Bitcoin Core, Bitcoin Knots, Electrs and Tor.

OPTIONS:
  -d, --dry-run  Show latest versions without updating .env
  -h, --help     Show this help message

DESCRIPTION:
  This script fetches latest version of:
  - Bitcoin Core using GitHub releases
  - Bitcoin Knots using GitHub releases
  - Electrs using GitHub releases  
  - Tor using package repository

  By default, it asks for user confirmation before updating .env.
EOF
  exit 0
fi

if [[ "$1" == "-d" || "$1" == "--dry-run" ]]; then
  dry_run=true
fi

bitcoin_core_version=$(curl -fsSL https://api.github.com/repos/bitcoin/bitcoin/releases/latest \
  | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')
bitcoin_knots_version=$(curl -fsSL https://api.github.com/repos/bitcoinknots/bitcoin/releases/latest \
  | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')
electrs_version=$(curl -fsSL https://api.github.com/repos/romanz/electrs/releases/latest \
  | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')
tor_version=$(curl -fsSL https://deb.torproject.org/torproject.org/dists/bookworm/main/binary-arm64/Packages \
  | awk '/^Package: tor$/ {getline; if ($1=="Version:"){sub(/-.*/,"",$2); print $2; exit}}')

printf "${bold}Proposed updates for .env${normal}:\n"
printf "BITCOIN_CORE_VERSION=%s\n" "\"$bitcoin_core_version\""
printf "BITCOIN_KNOTS_VERSION=%s\n" "\"$bitcoin_knots_version\""
printf "ELECTRS_VERSION=%s\n" "\"$electrs_version\""
printf "TOR_VERSION=%s\n\n" "\"$tor_version\""

if [ "$dry_run" = true ]; then
  exit 0
fi

printf "${bold}Do you wish to update .env to above versions (y or n)?${normal} "
read -r answer

if [ "$answer" = "y" ]; then
  sed -i '' "s/^BITCOIN_CORE_VERSION=.*/BITCOIN_CORE_VERSION=\"${bitcoin_core_version}\"/" .env
  sed -i '' "s/^BITCOIN_KNOTS_VERSION=.*/BITCOIN_KNOTS_VERSION=\"${bitcoin_knots_version}\"/" .env
  sed -i '' "s/^ELECTRS_VERSION=.*/ELECTRS_VERSION=\"${electrs_version}\"/" .env
  sed -i '' "s/^TOR_VERSION=.*/TOR_VERSION=\"${tor_version}\"/" .env
  printf "Done\n"
fi