#!/usr/bin/env bash

set -euo pipefail

MACHINES=("etna" "vesuvio")

if [ -z "$WEBHOOK_URL" ]; then
    echo "WEBHOOK_URL is not set"
    exit 1
fi

DOWN=()

for machine in "${MACHINES[@]}"; do
    if ssh "$machine" 'exit'; then
        echo "Connection to $machine is OK"
    else
        echo "Connection to $machine is NOT OK"
        DOWN+=("$machine")
    fi
done

DATETIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ARRAY=$(jq -c -n '$ARGS.positional' --args -- "${DOWN[@]}")
jq ". += [{\"time\": \"$DATETIME\", \"down\": $ARRAY}]" status.json >status.json.tmp

readarray -t LAST_DOWN < <(jq -r '. | sort_by(.time)[-1].down[]' status.json)

if ((${#DOWN[@]})) && [ "${DOWN[*]}" != "${LAST_DOWN[*]}" ]; then
    echo "Sending notification"
    curl -X POST -H "Content-Type: application/json" -d "{\"content\": \"<@319463560356823050> machines are down: ${DOWN[*]}\"}" "$WEBHOOK_URL"
fi

mv status.json.tmp status.json
