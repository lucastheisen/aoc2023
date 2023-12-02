#!/bin/bash

readonly MAX_RED=12
readonly MAX_GREEN=13
readonly MAX_BLUE=14

function check_pulls {
  local pulls=("$@")
  for pull in "${pulls[@]}"; do
    echo "    ${pull}"

    readarray -d$',' -t cube_counts <<<"${pull}"
    red=0
    green=0
    blue=0
    for cube_count in "${cube_counts[@]}"; do
      if [[ "${cube_count}" =~ ([[:digit:]]+)\ (red|blue|green) ]]; then
        case "${BASH_REMATCH[2]}" in
          red) red=${BASH_REMATCH[1]};;
          green) green=${BASH_REMATCH[1]};;
          blue) blue=${BASH_REMATCH[1]};;
          *) error_exit "unsupported color [${BASH_REMATCH[2]}]: ${line}"
        esac
      else
        error_exit "cant parse cube counts: ${line}"
      fi
    done

    if possible "${red}" "${green}" "${blue}"; then
      echo "            POSSIBLE"
    else
      echo "            NOT POSSIBLE"
      return 1
    fi
  done
}

function error_exit {
  echo "$1"
  exit "${2:-1}"
}

function possible {
  local red=$1
  local green=$2
  local blue=$3
  echo "        checking red=${red} green=${green} blue=${blue}"
  if ((red>MAX_RED)) || ((green>MAX_GREEN)) || ((blue>MAX_BLUE)); then
    return 1
  fi
}

function main {
  readarray -t lines < "$(dirname "$(readlink --canonicalize-existing "$0")")/input.txt"
  running=0
  for line in "${lines[@]}"; do
    IFS=: read -r game result <<<"${line}"
    printf "game [%s] result [%s]\n" "${game#Game }" "${result}"

    readarray -d$';' -t pulls <<<"${result}"
    if check_pulls "${pulls[@]}"; then
      running=$((running+${game#Game }))
    fi
  done

  printf 'Grand total: %d' "${running}"
}

main
