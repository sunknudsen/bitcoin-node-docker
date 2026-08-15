#!/bin/sh

bold=$(tput bold)
red=$(tput setaf 1)
normal=$(tput sgr0)

default_volume="/Volumes/Docker"
destination=""
force="false"
volume="${default_volume}"

project_directory=$(cd "$(dirname "${0}")" && cd ../ && pwd)
project_name=$(basename "${project_directory}" | tr "[:upper:]" "[:lower:]")

if [[ "${1}" == "-h" || "${1}" == "--help" ]]; then
  cat << EOF
Usage: clone.sh [options]

Clone dataset to destination COLIMA_HOME volume.

Options:
  -d, --destination <destination>   Volume to use for destination
                                    COLIMA_HOME
  -f, --force                       Clone even if destination dataset
                                    is ahead of source dataset
  -v, --volume <volume>             Volume to use for COLIMA_HOME
                                    (default: $default_volume)
  -h, --help                        Show this help message

Description:
  This script clones dataset by:
  1. Checking if COLIMA_HOME and destination volumes are mounted
  2. Making sure source virtual machine is stopped
  3. Provisioning destination virtual machine and Docker volumes
  4. Creating near-instant copy-on-write APFS clone of source data
     disk (source data disk is never opened)
  5. Starting temporary clone virtual machine (profile
     bitcoin-node-clone) and attaching destination data disk and
     source data disk clone as virtio block devices (fastest disk I/O
     path)
  6. Making sure destination dataset is not ahead of source dataset
     (protects against reversing --volume and --destination)
  7. Copying blocks, chainstate and indexes from bitcoind volume and
     everything from electrs volume using rsync (interrupted cloning
     can be resumed by running clone.sh again)
  8. Deleting temporary clone virtual machine and source data disk
     clone

  Node-specific files such as anchors.dat, banlist.json,
  fee_estimates.dat, mempool.dat, onion_v3_private_key, peers.dat and
  settings.json are excluded so dataset can be shared without
  revealing anything about one’s addresses or transactions.

  Destination volume becomes ready-to-run COLIMA_HOME volume (use
  run.sh --volume to run node using destination volume).

  Destination volume should be as large as COLIMA_HOME volume.
EOF
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "${1}" in
    -d|--destination)
      if [[ -n "${2}" && ! "${2}" =~ ^- ]]; then
        destination="${2}"
        shift
      else
        echo "Error: --destination requires a value" >&2
        exit 1
      fi
      shift
      ;;
    -f|--force)
      force="true"
      shift
      ;;
    -v|--volume)
      if [[ -n "${2}" && ! "${2}" =~ ^- ]]; then
        volume="${2}"
        shift
      else
        echo "Error: --volume requires value" >&2
        exit 1
      fi
      shift
      ;;
    -h|--help)
      shift
      ;;
    -*)
      echo "Error: Unknown option: ${1}" >&2
      exit 1
      ;;
    *)
      echo "Error: Unexpected argument: ${1}" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${destination}" ]]; then
  echo "Error: --destination requires a value" >&2
  exit 1
fi

if [[ "${destination}" == "${volume}" ]]; then
  echo "Error: --destination cannot match --volume" >&2
  exit 1
fi

if ! command -v limactl > /dev/null; then
  echo "Error: Cannot find limactl" >&2
  exit 1
fi

export COLIMA_HOME="${volume}"

if ! mount | grep "on ${COLIMA_HOME} (" | grep -q "apfs"; then
  echo "Error: Please connect ${COLIMA_HOME} (must be APFS volume)" >&2
  exit 1
fi

if ! mount | grep -q "on ${destination} ("; then
  echo "Error: Please connect ${destination}" >&2
  exit 1
fi

if colima list --json 2> /dev/null | grep -q '"status":"Running"'; then
  echo "Error: Please stop Bitcoin node" >&2
  exit 1
fi

source_datadisk="${volume}/_lima/_disks/colima-bitcoin-node/datadisk"
destination_datadisk="${destination}/_lima/_disks/colima-bitcoin-node/datadisk"
clone_directory="${volume}/bitcoin-node-clone"
clone_symlink="${destination}/_lima/_disks/bitcoin-node-clone-source"

if [[ ! -f "${source_datadisk}" ]]; then
  echo "Error: Cannot find ${source_datadisk}" >&2
  exit 1
fi

destination_docker_host="unix://${destination}/bitcoin-node/docker.sock"
worker_docker_host="unix://${destination}/bitcoin-node-clone/docker.sock"

if [[ ! -f "${destination}/bitcoin-node/colima.yaml" ]]; then
  mkdir -p "${destination}/bitcoin-node"
  cp "${project_directory}/colima.yaml.sample" "${destination}/bitcoin-node/colima.yaml"
fi

printf "${bold}Provisioning destination virtual machine…${normal}\n"

