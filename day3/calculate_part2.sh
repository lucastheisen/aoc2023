#!/bin/bash

set -e

function adjacent_numbers {
  local line=$1
  local gear_index=$2

  local start
  for ((start=gear_index-1; start >= 0; start--)); do
    if [[ ! "${line:${start}:1}" =~ [[:digit:]] ]]; then
      break
    fi
  done

  local end
  for ((end=gear_index+1; end<${#line}; end++)); do
    if [[ ! "${line:${end}:1}" =~ [[:digit:]] ]]; then
      break
    fi
  done

  local substr=${line:$((start+1)):$((end-start-1))}
  substr=${substr//\./ }
  substr=${substr//\*/ }
  echo -n "${substr}"
}

function line_gear_ratio_sum {
  local prev_line=$1
  local curr_line=$2
  local next_line=$3

  log vvv "begin:\nprev: ${prev_line}\ncurr: ${curr_line}\nnext: ${next_line}"
  local gear_ration_sum=0

  local prev_match_end=0
  local test_line="${curr_line}"
  local match_index
  while [[ "${test_line}" =~ ([^*]*)[*] ]]; do
    local full_match="${BASH_REMATCH[0]}"
    local match_prefix="${BASH_REMATCH[1]}"
    log vvv "[${test_line}] -> [${full_match}] -> [${match_prefix}]"

    ((match_index=prev_match_end+${#match_prefix})) || true
    log vv "found * at ${match_index} in ${full_match} (${curr_line})"

    # shellcheck disable=SC2046 # intentional word splitting of result from adjacent_numbers
    readarray -d$' ' -t adjacent < <(
      printf '%s ' \
        $(adjacent_numbers "${prev_line}" "${match_index}") \
        $(adjacent_numbers "${curr_line}" "${match_index}") \
        $(adjacent_numbers "${next_line}" "${match_index}"))
    log vvv "adjacent at ${match_index} is [${adjacent[*]}]"
    if ((${#adjacent[@]}==2)); then
      ((gear_ration_sum+=adjacent[0]*adjacent[1]))
    fi

    test_line="${test_line:${#full_match}}"
    ((prev_match_end+=${#full_match}))
  done

  echo -n "${gear_ration_sum}"
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

  exec 3< "$(dirname "$(readlink --canonicalize-existing "$0")")/input.txt"
  while read -r -u 3 line; do
    prev_line="${curr_line}"
    curr_line="${next_line}"
    next_line="${line}"
    if [[ -z "${curr_line}" ]]; then
      continue
    fi
    if [[ -z "${prev_line}" ]]; then
      prev_line="$(printf '.%.0s' $(seq "${#curr_line}"))"
    fi

    log vv "gathering sum for line ${index}"
    line_sum_value=$(line_gear_ratio_sum "${prev_line}" "${curr_line}" "${next_line}")
    ((running+=line_sum_value)) || true
    log v "line ${index}, sum ${line_sum_value}, total ${running}"
    ((index++))
  done
  exec 3<&-

  line_sum_value=$(line_gear_ratio_sum "${curr_line}" "${next_line}" "")
  ((running+=line_sum_value)) || true
  log v "line ${index}, sum ${line_sum_value}, total ${running}"

  printf 'Grand total: %d\n' "${running}"
}

main
