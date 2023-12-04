#!/bin/bash

set -e

readonly COLORIZED=/tmp/foo

function line_sum {
  local prev_line=$1
  local curr_line=$2
  local next_line=$3

  log vvv "begin:\nprev: ${prev_line}\ncurr: ${curr_line}\nnext: ${next_line}"

  local line_sum=0

  local prev_match_end=0
  local test_line="${curr_line}"
  while [[ "${test_line}" =~ (^|[^[:digit:]]+)([[:digit:]]+) ]]; do
    local full_match="${BASH_REMATCH[0]}"
    local match_prefix="${BASH_REMATCH[1]}"
    local match_number="${BASH_REMATCH[2]}"

    ((match_start=prev_match_end+${#match_prefix}))
    log vv "found ${match_number} at ${match_start} in ${full_match}"

    test_line="${test_line:${#full_match}}"
    ((prev_match_end+=${#full_match}))
    
    local check_start
    if [[ "${match_start}" == 0 ]]; then
      check_start=0
    else
      check_start=$((match_start-1))
    fi
    local check_len=$((${#match_number}+2))
    local check_prev="${prev_line:${check_start}:${check_len}}"
    local check_curr="${curr_line:${check_start}:${check_len}}"
    local check_next="${next_line:${check_start}:${check_len}}"

    log vv "checking from ${check_start} for ${check_len} chars"
    log vvv "check:\nprev: ${check_prev}\ncurr: ${check_curr}\nnext: ${check_next}"

    echo -n "${match_prefix}" >> /tmp/foo
    if [[ "${check_prev//\./ }${check_curr//\./ }${check_next//\./ }" =~ [[:punct:]] ]]; then
      ((line_sum+=match_number))
      echo -en "\e[1;32m${match_number}\e[0m" >> "${COLORIZED}"
      log vv "      found match (${match_number})"
    else
      echo -en "\e[1;31m${match_number}\e[0m" >> "${COLORIZED}"
    fi
    log vv "    line_sum=${line_sum}"
  done
  echo "${curr_line:$((match_start+${#match_number}))}" >> "${COLORIZED}"

  echo -n "${line_sum}"
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
  exec 3< "$(dirname "$(readlink --canonicalize-existing "$0")")/input.txt"
  running=0
  prev_line=""
  curr_line=""
  next_line=""
  index=1
  while read -r -u 3 line; do
    prev_line="${curr_line}"
    curr_line="${next_line}"
    next_line="${line}"
    if [[ -z "${curr_line}" ]]; then
      continue
    fi
  
    log vv "gathering sum for line ${index}"
    line_sum_value=$(line_sum "${prev_line}" "${curr_line}" "${next_line}")
    ((running+=line_sum_value))
    log v "line ${index}, sum ${line_sum_value}, total ${running}"
    ((index++))
  done
  
  line_sum_value=$(line_sum "${curr_line}" "${next_line}" "")
  ((running+=line_sum_value))
  log v "line ${index}, sum ${line_sum_value}, total ${running}"
  
  printf 'Grand total: %d\n' "${running}"
  exec 3<&-    
}

main
