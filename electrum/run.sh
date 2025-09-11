#!/bin/sh

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  cat << EOF
Usage: electrum.sh [OPTIONS]

Run Electrum wallet with a temporary RAM disk for enhanced privacy.

OPTIONS:
  -h, --help  Show this help message

DESCRIPTION:
  This script runs Electrum wallet with the following security features:
  1. Creates a 100MB RAM disk for temporary storage
  2. Partitions the RAM disk with APFS filesystem
  3. Runs Electrum connected to local server (127.0.0.1:50001)
  4. Uses oneserver mode for privacy
  5. Stores wallet on the RAM disk (/Volumes/tmp/holding)
  6. Automatically ejects the RAM disk when done

The RAM disk ensures that wallet data is never written to persistent storage,
providing enhanced privacy and security for your Bitcoin transactions.
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