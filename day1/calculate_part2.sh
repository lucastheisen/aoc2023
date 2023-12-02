#!/bin/bash

function error_exit {
  echo "$1"
  exit "${2:-1}"
}

function to_digit {
  if ((${#1}==1)); then
    echo -n "$1"
    return
  fi

  case $1 in
    zero) echo -n 0;;
    one) echo -n 1;;
    two) echo -n 2;;
    three) echo -n 3;;
    four) echo -n 4;;
    five) echo -n 5;;
    six) echo -n 6;;
    seven) echo -n 7;;
    eight) echo -n 8;;
    nine) echo -n 9;;
    default)
      error_exit "not a digit: [$1]"
  esac
}

function main {
  readarray -t lines < "$(dirname "$(readlink --canonicalize-existing "$0")")/input.txt"
  left_regex="(0|zero|1|one|2|two|3|three|4|four|5|five|6|six|7|seven|8|eight|9|nine)"
  right_regex=".*(0|zero|1|one|2|two|3|three|4|four|5|five|6|six|7|seven|8|eight|9|nine)"
  running=0
  for line in "${lines[@]}"; do
    if [[ "${line}" =~ ${left_regex} ]]; then
      left="$(to_digit "${BASH_REMATCH[1]}")"
    else
      error_exit "unable to match number: ${line}"
    fi
    if [[ "${line}" =~ ${right_regex} ]]; then
      right="$(to_digit "${BASH_REMATCH[1]}")"
    fi
  
    value=$((left*10+right))
    running=$((running+value))
    printf '%s: %d (running=%d)\n' "${line}" "${value}" "${running}"
  done
  printf "Grand total: %d" "${running}"
}

main
