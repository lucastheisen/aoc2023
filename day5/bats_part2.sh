#!/bin/bash

load calculate_part2.sh
load process_line.sh

function dedup_merges_overlapping_ranges { #@test
  diff -u \
    --label expected \
    <(echo -n "2 13 ") \
    --label actual \
    <(dedup_inputs "5 10 8 4 2 3")
}

function mapping_for_range_fully_contained_in_map_prints_proper_mapping { #@test
  load_map foo "3 4 12"
  diff -u \
    --label expected \
    <(echo -n "4 10 ") \
    --label actual \
    <(mapping_for foo 5 10)
}

function process_inputs_value_range_is_entirely_before_mapping_range { #@test
  load_map foo "3 4 12"
  diff -u \
    --label expected \
    <(echo -en "2 2 ") \
    --label actual \
    <(process_inputs foo "2 2 ")
}

function process_inputs_value_range_starts_before_mapping_range_and_ends_inside { #@test
  load_map foo "3 4 12"
  diff -u \
    --label expected \
    <(echo -en "2 2 3 8 ") \
    --label actual \
    <(process_inputs foo "2 10 ")
}

function process_inputs_value_range_starts_before_mapping_range_and_ends_after { #@test
  load_map foo "3 4 12"
  diff -u \
    --label expected \
    <(echo -en "2 2 3 12 16 2 ") \
    --label actual \
    <(process_inputs foo "2 16 ")
}

function process_inputs_value_range_is_entirely_inside_mapping_range { #@test
  load_map foo "3 4 12"
  diff -u \
    --label expected \
    <(echo -en "5 10 ") \
    --label actual \
    <(process_inputs foo "6 10 ")
}

function process_inputs_value_range_starts_inside_mapping_range_and_ends_after { #@test
  load_map foo "3 4 12"
  diff -u \
    --label expected \
    <(echo -en "13 2 16 2 ") \
    --label actual \
    <(process_inputs foo "14 4 ")
}

function process_inputs_value_range_is_entirely_after_mapping_range { #@test
  load_map foo "3 4 12"
  diff -u \
    --label expected \
    <(echo -en "20 4 ") \
    --label actual \
    <(process_inputs foo "20 4 ")
}

function process_inputs_value_range_starts_at_zero { #@test
  load_map foo "3 4 12"
  diff -u \
    --label expected \
    <(echo -en "0 4 ") \
    --label actual \
    <(process_inputs foo "0 4 ")
}

function process_inputs_map_starts_at_zero { #@test
  load_map foo "3 0 12"
  diff -u \
    --label expected \
    <(echo -en "6 5 ") \
    --label actual \
    <(process_inputs foo "3 5 ")
}

function process_line_value_range_is_entirely_before_mapping_range { #@test
  diff -u \
    --label expected \
    <(echo -en "\n2 2\n") \
    --label actual \
    <(process_line "3 4 12" "2 2")
}

function process_line_value_range_starts_before_mapping_range_and_ends_inside { #@test
  diff -u \
    --label expected \
    <(echo -en "3 8\n2 2\n") \
    --label actual \
    <(process_line "3 4 12" "2 10")
}

function process_line_value_range_starts_before_mapping_range_and_ends_after { #@test
  diff -u \
    --label expected \
    <(echo -en "3 12\n2 2\n16 2\n") \
    --label actual \
    <(process_line "3 4 12" "2 16")
}

function process_line_value_range_is_entirely_inside_mapping_range { #@test
  diff -u \
    --label expected \
    <(echo -en "5 10\n") \
    --label actual \
    <(process_line "3 4 12" "6 10")
}

function process_line_value_range_starts_inside_mapping_range_and_ends_after { #@test
  diff -u \
    --label expected \
    <(echo -en "13 2\n16 2\n") \
    --label actual \
    <(process_line "3 4 12" "14 4")
}

function process_line_value_range_is_entirely_after_mapping_range { #@test
  diff -u \
    --label expected \
    <(echo -en "\n20 4\n") \
    --label actual \
    <(process_line "3 4 12" "20 4")
}

function process_line_value_range_starts_at_zero { #@test
  diff -u \
    --label expected \
    <(echo -en "\n0 4\n") \
    --label actual \
    <(process_line "3 4 12" "0 4")
}

function process_line_map_starts_at_zero { #@test
  diff -u \
    --label expected \
    <(echo -en "6 5\n") \
    --label actual \
    <(process_line "3 0 12" "3 5")
}

function sort_and_dedup_inputs_merges_overlapping_ranges { #@test
  diff -u \
    --label expected \
    <(echo -en "2 13\n") \
    --label actual \
    <(sort_and_dedup_inputs "$(echo -en "5 10\n8 4\n2 3\n")")
}

function sort_and_dedup_inputs_merges_partial_overlapping_ranges { #@test
  diff -u \
    --label expected \
    <(echo -en "10 17\n30 20\n") \
    --label actual \
    <(sort_and_dedup_inputs "$(echo -en "30 20\n10 14\n17 10\n")")
}

function sort_and_dedup_inputs_does_not_merge_separation_by_one { #@test
  diff -u \
    --label expected \
    <(echo -en "2 2\n5 10\n") \
    --label actual \
    <(sort_and_dedup_inputs "$(echo -en "5 10\n2 2\n")")
}
