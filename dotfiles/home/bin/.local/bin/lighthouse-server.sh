#!/bin/bash
lighthouse beacon \
  --network mainnet \
  --execution-endpoint "http://localhost:8551" \
  --execution-jwt "${HOME}/.ethereum/lighthouse/jwtsecret" \
  --checkpoint-sync-url "https://mainnet.checkpoint.sigp.io" \
  --http
