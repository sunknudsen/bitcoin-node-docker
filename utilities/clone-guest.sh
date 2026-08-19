#!/bin/bash

# Runs inside privileged container on temporary worker virtual machine (see clone.sh)

bold=$(tput bold)
normal=$(tput sgr0)

set -o errexit -o pipefail

project_name="${1}"
force="${2}"
source_uuid="${3}"
destination_uuid="${4}"

printf "${bold}Installing rsync…${normal}\n"

apt-get update > /dev/null

DEBCONF_NOWARNINGS=yes DEBIAN_FRONTEND=noninteractive apt-get install --yes rsync > /dev/null

source_device=""
destination_device=""

for device in /dev/vd[b-z] /dev/vd[b-z][0-9]*; do
  if [[ ! -b "${device}" ]]; then
    continue
  fi
  uuid=$(blkid --match-tag UUID --output value "${device}" 2> /dev/null || true)
  if [[ "${uuid}" == "${source_uuid}" ]]; then
    source_device="${device}"
  elif [[ "${uuid}" == "${destination_uuid}" ]]; then
    destination_device="${device}"
  fi
done

if [[ -z "${source_device}" || -z "${destination_device}" ]]; then
  echo "Error: Cannot find source and destination data disks" >&2
  exit 1
fi

mkdir -p /mnt/source /mnt/destination

mount "${source_device}" /mnt/source

mount "${destination_device}" /mnt/destination

dataset_volumes() {
  volume_directory=$(find "${1}" -maxdepth 6 -type d -path "*/volumes/${project_name}_bitcoind" -print -quit)
  if [[ -z "${volume_directory}" ]]; then
    return 1
  fi
  dirname "${volume_directory}"
}

if ! source_volumes=$(dataset_volumes /mnt/source); then
  echo "Error: Cannot find source Docker volumes (make sure source virtual machine was stopped gracefully)" >&2
  exit 1
fi

if ! destination_volumes=$(dataset_volumes /mnt/destination); then
  echo "Error: Cannot find destination Docker volumes (make sure destination virtual machine was stopped gracefully)" >&2
  exit 1
fi

source_height=$(find "${source_volumes}/${project_name}_bitcoind/_data/blocks" -maxdepth 1 -name "blk*.dat" -printf "%f\n" 2> /dev/null | sort | tail --lines 1 | tr --complement --delete "0-9" || true)
destination_height=$(find "${destination_volumes}/${project_name}_bitcoind/_data/blocks" -maxdepth 1 -name "blk*.dat" -printf "%f\n" 2> /dev/null | sort | tail --lines 1 | tr --complement --delete "0-9" || true)

if [[ "${force}" != "true" && -n "${source_height}" && -n "${destination_height}" ]] && (( 10#${destination_height} > 10#${source_height} )); then
  echo "Error: Destination dataset is ahead of source dataset (are --source and --destination reversed? use --force to override)" >&2
  exit 1
fi

total=$(du --bytes --summarize \
  "${source_volumes}/${project_name}_bitcoind/_data/blocks" \
  "${source_volumes}/${project_name}_bitcoind/_data/chainstate" \
  "${source_volumes}/${project_name}_bitcoind/_data/indexes" \
  "${source_volumes}/${project_name}_electrs/_data" \
  | awk '{ sum += $1 } END { printf "%.0f\n", sum }')

printf "${bold}Cloning about %sGB of dataset…${normal}\n" "$((total / 1000000000))"

rsync --archive --delete --info=progress2 \
  "${source_volumes}/${project_name}_bitcoind/_data/blocks" \
  "${source_volumes}/${project_name}_bitcoind/_data/chainstate" \
  "${source_volumes}/${project_name}_bitcoind/_data/indexes" \
  "${destination_volumes}/${project_name}_bitcoind/_data"

rsync --archive --delete --info=progress2 \
  "${source_volumes}/${project_name}_electrs/_data/" \
  "${destination_volumes}/${project_name}_electrs/_data"

chown 1000:1000 \
  "${destination_volumes}/${project_name}_bitcoind/_data" \
  "${destination_volumes}/${project_name}_electrs/_data"

umount /mnt/source /mnt/destination

printf "${bold}Cloned dataset${normal}\n"
