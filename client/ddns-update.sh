#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${DDNS_ENV_FILE:-/etc/ddns-client/ddns-client.env}"
STATE_DIR="${DDNS_STATE_DIR:-/var/lib/ddns-client}"
STATE_FILE="$STATE_DIR/state"

if [[ ! -r "$ENV_FILE" ]]; then
    echo "env file not readable: $ENV_FILE" >&2
    exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

: "${API_URL:?API_URL must be set in $ENV_FILE}"
: "${API_KEY:?API_KEY must be set in $ENV_FILE}"
: "${RECORD_NAME:?RECORD_NAME must be set in $ENV_FILE}"
: "${IPV6_IFACE:?IPV6_IFACE must be set in $ENV_FILE}"

mkdir -p "$STATE_DIR"

detect_ipv4() {
    curl -4 -fsS --max-time 5 https://ifconfig.me 2>/dev/null || true
}

detect_ipv6() {
    # Pick the first global, permanent (non-temporary, non-deprecated) IPv6
    # on the configured egress interface.
    ip -6 -o addr show dev "$IPV6_IFACE" scope global 2>/dev/null \
        | awk '!/temporary/ && !/deprecated/ { for (i=1;i<=NF;i++) if ($i=="inet6") { split($(i+1),a,"/"); print a[1]; exit } }' \
        || true
}

read_state_value() {
    local key="$1"
    [[ -f "$STATE_FILE" ]] || return 0
    grep -E "^${key}=" "$STATE_FILE" | tail -n 1 | cut -d= -f2- || true
}

write_state() {
    local new_v4="$1" new_v6="$2"
    local tmp
    tmp="$(mktemp "$STATE_FILE.XXXXXX")"
    {
        [[ -n "$new_v4" ]] && echo "ipv4=$new_v4"
        [[ -n "$new_v6" ]] && echo "ipv6=$new_v6"
    } > "$tmp"
    mv "$tmp" "$STATE_FILE"
}

current_v4="$(detect_ipv4)"
current_v6="$(detect_ipv6)"

if [[ -z "$current_v4" && -z "$current_v6" ]]; then
    echo "failed to detect any IP address" >&2
    exit 1
fi

prev_v4="$(read_state_value ipv4)"
prev_v6="$(read_state_value ipv6)"

if [[ "$current_v4" == "$prev_v4" && "$current_v6" == "$prev_v6" ]]; then
    echo "no change (v4=$current_v4 v6=$current_v6)"
    exit 0
fi

# Build JSON payload with only changed fields.
payload="{"
sep=""
if [[ -n "$current_v4" && "$current_v4" != "$prev_v4" ]]; then
    payload+="${sep}\"ipv4\":\"$current_v4\""
    sep=","
fi
if [[ -n "$current_v6" && "$current_v6" != "$prev_v6" ]]; then
    payload+="${sep}\"ipv6\":\"$current_v6\""
fi
payload+="}"

echo "posting update for $RECORD_NAME: $payload"

http_code=$(curl -sS -o /tmp/ddns-response.$$ -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "x-api-key: $API_KEY" \
    --max-time 15 \
    --data "$payload" \
    "$API_URL")

body="$(cat /tmp/ddns-response.$$ 2>/dev/null || true)"
rm -f /tmp/ddns-response.$$

if [[ "$http_code" != 2* ]]; then
    echo "update failed: HTTP $http_code body=$body" >&2
    exit 1
fi

echo "update ok: HTTP $http_code body=$body"
write_state "${current_v4:-$prev_v4}" "${current_v6:-$prev_v6}"
