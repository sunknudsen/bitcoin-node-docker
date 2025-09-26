#!/bin/bash

bold=$(tput bold)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
grey=$(tput setaf 8)
normal=$(tput sgr0)
el=$(tput el)

label1="Memory pressure: "
label2="Thermal pressure: "
label3="Disk usage: "

default_volume="/Volumes/Docker"
default_interval=10
watch_mode=false

volume="$default_volume"
interval="$default_interval"

mem_status() {
  v=$(sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null)
  case $v in
    1) printf "${bold}${green}Normal${normal}" ;;
    2) printf "${bold}${yellow}Warning${normal}" ;;
    4) printf "${bold}${red}Critical${normal}" ;;
    *) printf "Unknown (%s)" "$v" ;;
  esac
}

thermal_status() {
  v=$(sudo powermetrics -i 500 -n 1 -s thermal 2>/dev/null | awk -F ': *' '/Current pressure level/ {print $2; exit}')
  case "$v" in
    Nominal) printf "${bold}${green}Nominal${normal}" ;;
    Moderate) printf "${bold}${yellow}Moderate${normal}" ;;
    Heavy) printf "${bold}${red}Heavy${normal}" ;;
    Trapping) printf "${bold}${red}Trapping${normal}" ;;
    Sleeping) printf "${bold}${red}Sleeping${normal}" ;;
    *) printf "%s" "$v" ;;
  esac
}

disk_usage() {
  local df_output=$(df "$volume" 2>/dev/null | awk 'NR==2 {print $2, $3, $4}')
  read -r total_blocks used_blocks available_blocks <<< "$df_output"
  
  if [[ -z "$total_blocks" ]]; then
    printf "${bold}${red}Unable to read disk usage${normal}"
    return
  fi
  
  local v=$(( (used_blocks * 100) / total_blocks ))
  
  local color="$green"
  if [[ "$v" -ge 90 ]]; then
    color="$red"
  elif [[ "$v" -ge 75 ]]; then
    color="$yellow"
  fi
  
  printf "${bold}${color}%s%%${normal}" "$v"
}

print_status() {
  local mem_val=$(mem_status)
  local therm_val=$(thermal_status)
  local disk_val=$(disk_usage)
  printf "%s%s${el}\n%s%s${el}\n%s%s${el}\n" "$label1" "$mem_val" "$label2" "$therm_val" "$label3" "$disk_val"
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  cat << EOF
Usage: monitor.sh [OPTIONS] [INTERVAL]

Monitor memory and thermal pressure and disk usage on macOS.

OPTIONS:
  -v, --volume VOLUME     Volume to monitor for disk usage
                          (default: $default_volume)
  -w, --watch [INTERVAL]  Enable watch mode with updates every INTERVAL seconds
                          (default: $default_interval)
  -h, --help              Show this help message

DESCRIPTION:
  This script monitors critical system health metrics on macOS:
  1. Memory pressure - Shows system memory stress level
  2. Thermal pressure - Shows system thermal stress level
  3. Disk usage - Shows disk usage percentage
  
  Status indicators use color coding:
  - Green: Normal/healthy levels
  - Yellow: Warning/moderate levels
  - Red: Critical/severe levels
  
  Watch mode updates metrics using interval until interrupted using Ctrl+C.
EOF
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case $1 in
    -w|--watch)
      watch_mode=true
      if [[ $2 =~ ^[0-9]+$ ]]; then
        interval="$2"
        shift
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

if [[ ! -d "$volume" ]]; then
  printf "Error: Volume not found: %s\n" "$volume" >&2
  exit 1
fi

if [[ "$watch_mode" == true ]]; then
  printf "${grey}Updating every %s seconds (Ctrl+C to exit):${normal}\n\n" "$interval"
  print_status
  
  tput civis
  trap 'tput cnorm; printf "\n"; exit' INT TERM
  
  while :; do
    tput cuu 3
    print_status
    sleep "$interval"
  done
else
  print_status
fi