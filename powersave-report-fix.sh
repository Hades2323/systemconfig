#!/bin/bash

USE_TLP=1
[[ "$1" == "--no-tlp" ]] && USE_TLP=0 && shift
[[ "$1" == "--fix" ]] && FIX_MODE=1
[[ "$1" == "--restore" ]] && RESTORE_MODE=1

USER_NAME=$(logname 2>/dev/null || echo "$SUDO_USER")
USER_HOME=$(eval echo "~$USER_NAME")

BASE_DIR="$USER_HOME/report_risparmio"
BACKUP_DIR="$BASE_DIR/backup_config"
mkdir -p "$BASE_DIR" "$BACKUP_DIR"

HTML="$BASE_DIR/report_risparmio_energetico.html"
TXT="$BASE_DIR/report_risparmio_energetico.txt"
JSON="$BASE_DIR/report_risparmio_energetico.json"
TMP_HTML=$(mktemp)
TMP_TXT=$(mktemp)
TMP_JSON=$(mktemp)
DATE=$(date)

SUGGESTIONS=()

# ... [Qui va incluso il resto dello script esistente] ...
# Per brevità, assumiamo che tutto il codice precedente venga mantenuto

# Alla fine dello script, dopo aver creato i report:
chown "$USER_NAME":"$USER_NAME" "$HTML" "$TXT" "$JSON"
chown -R "$USER_NAME":"$USER_NAME" "$BACKUP_DIR"

# Durante la modalità --fix, se USE_TLP è 1, si installa/attiva TLP
if [[ "$FIX_MODE" == "1" ]]; then
  if [[ "$USE_TLP" == "1" ]]; then
    if ! dpkg -s tlp &>/dev/null; then
      echo "📦 TLP non trovato. Puoi installarlo con:"
      echo "sudo add-apt-repository ppa:linrunner/tlp && sudo apt update && sudo apt install tlp"
    else
      systemctl enable --now tlp
    fi
  fi
fi
