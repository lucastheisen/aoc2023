#!/bin/bash

set -e

function line_points {
  local line=$1

  log vvv "begin: ${line}"
  local card
  local winning_numbers
  local my_numbers
  local points=0
  if [[ "${line}" =~ ^Card[[:space:]]+([[:digit:]]+)([^|]+)[|](.*) ]]; then
    card="${BASH_REMATCH[1]}"
    read -ra winning_numbers <<<"${BASH_REMATCH[2]}"
    my_numbers=" ${BASH_REMATCH[3]} "

    local number
    for number in "${winning_numbers[@]}"; do
      if [[ "${my_numbers}" =~ \ ${number}\  ]]; then
        log vvv "card ${card} matches ${number}"
        if ((points==0)); then
          points=1
        else
          ((points*=2))
        fi
      fi
    done
  fi

  echo -n "${points}"
}

function log {
  local verbosity=$1
  local message=$2

  if [[ "${LOG_VERBOSITY:-x}" =~ ^${verbosity} ]]; then
    >&2 printf "%s [%3s] %s: %b\n" \
      "$(date +%H:%M:%S)" \
      "${verbosity}" \
      "$(caller 0 | awk '{print $2}')" \
      "${message}"
  fi
}

function main {
  log v "begin main"
  local running=0
  local prev_line=""
  local curr_line=""
  local next_line=""
  local index=1
  local points

  exec 3< "$(dirname "$(readlink --canonicalize-existing "$0")")/input.txt"
  while read -r -u 3 line; do
    prev_line="${curr_line}"
    curr_line="${next_line}"
    next_line="${line}"
    if [[ -z "${curr_line}" ]]; then
      continue
    fi
  
    log vv "gathering sum for line ${index}"
    points=$(line_points "${prev_line}" "${curr_line}" "${next_line}")
    ((running+=points)) || true

    log v "line ${index}, sum ${points}, total ${running}"
    ((index++))
  done
  exec 3<&-    
  
  points=$(line_points "${curr_line}" "${next_line}" "")
  ((running+=points))
  log v "line ${index}, points ${points}, total ${running}"
  
  printf 'Grand total: %d\n' "${running}"
}

main
