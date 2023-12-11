#!/bin/bash

set -e

# inputs tuples of start and length, one per line:
#
#   30 20
#   10 14
#   17 10
#
# inputs will be sorted by their start value and merged with any subsequent
# ranges that they overlap. sorted and deduplicated inputs will be printed to
# stdout in the same format:
#
#   10 17
#   30 20
function sort_and_dedup_inputs {
  local sorted_inputs
  readarray -t sorted_inputs < <(sort -n <<<"$1")
  log vvv "raw:\n$1\nsorted:\n$(printf '%s\n' "${sorted_inputs[@]}")"

  local num_inputs="${#sorted_inputs[@]}"
  local input range next_input next_range combined_range
  for ((i=0; i<num_inputs; i++)); do
    read -r input range <<<"${sorted_inputs[${i}]}"
    printf '%s ' "${input}"

    log vv "checking input[$i/${num_inputs}]: ${input} for ${range} (max value $((input+range)))"
    while ((i+1<num_inputs)); do
      read -r next_input next_range <<<"${sorted_inputs[$((i+1))]}"
      log vvv "checking ${next_input}"

      if ((next_input>input+range)); then
        break
      fi

      log vv "input ${input} for ${range} extends into ${next_input}"
      ((combined_range=(next_input+next_range-input)))
      if ((combined_range>range)); then
        range="${combined_range}"
      fi

      # dont use i++ because if i was zero, then the postfix will return the
      # original value which was zero which causes bash arithmetic to return 1
      # thus error out.  could use prefix ++ for increment but also dangerous
      # if i were ever -1. this approach is safe though
      ((i=i+1))
    done
    log vvv "${input} has range ${range}"
    printf '%s\n' "${range}"
  done
  
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

# prints out multiple lines where the first line is mapped data, and subsequent
# lines contain unmapped contiguous segments of data that can be fed into other
# maps as source
function process_line {
  local map=$1
  local input=$2
  log vv "checking input ${input} against map ${map}"

  local map_src map_dest map_len
  read -r map_dest map_src map_len <<<"${map}"
  local input_src input_len
  read -r input_src input_len <<<"${input}"

  local map_max_src
  ((map_max_src=map_src+map_len-1))
  local map_add_to_src
  ((map_add_to_src=map_dest-map_src))

  local input_max_src
  ((input_max_src=input_src+input_len-1))

  if ((input_max_src<map_src)); then
    log vv "${input} entirely before ${map} (input_max_src=${input_max_src}, map_src=${map_src})"
    printf '\n%s\n' "${input}"
    return
  fi

  if ((input_src>=map_max_src)); then
    log vv "${input} entirely after ${map} (input_src=${input_src}, map_max_src=${map_max_src})"
    printf '\n%s\n' "${input}"
    return
  fi

  local mapped_start mapped_end
  local unmapped_segment
  local -a unmapped
  if ((input_src<map_src)); then
    unmapped_segment="$(printf '%d %d' "${input_src}" "$((map_src-input_src))")"
    log vv "<${input}> starts before <${map}> (unmapped segment ${unmapped_segment})"
    unmapped+=("${unmapped_segment}")
    mapped_start="${map_src}"
  else
    log vv "<${input}> starts inside <${map}>"
    mapped_start="${input_src}"
  fi

  if ((input_max_src>map_max_src)); then
    unmapped_segment="$(printf '%d %d' "$((map_max_src+1))" "$((input_max_src-map_max_src))")"
    log vv "<${input}> ends after <${map}> (unmapped segment ${unmapped_segment})"
    unmapped+=("${unmapped_segment}")
    mapped_end="${map_max_src}"
  else
    log vv "<${input}> ends inside <${map}>"
    mapped_end="${input_max_src}"
  fi

  log vvv "process visual:\n$(
    printf 'input:  % 12d % 12d\nmap:    % 12d % 12d\nmapped: % 12d % 12d (add %d)\n' \
      "${input_src}" \
      "${input_max_src}" \
      "${map_src}" \
      "${map_max_src}" \
      "${mapped_start}" \
      "${mapped_end}" \
      "${map_add_to_src}")"
  printf '%d %d\n' "$((mapped_start+map_add_to_src))" "$((mapped_end-mapped_start+1))"
  if ((${#unmapped[@]}>0)); then
    printf '%s\n' "${unmapped[@]}"
  fi
}

function process_map {
  local mappings=$1
  local inputs=$2

  local input_lines mapping_lines
  readarray -t mapping_lines < <(sort -k 2 -n <<<"${mappings}" | sed '/^[[:space:]]*$/d')
  log vvv "mapping lines:\n$(printf '%s\n' "${mapping_lines[@]}")\n"
  readarray -t input_lines < <(sort_and_dedup_inputs "${inputs}")
  log vvv "input lines:\n$(printf '%s\n' "${input_lines[@]}")\n"

  local -a result_lines
  local i input_line mapping_line
  for ((i=0; i<${#input_lines[@]}; i++)); do
    input_line="${input_lines["${i}"]}"
    for mapping_line in "${mapping_lines[@]}"; do
      readarray -t result_lines < <(process_line "${mapping_line}" "${input_line}")
      if [[ -z "${result_lines[0]}" ]]; then
        continue
      fi
      log vv "[${input_line}] mapped by [${mapping_line}]"
      printf '%s\n' "${result_lines[0]}"
      if ((${#result_lines[@]}>1)); then
        log vv "adding remaining ranges (${#result_lines[@]}) back to inputs: [${result_lines[*]:1}]"
        input_lines+=("${result_lines[@]:1}")
      fi
      continue 2
    done
    log vv "[${input_line}] unmapped"
    printf '%s\n' "${input_line}"
  done
}

function main {
  local file="${1:-input.txt}"
  local path
  path="$(dirname "$(readlink --canonicalize-existing "$0")")/${file}"
  log v "begin main for ${path}"

  local -A maps
  local current_map
  local seeds
  exec 3< "${path}"
  while read -r -u 3 line; do
    case "${line}" in
      "seeds: "*)
        log vv "got seeds line ${line}"
        read -ra seeds_list <<<"${line##seeds: }"
        seeds="$(printf '%d %d\n' "${seeds_list[@]}")"
        ;;
      *" map:")
        current_map="${line%% map:}"
        current_map="${current_map//-/_}"
        log vv "setting current map to ${current_map}"
        ;;
      *)
        if [[ -n "${line}" ]]; then
          maps["${current_map}"]+="${line}"$'\n'
        fi
        ;;
    esac
  done
  exec 3<&-

  local ordered_maps=(
    seed_to_soil
    soil_to_fertilizer
    fertilizer_to_water
    water_to_light
    light_to_temperature
    temperature_to_humidity
    humidity_to_location
  )
  local map inputs
  inputs="${seeds}"
  for map in "${ordered_maps[@]}"; do
    log v "processing map ${map}"
    inputs="$(process_map "${maps["${map}"]}" "${inputs}")"
  done
  printf 'inputs:\n%s' "$(sort_and_dedup_inputs "${inputs}")"
}

(return 0 2>/dev/null) || main "$@"
