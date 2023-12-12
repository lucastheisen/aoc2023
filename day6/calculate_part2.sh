#!/bin/bash

function search {
  local time=$1
  local distance=$2
  local low=$3
  local high=$4
  local test_func=$5

  >&2 printf 'low=%d high=%d\n' "${low}" "${high}"

  if ((low==high)); then
    echo -n "${low}"
    return
  elif ((low+1==high)); then
    if "${test_func}" "${time}" "${distance}" "${low}"; then
      echo -n "${low}"
    else
      echo -n "${high}"
    fi
    return
  fi

  local mid
  ((mid=(high+low)/2))
  >&2 printf 'mid=%d\n' "${mid}"

  if "${test_func}" "${time}" "${distance}" "${mid}"; then
    >&2 printf 'go lower\n'
    search "${time}" "${distance}" "${low}" "${mid}" "${test_func}"
  else
    >&2 printf 'go higher\n'
    search "${time}" "${distance}" "${mid}" "${high}" "${test_func}"
  fi
}

function test_high {
  local time=$1
  local distance=$2
  local value=$3
  ((value*(time-value)<=distance))
}

function test_low {
  local time=$1
  local distance=$2
  local value=$3
  ((value*(time-value)>distance))
}

function main {
  local file="${1:-input.txt}"
  local path
  path="$(dirname "$(readlink --canonicalize-existing "$0")")/${file}"

  local time distance
  time="$(grep '^Time:' "${path}" | sed -e 's/Time://' -e 's/[[:space:]]//g')"
  distance="$(grep '^Distance:' "${path}" | sed -e 's/Distance://' -e 's/[[:space:]]//g')"

  low="$(search "${time}" "${distance}" 0 "${time}" test_low)"
  high="$(search "${time}" "${distance}" 0 "${time}" test_high)"
  >&2 printf "[%d,%d] %d - %d\n" "${time}" "${distance}" "${low}" "${high}"

  printf 'Grand total: %d' "$((high-low))"
}

main "$@"
