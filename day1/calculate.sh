#!/bin/bash

readarray -t lines < <(
  sed 's/[^0-9]//g' < "$(dirname "$(readlink --canonicalize-existing "$0")")/input.txt")
running=0
for line in "${lines[@]}"; do
  total=$(("${line:0:1}"+"${line: -1}"))
  running=$((running+total))
  printf '%s: %d + %d = %d (running=%d)\n' "${line}" "${line:0:1}" "${line: -1}" "${total}" "${running}"
done
printf "Grand total: %d" "${running}"
