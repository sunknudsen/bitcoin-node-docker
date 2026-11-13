#!/bin/sh

bold=$(tput bold)
normal=$(tput sgr0)

if [[ "${1}" == "-h" || "${1}" == "--help" ]]; then
  cat << EOF
Usage: update-dotenv.sh [options]

Update .env with latest version of Bitcoin Core, Electrs and Tor.

Options:
  -h, --help     Show this help message

Description:
  This script fetches latest version of:
  - Bitcoin Core using GitHub releases
  - Electrs using GitHub releases
  - Tor using package repository

  It asks for user confirmation before updating .env when updates are
  available.
EOF
  exit 0
fi

github_version() {
  curl -fsSL "https://api.github.com/repos/${1}/releases/latest" \
    | grep '"tag_name":' | sed -E 's/.*"tag_name": *"v?([^"]+)".*/\1/'
}

annotation() {
  current=$(grep "^${1}=" .env | cut -d "=" -f 2)
  if [[ -z "${2}" ]]; then
    printf " (could not fetch)"
  elif [[ "${2}" == "${current}" ]]; then
    printf " (up to date)"
  fi
}

update_version() {
  if [[ -n "${3}" ]]; then
    return 0
  fi
  printf "${bold}Update ${1} to %s (y or n)?${normal} " "${2}"
  read -r answer
  if [ "${answer}" = "y" ]; then
    sed -i '' "s/^${1}=.*/${1}=${2}/" .env
  fi
}

bitcoin_core_version=$(github_version bitcoin/bitcoin)
electrs_version=$(github_version romanz/electrs)
tor_version=$(curl -fsSL https://deb.torproject.org/torproject.org/dists/bookworm/main/binary-arm64/Packages \
  | awk '/^Package: tor$/ {getline; if ($1=="Version:"){sub(/-.*/,"",$2); print $2; exit}}')

bitcoin_core_annotation=$(annotation BITCOIN_CORE_VERSION "${bitcoin_core_version}")
electrs_annotation=$(annotation ELECTRS_VERSION "${electrs_version}")
tor_annotation=$(annotation TOR_VERSION "${tor_version}")

printf "${bold}Latest versions${normal}:\n"
printf "BITCOIN_CORE_VERSION=%s%s\n" "${bitcoin_core_version}" "${bitcoin_core_annotation}"
printf "ELECTRS_VERSION=%s%s\n" "${electrs_version}" "${electrs_annotation}"
printf "TOR_VERSION=%s%s\n\n" "${tor_version}" "${tor_annotation}"

update_version BITCOIN_CORE_VERSION "${bitcoin_core_version}" "${bitcoin_core_annotation}"
update_version ELECTRS_VERSION "${electrs_version}" "${electrs_annotation}"
update_version TOR_VERSION "${tor_version}" "${tor_annotation}"

printf "\nDone\n"
