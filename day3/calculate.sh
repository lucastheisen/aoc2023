#!/bin/bash

set -e

function line_sum {
  local prev_line=$1
  local curr_line=$2
  local next_line=$3

  line_sum=0

  prev_match_end=0
  test_line="${curr_line}"
  while [[ "${test_line}" =~ ([^[:digit:]]+)([[:digit:]]+) ]]; do
    ((match_start=prev_match_end+${#BASH_REMATCH[1]}))
    value="${BASH_REMATCH[2]}"
    #>&2 printf '<<%s>> at %d: [[%s]]\n' "${value}" "${match_start}" "${BASH_REMATCH[0]}"

    test_line="${test_line:${#BASH_REMATCH[0]}}"
    ((prev_match_end+=${#BASH_REMATCH[0]}))
    
    check_start=$((match_start-1))
    check_len=$((${#value}+2))
    check_prev="${prev_line:${check_start}:${check_len}}"
    check_curr="${curr_line:${check_start}:${check_len}}"
    check_next="${next_line:${check_start}:${check_len}}"

    #>&2 echo "  checking between ${check_start} and ${check_len}"
    #>&2 printf "    %s\n    %s\n    %s\n" "${check_prev}" "${check_curr}" "${check_next}"

    if [[ "${check_prev//\./ }${check_curr//\./ }${check_next//\./ }" =~ [[:punct:]] ]]; then
      ((line_sum+=value))
      #>&2 printf "      found match (%d)\n" "${value}"
    fi
    #>&2 printf "    line_sum=%d\n" "${line_sum}"
  done

  echo -n "${line_sum}"
}

function main {
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
  
    line_sum_value=$(line_sum "${prev_line}" "${curr_line}" "${next_line}")
    ((running+=line_sum_value))
    >&2 printf "######## %d: %d -> %d\n" "${index}" "${line_sum_value}" "${running}"
    ((index++))
  done
  
  line_sum_value=$(line_sum "${curr_line}" "${next_line}" "")
  ((running+=$(line_sum "${curr_line}" "${next_line}" "")))
  >&2 printf "######## %d: %d -> %d\n" "${index}" "${line_sum_value}" "${running}"
  
  printf 'Grand total: %d' "${running}"
  exec 3<&-    
}

main
