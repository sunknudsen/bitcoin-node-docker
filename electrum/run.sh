#!/bin/sh

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  cat << EOF
Usage: electrum.sh [OPTIONS]

Start Electrum without data persistence using RAM disk.

OPTIONS:
  -h, --help  Show this help message

DESCRIPTION:
  This script starts Electrum without data persistence by:
  1. Creating a 100MB RAM disk
  2. Partitioning RAM disk using APFS filesystem
  3. Starting Electrum using oneserver to only connect to local Bitcoin node
  4. Storing wallet on RAM disk (/Volumes/tmp/holding)
  5. Automatically ejecting RAM disk when done
EOF
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

disk=$(hdiutil attach -nomount ram://204800 | awk '{ print $1 }')

diskutil partitionDisk $disk 1 GPT APFS tmp R

/Applications/Electrum.app/Contents/MacOS/run_electrum --oneserver --server 127.0.0.1:50001:t --wallet /Volumes/tmp/holding

diskutil eject $disk