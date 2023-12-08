#!/bin/bash

function load_map {
  local -n map=$1
  map=("${@:2}")
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

function get_value {
  local -n map=$1
  local key=$2

  local mapping dest src len
  for mapping in "${map[@]}"; do
    read -r dest src len <<<"${mapping}"
    if ((key>=src)) && ((key<src+len)); then
      log vv "match for $key in mapping [${mapping}]"
      echo -n "$((dest+(key-src)))"
      return
    fi
  done
  echo -n "${key}"
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
  local max_number=9223372036854775807
  local min_start="${max_number}"
  for start in "${range_starts[@]}"; do
    log vvv "range start ${start} key=${key} min_start=${min_start}"
    if ((start>key)) && ((start<min_start)); then
      min_start="${start}"
    fi
  done
  if ((min_start==max_number)); then
    log vv "unmapped full match for ${key} is ${key} for ${range}"
    printf '%d ' "${key}" "${range}"
  else
    dest_range="$((min_start-key))"
    log vv "unmapped partial match for ${key} is ${key} for ${dest_range} (leaving $((range-dest_range)))"
    printf '%d ' "${key}" "${dest_range}"
    
    local remaining_range
    remaining_range="$((range-dest_range))"
    if ((remaining_range>0)); then
      mapping_for "${!map}" "${min_start}" "${remaining_range}"
    fi
  fi
}

function process_inputs {
  local -n map=$1
  local key_range_line=$2
  read -ra seeds <<<"${key_range_line}"

  local seed
  local seed_range
  local min_location=0
  for ((i=0; i<${#seeds[@]}; i=i+2)); do
    seed="${seeds[${i}]}"
    seed_range="${seeds[$((i+1))]}"
    log vv "[${seeds[*]}] seed=[${seed}], seed_range=[${seed_range}]"

    local mapped_inputs
    read -r -a mapped_inputs < <(mapping_for "${!map}" "${seed}" "${seed_range}")
    log vvv "$(printf "%d for %d -> %s\n" "${seed}" "${seed_range}" "$(printf '<<%s>>' "${mapped_inputs[@]}")")"
    printf '%s ' "${mapped_inputs[@]}"
  done
}

function main {
  local file="${1:-input.txt}"
  log v "begin main for ${file}"

  local current_map
  local lines
  local seeds
  exec 3< "$(dirname "$(readlink --canonicalize-existing "$0")")/${file}"
  while read -r -u 3 line; do
    case "${line}" in
      "seeds: "*)
        log vv "got seeds line ${line}"
        seeds="${line##seeds: }"
        ;;
      *" map:")
        if [[ -n "${current_map}" ]]; then
          load_map "${current_map}" "${lines[@]}"
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

  load_map "${current_map}" "${lines[@]}"

  local ranges
  read -r -a ranges < <(process_inputs humidity_to_location \
    "$(process_inputs temperature_to_humidity \
      "$(process_inputs light_to_temperature \
        "$(process_inputs water_to_light \
          "$(process_inputs fertilizer_to_water \
            "$(process_inputs seed_to_soil "${seeds}")")")")")")
  echo "res [$(printf '%s ' "${ranges[@]}")]"

  local max_number=9223372036854775807
  local min_location="${max_number}"
  for ((i=0; i<${#ranges[@]}; i=i+2)); do
    if ((ranges[i]<min_location)); then
      min_location="${ranges["${i}"]}"
    fi
  done
  printf 'Minimum location is: %d' "${min_location}"
}

main "$@"
