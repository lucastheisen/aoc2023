#!/bin/bash

set -e

function line_wins {
  local line=$1
  local wins=0

  log vvv "begin: ${line}"
  local card
  local winning_numbers
  local my_numbers
  if [[ "${line}" =~ ^Card[[:space:]]+([[:digit:]]+)([^|]+)[|](.*) ]]; then
    card="${BASH_REMATCH[1]}"
    read -ra winning_numbers <<<"${BASH_REMATCH[2]}"
    my_numbers=" ${BASH_REMATCH[3]} "

    local number
    for number in "${winning_numbers[@]}"; do
      if [[ "${my_numbers}" =~ \ ${number}\  ]]; then
        log vvv "card ${card} matches ${number}"
        ((wins++))
      fi
    done
  fi

  echo -n "${wins}"
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
  local file="${1:-input.txt}"
  log v "begin main"
  local cards=()

  local card
  local wins
  exec 3< "$(dirname "$(readlink --canonicalize-existing "$0")")/${file}"
  while read -r -u 3 line; do
    read -r _ card <<<"${line%%:*}"
    if [[ -z "${cards[${card}]}" ]]; then
      cards[$card]=1
    else
      ((cards[card]++))
    fi

    log vv "gathering sum for line ${index}"
    wins=$(line_wins "${line}")
    for ((i=card+1; i<card+wins+1; i++)); do
      if [[ -z "${cards[${i}]}" ]]; then
        cards[$i]=${cards[${card}]}
      else
        ((cards[i]+=cards[card]))
      fi
    done

    log v "card ${card}, wins ${wins}, total ${cards[*]}"
  done
  exec 3<&-

  log vv "final card is ${card}"
  local total=0
  for ((i=1; i<=card; i++)); do
    ((total+=cards[i]))
    log vvv "card ${i} added ${cards[${i}]} for total ${total}"
  done

  printf 'Grand total: %d\n' "${total}"
}

main "$@"
