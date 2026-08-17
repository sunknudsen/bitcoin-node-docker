#!/bin/sh

bold=$(tput bold)
normal=$(tput sgr0)

if [[ "${1}" == "-h" || "${1}" == "--help" ]]; then
  cat << EOF
Usage: update-dotenv.sh [options]

Update .env with latest version of Bitcoin Core, Bitcoin Knots, Electrs and Tor.

Options:
  -h, --help     Show this help message

Description:
  This script fetches latest version of:
  - Bitcoin Core using GitHub releases
  - Bitcoin Knots using GitHub releases
  - Electrs using GitHub releases
  - Tor using package repository

  It asks for user confirmation before updating .env when updates are
  available.
EOF
  exit 0
fi

bitcoin_core_version=$(curl -fsSL https://api.github.com/repos/bitcoin/bitcoin/releases/latest \
  | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')
bitcoin_knots_version=$(curl -fsSL https://api.github.com/repos/bitcoinknots/bitcoin/releases/latest \
  | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')
electrs_version=$(curl -fsSL https://api.github.com/repos/romanz/electrs/releases/latest \
  | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')
tor_version=$(curl -fsSL https://deb.torproject.org/torproject.org/dists/bookworm/main/binary-arm64/Packages \
  | awk '/^Package: tor$/ {getline; if ($1=="Version:"){sub(/-.*/,"",$2); print $2; exit}}')

current_bitcoin_core_version=$(grep "^BITCOIN_CORE_VERSION=" .env | cut -d "=" -f 2)
current_bitcoin_knots_version=$(grep "^BITCOIN_KNOTS_VERSION=" .env | cut -d "=" -f 2)
current_electrs_version=$(grep "^ELECTRS_VERSION=" .env | cut -d "=" -f 2)
current_tor_version=$(grep "^TOR_VERSION=" .env | cut -d "=" -f 2)

bitcoin_core_annotation=""
if [[ -z "${bitcoin_core_version}" ]]; then
  bitcoin_core_annotation=" (could not fetch)"
elif [[ "${bitcoin_core_version}" == "${current_bitcoin_core_version}" ]]; then
  bitcoin_core_annotation=" (up to date)"
fi

bitcoin_knots_annotation=""
if [[ -z "${bitcoin_knots_version}" ]]; then
  bitcoin_knots_annotation=" (could not fetch)"
elif [[ "${bitcoin_knots_version}" == "${current_bitcoin_knots_version}" ]]; then
  bitcoin_knots_annotation=" (up to date)"
fi

electrs_annotation=""
if [[ -z "${electrs_version}" ]]; then
  electrs_annotation=" (could not fetch)"
elif [[ "${electrs_version}" == "${current_electrs_version}" ]]; then
  electrs_annotation=" (up to date)"
fi

tor_annotation=""
if [[ -z "${tor_version}" ]]; then
  tor_annotation=" (could not fetch)"
elif [[ "${tor_version}" == "${current_tor_version}" ]]; then
  tor_annotation=" (up to date)"
fi

printf "${bold}Latest versions${normal}:\n"
printf "BITCOIN_CORE_VERSION=%s%s\n" "${bitcoin_core_version}" "${bitcoin_core_annotation}"
printf "BITCOIN_KNOTS_VERSION=%s%s\n" "${bitcoin_knots_version}" "${bitcoin_knots_annotation}"
printf "ELECTRS_VERSION=%s%s\n" "${electrs_version}" "${electrs_annotation}"
printf "TOR_VERSION=%s%s\n\n" "${tor_version}" "${tor_annotation}"

# Bitcoin Core
if [[ -z "${bitcoin_core_annotation}" ]]; then
  printf "${bold}Update BITCOIN_CORE_VERSION to %s (y or n)?${normal} " "${bitcoin_core_version}"
  read -r answer
  if [ "${answer}" = "y" ]; then
    sed -i '' "s/^BITCOIN_CORE_VERSION=.*/BITCOIN_CORE_VERSION=${bitcoin_core_version}/" .env
  fi
fi

# Bitcoin Knots
if [[ -z "${bitcoin_knots_annotation}" ]]; then
  printf "${bold}Update BITCOIN_KNOTS_VERSION to %s (y or n)?${normal} " "${bitcoin_knots_version}"
  read -r answer
  if [ "${answer}" = "y" ]; then
    sed -i '' "s/^BITCOIN_KNOTS_VERSION=.*/BITCOIN_KNOTS_VERSION=${bitcoin_knots_version}/" .env
  fi
fi

# Electrs
if [[ -z "${electrs_annotation}" ]]; then
  printf "${bold}Update ELECTRS_VERSION to %s (y or n)?${normal} " "${electrs_version}"
  read -r answer
  if [ "${answer}" = "y" ]; then
    sed -i '' "s/^ELECTRS_VERSION=.*/ELECTRS_VERSION=${electrs_version}/" .env
  fi
fi

# Tor
if [[ -z "${tor_annotation}" ]]; then
  printf "${bold}Update TOR_VERSION to %s (y or n)?${normal} " "${tor_version}"
  read -r answer
  if [ "${answer}" = "y" ]; then
    sed -i '' "s/^TOR_VERSION=.*/TOR_VERSION=${tor_version}/" .env
  fi
fi

printf "\nDone\n"
