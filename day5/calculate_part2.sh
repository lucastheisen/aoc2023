#!/bin/bash

set -e

readonly MAX_NUMBER=9223372036854775807

function dedup_inputs {
  local inputs
  read -ra inputs <<<"${1}"
  local num_inputs="${#inputs[@]}"

  local -a unsorted_inputs
  local -A input_range_map
  local input range
  for ((i=0; i<num_inputs; i=i+2)); do
    input="${inputs[${i}]}"
    range="${inputs[$((i+1))]}"
    unsorted_inputs+=("${input}")
    input_range_map[${input}]="${range}"
  done

  local -a sorted_inputs
  readarray -d $'\0' -t sorted_inputs < <(printf '%s\0' "${unsorted_inputs[@]}" | sort -n -z)
  log v "unsorted_inputs [$(printf '%s,' "${unsorted_inputs[@]}")], sorted_inputs [$(printf '%s,' "${sorted_inputs[@]}")]"

  num_inputs="${#sorted_inputs[@]}"
  local next_input
  for ((i=0; i<num_inputs; i++)); do
    input="${sorted_inputs[${i}]}"
    printf '%s ' "${input}"

    range="${input_range_map[${input}]}"
    log v "checking input[$i/${num_inputs}]: ${input} for ${range} (max value $((input+range)))"
    local next_range
    while ((i+1<num_inputs)); do
      next_input="${sorted_inputs[$((i+1))]}"
      log vvv "checking ${next_input}"

      if ((next_input>input+range+1)); then
        break
      fi
      log vv "input ${input} for ${range} extends into ${next_input}"
      ((next_range=(next_input+input_range_map[${next_input}])-input))
      if ((next_range>range)); then
        range="${next_range}"
      fi

      # dont use i++ because if i was zero, then the postfix will return the
      # original value which was zero which causes bash arithmetic to return 1
      # thus error out.  could use prefix ++ for increment but also dangerous
      # if i were ever -1. this approach is safe though
      ((i=i+1))
      log vvv "bout to check $((i+1))<${num_inputs}"
    done
    log vvv "printing range ${range}"
    printf '%s ' "${range}"
  done
}

function load_map {
  local -n map=$1
  map=("${@:2}")

  # unnecessary work, but will help visualize the mappings better by writing out
  # sorted with src first and include a max_src
  printf '%s:\n%s\n\n' \
    "${!map}" \
    "$(
      (
        local mapping dest src range max_src add_to_src
        for mapping in "${map[@]}"; do
          read -r dest src range <<<"${mapping}"
          ((max_src=src+range-1))
          ((add_to_src=dest-src))
          printf '%d %d %d %d %d\n' "${src}" "${max_src}" "${add_to_src}" "${dest}" "${range}"
        done
      ) | sort -n)"
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

function mapping_for {
  local -n map=$1
  local key=$2
  local range=$3
  local range_end="$((key+range))"
  log vv "map=${!map} key=${key} range=${range} range_end=${range_end}"

  local mapping mapping_end dest src len dest_start dest_range range_starts
  for mapping in "${map[@]}"; do
    read -r dest src len <<<"${mapping}"
    range_starts+=("${src}")
    mapping_end="$((src+len))"
    if ((key>=src)) && ((key<mapping_end)); then
      log vv "match for $key in mapping [${mapping}]"

      dest_start="$((dest+(key-src)))"
      printf '%d ' "${dest_start}"
      if ((range_end>mapping_end)); then
        dest_range="$((mapping_end-key))"
        log vv "partial match for ${key} is ${dest_start} for ${dest_range}"
        printf '%d ' "${dest_range}"
        mapping_for "${!map}" "${mapping_end}" "$((range_end-mapping_end))"
        return
      else
        log vv "full match for ${key} is ${dest_start} for ${range}"
        printf '%d ' "${range}"
        return
      fi
    fi
  done

  log vv "no mapping match in ${!map} for [${key}], using default mapping"
  local min_start="${MAX_NUMBER}"
  for start in "${range_starts[@]}"; do
    log vvv "range start ((${start}>=${key}))=$(if ((start>=key)); then echo 'true'; else echo 'false'; fi) && ((${start}<${min_start}))=$(if ((start<min_start)); then echo 'true'; else echo 'false'; fi) = $(if ((start>=key)) && ((start<min_start)); then echo 'true'; else echo 'false'; fi)"
    if ((start>=key)) && ((start<min_start)); then
      log vvv "found later range startint at ${start}, setting min_start"
      min_start="${start}"
    fi
  done

  log vvv "checking for later range match ((${min_start}==${MAX_NUMBER})) = $(if ((min_start==MAX_NUMBER)); then echo 'true'; else echo 'false'; fi)"
  if ((min_start==MAX_NUMBER)); then
    log vv "unmapped full match for ${key} is ${key} for ${range} (no remaining maps)"
    printf '%d ' "${key}" "${range}"
  else
    dest_range="$((min_start-key))"
    printf '%d ' "${key}" "${dest_range}"
    
    local remaining_range
    remaining_range="$((range-dest_range))"
    if ((remaining_range>0)); then
      log vv "unmapped partial match for ${key} is ${key} for ${dest_range} (leaving $((range-dest_range)))"
      mapping_for "${!map}" "${min_start}" "${remaining_range}"
    else
      log vv "unmapped full match for ${key} is ${key} for ${range} (next map start ${min_start})"
    fi
  fi
}

