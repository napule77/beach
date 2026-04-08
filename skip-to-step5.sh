#!/usr/bin/env bash
# Segna gli step 0-4 come già completati nello state file dell'installer.
# Esegui questo script sulla VPS prima di lanciare install-vps.sh.

STATE_FILE="/opt/.beach-install-state"

printf 'step-0\nstep-1\nstep-2\nstep-3\nstep-4\n' > "${STATE_FILE}"

echo "State file scritto in ${STATE_FILE}:"
cat "${STATE_FILE}"
echo ""
echo "Ora lancia: bash /opt/install-vps.sh"
echo "Lo script ripartirà dallo step 5."
