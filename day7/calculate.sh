#!/bin/bash

set -e

function rank {
  local hand=$1

  # starting counts at 2 to align with card numbers for easier visual inspection
  local counts=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
  local suffix=""
  local high=0
  local i v
  for ((i=0; i<${#hand}; i++)); do
    v="${hand:${i}:1}"
    case "${v}" in
      A) v=14;;
      K) v=13;;
      Q) v=12;;
      J) v=11;;
      T) v=10;;
    esac

    if ((v<10)); then
      suffix+="0${v}"
    else
      suffix+="${v}"
    fi
    ((++counts[v]))
    if ((high<v)); then
      high="${v}"
    fi
  done

  local multiples=(0 0 0 0 0 0)
  local count
  for count in "${counts[@]:2}"; do
    if ((count>1)); then
      ((++multiples[count]))
    fi
  done

  local category
  if ((multiples[5]>0)); then
    # five of a kind
    category=20
  elif ((multiples[4]>0)); then
    # four of a kind
    category=19
  elif ((multiples[3]>0)); then
    if ((multiples[2]>0)); then
      # full house
      category=18
    else
      # three of a kind
      category=17
    fi
  elif ((multiples[2]>1)); then
    # two pair
    category=16
  elif ((multiples[2]>0)); then
    # one pair
    category=15
  else
    # high card
    category="$(printf '%02d' "${high}")"
  fi

  if [[ -v DEBUG_OUTFILE ]]; then
    (
      echo -n "${category}${suffix} "
      echo -n "${hand}: "
      printf '%s' "${multiples[@]:2}"
      echo -n " ${suffix} "
      for ((i=2; i<=14; i++)); do
        if ((counts[i]>0)); then
          echo -n "[${i}=${counts[i]}]"
        fi
      done
      echo
    ) >> "${DEBUG_OUTFILE}"
  fi

  echo -n "${category}${suffix}"
}

function main {
  local file="${1:-input.txt}"
  local path
  path="$(dirname "$(readlink --canonicalize-existing "$0")")/${file}"

  if [[ -v DEBUG_OUTFILE ]]; then
    rm --force "${DEBUG_OUTFILE}"
  fi

  exec 4< <(
    (
      exec 3< "${path}"
      while read -r -u 3 hand bid; do
        printf '%s %s %s\n' "$(rank "${hand}")" "${hand}" "${bid}"
      done
      exec 3<&-
    ) | sort | cat -n
  )
  local multiplier rank hand bid winnings total
  while read -r -u 4 multiplier rank hand bid; do
    ((winnings=multiplier*bid))
    ((total+=winnings))
    >&2 printf '% 4s %s %s % 3s % 6s % 10s\n' \
      "${multiplier}" \
      "${rank}" \
      "${hand}" \
      "${bid}" \
      "${winnings}" \
      "${total}"
  done
  exec 4<&-

  if [[ -v DEBUG_OUTFILE ]]; then
    local temp
    temp="$(mktemp)"
    sort < "${DEBUG_OUTFILE}" | cat -n > "${temp}"
    mv "${temp}" "${DEBUG_OUTFILE}"
  fi

  printf 'Grand total: %d\n' "${total}"
}

(return 0 2>/dev/null) || main "$@"