function process_inputs {
  local -n map=$1
  local key_range_line=$2

  local dedupd
  dedupd=$(dedup_inputs "${key_range_line}")
  read -ra inputs <<<"${dedupd}"

  log vv "${!map} [${inputs[*]}]"
  local input
  local range
  local -a mapped_inputs
  local min_location=0
  for ((i=0; i<${#inputs[@]}; i=i+2)); do
    input="${inputs[${i}]}"
    range="${inputs[$((i+1))]}"

    read -r -a mapped_inputs <<<"$(mapping_for "${!map}" "${input}" "${range}")"
    log v "${!map} $(printf "%d for %d -> [%s]\n" "${input}" "${range}" "$(printf '<<%s>>' "${mapped_inputs[@]}")")"
    printf '%s ' "${mapped_inputs[@]}"
  done
}

function main {
  local file="${1:-input.txt}"
  local path
  path="$(dirname "$(readlink --canonicalize-existing "$0")")/${file}"
  local sorted_path="${path%.txt}_sorted.txt"
  log v "begin main for ${path}"

  local current_map
  local lines
  local seeds
  exec 3< "${path}"
  while read -r -u 3 line; do
    case "${line}" in
      "seeds: "*)
        log vv "got seeds line ${line}"
        seeds="${line##seeds: }"
        printf 'seeds: %s\n\n' "$(dedup_inputs "${seeds}")" > "${sorted_path}"
        ;;
      *" map:")
        if [[ -n "${current_map}" ]]; then
          load_map "${current_map}" "${lines[@]}" >> "${sorted_path}"
          lines=()
        fi
        current_map="${line%% map:}"
        current_map="${current_map//-/_}"
        log vv "setting current map to ${current_map}"
        ;;
      *)
        if [[ -n "${line}" ]]; then
          log vv "got range line for ${current_map}: ${line}"
          lines+=("${line}")
        fi
        ;;
    esac
  done
  exec 3<&-

  load_map "${current_map}" "${lines[@]}" >> "${sorted_path}"
  exit 1

  local ranges
  # cant use this idiom:
  #   read -r -a some_array < <(echo -e -n "1 2 ")
  # because it fails (return non-zero), but
  #   read -r -a some_array <<<"1 2 "
  # does not...  turns out read will fail if it does not see its delim (newline)
  # and <<< automatically appends a newline to the string...  thats a very
  # painful footgun
  read -r -a ranges <<<"$(dedup_inputs \
    "$(process_inputs humidity_to_location \
      "$(process_inputs temperature_to_humidity \
        "$(process_inputs light_to_temperature \
          "$(process_inputs water_to_light \
            "$(process_inputs fertilizer_to_water \
              "$(process_inputs soil_to_fertilizer \
                "$(process_inputs seed_to_soil "${seeds}")")")")")")")")"
  echo -e "res [\n$(printf '  %s %s\n' "${ranges[@]}")\n]"

  # dedup_inputs results in sorted output so minimum location would be the very
  # first value
  printf 'Minimum location is: %d' "${ranges[0]}"
}

(return 0 2>/dev/null) || main "$@"
