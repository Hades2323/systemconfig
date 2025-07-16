#!/usr/bin/env bash
set -e

echo "🔧 Configurazione OneDrive per multi account separati con systemd"

# === INPUT UTENTE: NUMERO E NOMI ACCOUNT ===

echo "🔒 ATTENZIONE: Ogni nome account deve iniziare con il prefisso 'onedrive-' (es: onedrive-personale, onedrive-lavoro)"
read -rp "Quanti account OneDrive vuoi configurare? (minimo 1): " N_ACCOUNTS
while ! [[ $N_ACCOUNTS =~ ^[1-9][0-9]*$ ]]; do
  echo "❌ Inserisci un numero valido (minimo 1)."
  read -rp "Quanti account OneDrive vuoi configurare? (minimo 1): " N_ACCOUNTS
done

declare -a ACCOUNTS CONFIGS SYNC_DIRS SERVICES

for ((i=1; i<=N_ACCOUNTS; i++)); do
  while true; do
    read -rp "Inserisci il nome per l'account #$i (es: onedrive-personale): " ACCOUNT
    if [[ $ACCOUNT =~ ^onedrive- ]]; then
      break
    else
      echo "❌ Il nome deve iniziare con 'onedrive-'! Riprova."
    fi
  done
  ACCOUNTS+=("$ACCOUNT")
  CONFIGS+=("$HOME/.config/$ACCOUNT")
  SYNC_DIRS+=("$HOME/${ACCOUNT^}")
  SERVICES+=("$ACCOUNT.service")
done

# === PULIZIA CONFIGURAZIONI PRECEDENTI ===

echo "🧹 Rimozione di tutte le vecchie configurazioni di OneDrive..."

# Termina eventuali processi onedrive attivi
pkill -u "$USER" onedrive 2>/dev/null || true

# Disabilita e rimuove eventuali servizi systemd utente esistenti (tutti i possibili onedriv*)
for svc in "$HOME/.config/systemd/user/"onedriv*.service" "$HOME/.config/systemd/user/"OneDriv*.service" "$HOME/.config/systemd/user/"ONEDRIV*.service"; do
  [ -e "$svc" ] || continue
  svc_name=$(basename "$svc")
  systemctl --user stop "$svc_name" 2>/dev/null || true
  systemctl --user disable "$svc_name" 2>/dev/null || true
  rm -f "$svc"
done

# Rimuove tutte le cartelle e file di configurazione che iniziano per onedriv*
find "$HOME/.config" -maxdepth 1 -type d -name 'onedriv*' -exec rm -rf {} +
find "$HOME/.cache" -maxdepth 1 -type d -name 'onedriv*' -exec rm -rf {} +
find "$HOME" -maxdepth 1 -type d -name 'OneDriv*' -exec rm -rf {} +

# Ricarica systemd per evitare errori successivi
systemctl --user daemon-reload 2>/dev/null || true

echo "✅ Vecchie configurazioni rimosse."

# === CONFIGURAZIONE ACCOUNT ===
for ((i=0; i<N_ACCOUNTS; i++)); do
  echo ""
  echo "📁 [$(($i+1))/$N_ACCOUNTS] Configurazione ACCOUNT: ${ACCOUNTS[$i]}"
  mkdir -p "${CONFIGS[$i]}"
  mkdir -p "${SYNC_DIRS[$i]}"
  echo "🧠 Avvia autenticazione per l'account ${ACCOUNTS[$i]}..."
  onedrive --confdir "${CONFIGS[$i]}"
  echo "📄 Genero file config per l'account ${ACCOUNTS[$i]}..."
  onedrive --display-config 2>/dev/null | grep -Ev '^(Reading configuration file:|Configuration file successfully loaded)' > "${CONFIGS[$i]}/config"
  echo "🛠️ Personalizzo config (sync_dir)..."
  sed -i "s|^sync_dir = .*|sync_dir = \"${SYNC_DIRS[$i]}\"|g" "${CONFIGS[$i]}/config"
  sed -i "s|^# monitor_enabled =.*|monitor_enabled = true|g" "${CONFIGS[$i]}/config"
done

# === SERVIZI SYSTEMD ===
echo ""
echo "⚙️ Creazione dei servizi systemd utente..."
echo "ℹ️ Se ricevi errori relativi a DBUS o systemd user, assicurati di eseguire questo script da un terminale grafico (come xfce-terminal, gnome-terminal, ecc.) all'interno della tua sessione desktop."
SYSTEMD_PATH="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_PATH"
for ((i=0; i<N_ACCOUNTS; i++)); do
  cat > "$SYSTEMD_PATH/${SERVICES[$i]}" <<EOF
[Unit]
Description=OneDrive (${ACCOUNTS[$i]})
After=network-online.target

[Service]
ExecStart=/usr/bin/onedrive --monitor --confdir=${CONFIGS[$i]}
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF
done

# === ATTIVAZIONE ===
echo "🚀 Ricarico systemd e attivo tutti i servizi..."
systemctl --user daemon-reload
for svc in "${SERVICES[@]}"; do
  systemctl --user enable --now "$svc"
done

# === VERIFICA ===
echo ""
echo "✅ Configurazione completata con successo!"
echo "🔍 Stato servizi:"
for svc in "${SERVICES[@]}"; do
  systemctl --user status "$svc" --no-pager
done
