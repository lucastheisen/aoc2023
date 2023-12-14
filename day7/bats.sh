#!/bin/bash

load calculate.sh

function rank_properly_ranks_random_hand { #@test
  diff -u \
    --label expected \
    <(echo -n "181414101410") \
    --label actual \
    <(rank "AATAT")
}

function rank_catches_all_full_houses { #@test
  for hand in \
      22233 22323 22332 23223 23232 \
      23322 32223 32232 32322 33222 \
      33322 33232 33223 32332 32323 \
      32233 23332 23323 23233 22333; do
    r="$(rank "${hand}")"
    if [[ ${r:0:2} != 18 ]]; then
      echo "${hand} is not detected as full house"
      exit 1
    fi
  done
}

function rank_catches_all_high_cards { #@test
  for line in \
      '65432 06' \
      '75432 07' \
      '85432 08' \
      '95432 09' \
      'T5432 10' \
      'J5432 11' \
      'Q5432 12' \
      'K5432 13' \
      'A5432 14'; do
    read -r hand category <<<"${line}"
    r="$(rank "${hand}")"
    if [[ ${r:0:2} != "${category}" ]]; then
      echo "${hand} is not detected as category ${category}"
      exit 1
    fi
  done
}

function every_single_possible_rank { #@test

}
