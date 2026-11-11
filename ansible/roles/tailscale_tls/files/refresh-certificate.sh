#!/usr/bin/env bash
set -euo pipefail

cert=/etc/phase8/tls/tls.crt
key=/etc/phase8/tls/tls.key
mkdir -p /etc/phase8/tls
chmod 0750 /etc/phase8/tls

if [[ -s "$cert" ]] && openssl x509 -in "$cert" -noout -checkend 1209600 >/dev/null 2>&1; then
  exit 0
fi

dns_name="$(tailscale status --json | jq -r '.Self.DNSName // empty' | sed 's/\.$//')"
if [[ -z "$dns_name" ]]; then
  echo "Tailscale DNS name unavailable; certificate not issued" >&2
  exit 1
fi

tailscale cert --cert-file "$cert" --key-file "$key" "$dns_name"
chown root:phase8-tls "$cert" "$key"
chmod 0644 "$cert"
chmod 0640 "$key"
echo "Issued or renewed TLS certificate for $dns_name"

systemctl try-reload-or-restart nginx.service >/dev/null 2>&1 || true
systemctl try-restart node_exporter.service >/dev/null 2>&1 || true
systemctl try-restart loki.service >/dev/null 2>&1 || true
systemctl try-restart postgresql.service >/dev/null 2>&1 || true
