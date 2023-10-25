#!/bin/bash
geth --mainnet --syncmode snap --signer "${HOME}/.ethereum/clef/clef.ipc" --config "${HOME}/.ethereum/geth/config.toml"
