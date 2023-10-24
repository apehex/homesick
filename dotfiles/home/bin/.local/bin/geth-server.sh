#!/bin/bash
# geth --mainnet --config geth.config.toml
geth --mainnet --syncmode snap --signer "${HOME}/.ethereum/clef/clef.ipc"  --config "${HOME}/.ethereum/geth/config.toml"
