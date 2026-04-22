#!/usr/bin/env bash
# Install the DDNS client on a Debian host. Must be run as root.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "must be run as root (try: sudo $0)" >&2
    exit 1
fi

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

BIN_PATH=/usr/local/bin/ddns-update.sh
ETC_DIR=/etc/ddns-client
STATE_DIR=/var/lib/ddns-client
SYSTEMD_DIR=/etc/systemd/system

# Create system user if missing
if ! id -u ddns >/dev/null 2>&1; then
    useradd --system --home-dir "$STATE_DIR" --shell /usr/sbin/nologin ddns
fi

install -d -m 0755 "$(dirname "$BIN_PATH")"
install -m 0755 "$SRC_DIR/ddns-update.sh" "$BIN_PATH"

install -d -m 0750 -o ddns -g ddns "$STATE_DIR"

install -d -m 0750 -o root -g ddns "$ETC_DIR"
if [[ ! -f "$ETC_DIR/ddns-client.env" ]]; then
    install -m 0640 -o root -g ddns "$SRC_DIR/ddns-client.env.example" "$ETC_DIR/ddns-client.env"
    echo "Wrote $ETC_DIR/ddns-client.env from example — EDIT IT with real API_URL, API_KEY, RECORD_NAME, IPV6_IFACE."
fi

install -m 0644 "$SRC_DIR/ddns-client.service" "$SYSTEMD_DIR/ddns-client.service"
install -m 0644 "$SRC_DIR/ddns-client.timer" "$SYSTEMD_DIR/ddns-client.timer"

systemctl daemon-reload
systemctl enable --now ddns-client.timer

echo ""
echo "Installed. Next steps:"
echo "  1. Edit $ETC_DIR/ddns-client.env"
echo "  2. sudo systemctl start ddns-client.service   # trigger an immediate run"
echo "  3. journalctl -u ddns-client.service -n 50    # check the result"
