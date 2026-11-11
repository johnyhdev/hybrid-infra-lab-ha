#!/usr/bin/env bash
set -euo pipefail
umask 027
install -d -o root -g recovery-dispatcher -m 0750 /run/phase8-dispatcher
file="/run/phase8-dispatcher/.alertmanager.token.$$"
trap 'rm -f "$file"' EXIT
openssl rand -hex 32 > "$file"
chown root:recovery-dispatcher "$file"
chmod 0640 "$file"
mv -f "$file" /run/phase8-dispatcher/alertmanager.token
trap - EXIT
