#!/bin/bash

readarray -t lines < <(
  sed 's/[^0-9]//g' < "$(dirname "$(readlink --canonicalize-existing "$0")")/input.txt")
running=0
for line in "${lines[@]}"; do
  value=$(("${line:0:1}"*10+"${line: -1}"))
  running=$((running+value))
  printf '%s: %d (running=%d)\n' "${line}" "${value}" "${running}"
done
printf "Grand total: %d" "${running}"
