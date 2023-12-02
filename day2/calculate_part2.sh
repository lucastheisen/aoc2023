#!/bin/bash

function power_of_pulls {
  local pulls=("$@")

  red=0
  green=0
  blue=0
  for pull in "${pulls[@]}"; do
    >&2 echo "    ${pull}"

    readarray -d$',' -t cube_counts <<<"${pull}"
    for cube_count in "${cube_counts[@]}"; do
      if [[ "${cube_count}" =~ ([[:digit:]]+)\ (red|blue|green) ]]; then
        case "${BASH_REMATCH[2]}" in
          red) if ((BASH_REMATCH[1]>red)); then red=${BASH_REMATCH[1]}; fi;;
          green) if ((BASH_REMATCH[1]>green)); then green=${BASH_REMATCH[1]}; fi;;
          blue) if ((BASH_REMATCH[1]>blue)); then blue=${BASH_REMATCH[1]}; fi;;
          *) error_exit "unsupported color [${BASH_REMATCH[2]}]: ${line}"
        esac
      else
        error_exit "cant parse cube counts: ${line}"
      fi
    done
  done

  >&2 echo "        red=${red} green=${green} blue=${blue}"
  echo -n $((red*green*blue))
}

function error_exit {
  echo "$1"
  exit "${2:-1}"
}

function main {
  readarray -t lines < "$(dirname "$(readlink --canonicalize-existing "$0")")/input.txt"
  running=0
  for line in "${lines[@]}"; do
    IFS=: read -r game result <<<"${line}"
    >&2 printf "game [%s] result [%s]\n" "${game#Game }" "${result}"

    readarray -d$';' -t pulls <<<"${result}"
    power=$(power_of_pulls "${pulls[@]}")
    >&2 printf "           POWER %d\n" "${power}"
    running=$((running+power))
  done

  printf 'Grand total: %d' "${running}"
}

main
