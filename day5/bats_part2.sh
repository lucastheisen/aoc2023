#!/bin/bash

load calculate_part2.sh

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