COLIMA_HOME="${destination}" colima --profile bitcoin-node start

if [[ -n "$(DOCKER_HOST="${destination_docker_host}" docker ps --filter volume="${project_name}_bitcoind" --quiet)" || -n "$(DOCKER_HOST="${destination_docker_host}" docker ps --filter volume="${project_name}_electrs" --quiet)" ]]; then
  echo "Error: Please stop Bitcoin node on destination" >&2
  exit 1
fi

for name in bitcoind electrs; do
  DOCKER_HOST="${destination_docker_host}" docker volume create \
    --label "com.docker.compose.project=${project_name}" \
    --label "com.docker.compose.volume=${name}" \
    "${project_name}_${name}" > /dev/null
done

COLIMA_HOME="${destination}" colima --profile bitcoin-node stop

if [[ ! -f "${destination_datadisk}" ]]; then
  echo "Error: Cannot find ${destination_datadisk}" >&2
  exit 1
fi

datadisk_uuid() {
  offset=0
  if [[ "$(xxd -plain -s 512 -l 8 "${1}")" == "4546492050415254" ]]; then
    start_sector_hex=$(xxd -plain -s 1056 -l 8 "${1}" | fold -w 2 | tail -r | tr -d "\n")
    offset=$((16#${start_sector_hex} * 512))
  fi
  if [[ "$(xxd -plain -s $((offset + 1080)) -l 2 "${1}")" != "53ef" ]]; then
    return 1
  fi
  xxd -plain -s $((offset + 1128)) -l 16 "${1}" | sed 's/^\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)$/\1-\2-\3-\4-\5/'
}

if ! source_uuid=$(datadisk_uuid "${source_datadisk}"); then
  echo "Error: Cannot find ext4 filesystem on ${source_datadisk}" >&2
  exit 1
fi

if ! destination_uuid=$(datadisk_uuid "${destination_datadisk}"); then
  echo "Error: Cannot find ext4 filesystem on ${destination_datadisk}" >&2
  exit 1
fi

if [[ -z "${source_uuid}" || -z "${destination_uuid}" || "${source_uuid}" == "${destination_uuid}" ]]; then
  echo "Error: Cannot tell source and destination data disks apart using filesystem UUIDs" >&2
  exit 1
fi

trap 'COLIMA_HOME="${destination}" colima --profile bitcoin-node-clone stop > /dev/null 2>&1; COLIMA_HOME="${destination}" colima --profile bitcoin-node-clone delete --force > /dev/null 2>&1; rm -f "${clone_symlink}" "${clone_directory}/datadisk" "${clone_directory}/in_use_by"; rmdir "${clone_directory}" 2> /dev/null' EXIT

printf "${bold}Creating copy-on-write clone of source data disk…${normal}\n"

rm -f "${clone_symlink}" "${clone_directory}/datadisk" "${clone_directory}/in_use_by"

mkdir -p "${clone_directory}"

cp -c "${source_datadisk}" "${clone_directory}/datadisk"

ln -s "${clone_directory}" "${clone_symlink}"

printf "${bold}Starting temporary clone virtual machine…${normal}\n"

COLIMA_HOME="${destination}" colima --profile bitcoin-node-clone start \
  --cpu 2 \
  --disk 10 \
  --memory 2 \
  --vm-type vz

COLIMA_HOME="${destination}" colima --profile bitcoin-node-clone stop

if ! LIMA_HOME="${destination}/_lima" limactl --log-level error edit colima-bitcoin-node-clone --tty=false --set '.additionalDisks = [{"name": "colima-bitcoin-node", "format": false}, {"name": "bitcoin-node-clone-source", "format": false}]'; then
  echo "Error: Cannot attach data disks to temporary clone virtual machine" >&2
  exit 1
fi

if ! LIMA_HOME="${destination}/_lima" limactl --log-level error start colima-bitcoin-node-clone; then
  echo "Error: Cannot start temporary clone virtual machine" >&2
  exit 1
fi

DOCKER_HOST="${worker_docker_host}" docker image pull debian:bookworm-slim > /dev/null

DOCKER_HOST="${worker_docker_host}" docker run --env TERM --interactive --privileged --rm \
  --volume /dev:/dev \
  debian:bookworm-slim \
  bash -s "${project_name}" "${force}" "${source_uuid}" "${destination_uuid}" < "${project_directory}/utilities/clone-guest.sh"

status=$?

printf "${bold}Deleting temporary clone virtual machine…${normal}\n"

COLIMA_HOME="${destination}" colima --profile bitcoin-node-clone stop

COLIMA_HOME="${destination}" colima --profile bitcoin-node-clone delete --force

if [[ "${status}" != "0" ]]; then
  echo "Error: Cloning failed, please run clone.sh again to resume" >&2
  exit 1
fi

printf "${bold}Cloned dataset to %s${normal}\n" "${destination}"
