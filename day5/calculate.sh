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
        read -ra seeds <<<"${line##seeds: }"
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

  log v "seed_to_soil=[${seed_to_soil[*]}]"

  local seed
  local soil
  local fertilizer
  local min_location
  for seed in "${seeds[@]}"; do
    log vv "seed=[${seed}]"
    soil="$(get_value seed_to_soil "${seed}")"
    log vv "soil=[${soil}]"
    fertilizer="$(get_value soil_to_fertilizer "${soil}")"
    log vv "fertilizer=[${fertilizer}]"
    water="$(get_value fertilizer_to_water "${fertilizer}")"
    log vv "water=[${water}]"
    light="$(get_value water_to_light "${water}")"
    log vv "light=[${light}]"
    temperature="$(get_value light_to_temperature "${light}")"
    log vv "temperature=[${temperature}]"
    humidity="$(get_value temperature_to_humidity "${temperature}")"
    log vv "humidity=[${humidity}]"
    location="$(get_value humidity_to_location "${humidity}")"
    log vv "location=[${location}]"
    log v "seed ${seed} -> soil ${soil} -> fertilizer ${fertilizer} -> water ${water} -> light ${light} -> temperature ${temperature} -> humidity ${humidity} -> location ${location}"
    if [[ -z "${min_location}" ]] || ((location<min_location)); then
      min_location="${location}"
    fi
  done

  printf 'Minimum location is: %d' "${min_location}"
}

main "$@"
