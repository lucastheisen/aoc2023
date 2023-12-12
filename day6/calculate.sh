#!/bin/bash

function main {
  local file="${1:-input.txt}"
  local path
  path="$(dirname "$(readlink --canonicalize-existing "$0")")/${file}"

  local times distances
  read -r -a times < <(grep '^Time:' "${path}" | sed 's/Time://')
  read -r -a distances < <(grep '^Distance:' "${path}" | sed 's/Distance://')

  local i j time distance total
  for ((i=0; i<"${#times[@]}"; i++)); do
    time="${times["${i}"]}"
    distance="${distances["${i}"]}"

    local wins=0
    # both 0 and time result in zero distance so dont calculate
    for ((j=1; j<time; j++)); do
      if (((j*(time-j))>distance)); then
        ((wins=wins+1))
      fi
    done
    if ((total==0)); then
      ((total=wins))
    else
      ((total=total*wins))
    fi
  done

  printf 'Grand total: %d' "${total}"
}

main "$@"
