#!/usr/bin/env bash
set -euo pipefail

HOSTED_ZONE_ID="${1:?hosted zone id is required}"
RECORD_NAME="${2:?record name is required}"
STABLE_TARGET="${3:?stable target is required}"
CANARY_TARGET="${4:?canary target is required}"
CANARY_WEIGHT="${5:-10}"

if ! [[ "$CANARY_WEIGHT" =~ ^[0-9]+$ ]]; then
  echo "Canary weight must be an integer from 0 to 100." >&2
  exit 1
fi

if (( CANARY_WEIGHT < 0 || CANARY_WEIGHT > 100 )); then
  echo "Canary weight must be between 0 and 100." >&2
  exit 1
fi

STABLE_WEIGHT=$((100 - CANARY_WEIGHT))
RECORD_NAME="${RECORD_NAME%.}."
STABLE_TARGET="${STABLE_TARGET%.}."
CANARY_TARGET="${CANARY_TARGET%.}."
CHANGE_FILE="$(mktemp)"

cat > "$CHANGE_FILE" <<JSON
{
  "Comment": "Jenkins canary deployment update",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$RECORD_NAME",
        "Type": "CNAME",
        "SetIdentifier": "stable",
        "Weight": $STABLE_WEIGHT,
        "TTL": 30,
        "ResourceRecords": [
          { "Value": "$STABLE_TARGET" }
        ]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$RECORD_NAME",
        "Type": "CNAME",
        "SetIdentifier": "canary",
        "Weight": $CANARY_WEIGHT,
        "TTL": 30,
        "ResourceRecords": [
          { "Value": "$CANARY_TARGET" }
        ]
      }
    }
  ]
}
JSON

aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch "file://$CHANGE_FILE"

rm -f "$CHANGE_FILE"

echo "Route 53 updated: stable=$STABLE_WEIGHT canary=$CANARY_WEIGHT record=$RECORD_NAME"

