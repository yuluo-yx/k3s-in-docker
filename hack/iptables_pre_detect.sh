#!/bin/bash

set -e

nft_valid=false
legacy_valid=false

if xtables-legacy-multi iptables -L > /dev/null 2>&1 ; then
  legacy_valid=true
fi

if xtables-nft-multi iptables -L > /dev/null 2>&1 ; then
  nft_valid=true
fi

if [ "$legacy_valid" = true ] && [ "$nft_valid" != true ]; then
  export IPTABLES_MODE=legacy
  iptables -V > /dev/null
elif [ "$legacy_valid" != true ] && [ "$nft_valid" = true ]; then
  export IPTABLES_MODE=nft
  iptables -V > /dev/null
fi
