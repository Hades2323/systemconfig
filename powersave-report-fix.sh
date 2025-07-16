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

# Se in modalità restore
if [[ "$RESTORE_MODE" -eq 1 ]]; then
  echo "♻️ Modalità RESTORE: ripristino le configurazioni..."

  if [ -f "$BACKUP_DIR/.bak_governor" ]; then
    echo "↩️  Ripristino CPU governor..."
    IFS=$'\n'
    for line in $(cat "$BACKUP_DIR/.bak_governor"); do
      core=$(echo "$line" | cut -d':' -f1)
      gov=$(echo "$line" | cut -d':' -f2)
      echo "$gov" > "/sys/devices/system/cpu/$core/cpufreq/scaling_governor"
    done
  fi

  if [ -f "$BACKUP_DIR/.usb_suspend_state" ]; then
    echo "↩️  Ripristino USB autosuspend..."
    while read -r path state; do
      echo "$state" > "$path" 2>/dev/null
    done < "$BACKUP_DIR/.usb_suspend_state"
  fi

  if [ -f "$BACKUP_DIR/.wifi_powersave_state" ]; then
    echo "↩️  Ripristino Wi-Fi powersave..."
    while read -r iface state; do
      iw dev "$iface" set power_save "$state" 2>/dev/null
    done < "$BACKUP_DIR/.wifi_powersave_state"
  fi

  if [ -f "$BACKUP_DIR/tlp.conf.bak" ]; then
    echo "↩️  Ripristino /etc/tlp.conf"
    cp "$BACKUP_DIR/tlp.conf.bak" /etc/tlp.conf
  fi

  echo "✅ Configurazioni ripristinate."
  exit 0
fi

# Funzioni HTML
escape_html() { echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

html_header() {
cat <<EOF
<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="UTF-8">
  <title>Report Risparmio Energetico</title>
  <style>
    body { font-family: sans-serif; background: #f5f5f5; padding: 2em; color: #333; }
    h1 { color: #2a2a2a; }
    .ok { color: green; font-weight: bold; }
    .warn { color: orange; font-weight: bold; }
    .err { color: red; font-weight: bold; }
    pre { background: #eee; padding: 1em; border-radius: 8px; overflow-x: auto; }
    .suggest { background: #fff3cd; padding: 1em; border-left: 5px solid #ffc107; margin: 1em 0; }
  </style>
</head>
<body>
<h1>💻 Report Risparmio Energetico</h1>
<p><b>Generato:</b> $DATE</p>
EOF
}

html_footer() {
  if [[ ${#SUGGESTIONS[@]} -gt 0 ]]; then
    echo "<h2>🛠️ Suggerimenti di ottimizzazione</h2>" >> "$TMP_HTML"
    for s in "${SUGGESTIONS[@]}"; do
      echo "<div class='suggest'>💡 $s</div>" >> "$TMP_HTML"
    done
  fi
  echo "</body></html>" >> "$TMP_HTML"
}

section() {
  echo "<h2>$1</h2><pre>$(escape_html "$2")</pre>" >> "$TMP_HTML"
  echo -e "\n## $1\n$2" >> "$TMP_TXT"
}

json_entry() {
  echo "\"$1\": \"$2\"," >> "$TMP_JSON"
}

start_json() {
  echo "{" > "$TMP_JSON"
  json_entry "generato" "$DATE"
}

end_json() {
  echo "\"suggerimenti\": [" >> "$TMP_JSON"
  for s in "${SUGGESTIONS[@]}"; do
    echo "\"$s\"," >> "$TMP_JSON"
  done
  sed -i '$ s/,$//' "$TMP_JSON"
  echo "]" >> "$TMP_JSON"
  echo "}" >> "$TMP_JSON"
}

check_status() {
  if eval "$1" &>/dev/null; then
    echo "<p class='ok'>✔️ $2</p>" >> "$TMP_HTML"
    echo "✔️ $2" >> "$TMP_TXT"
    json_entry "$2" "ok"
  else
    echo "<p class='err'>❌ $3</p>" >> "$TMP_HTML"
    echo "❌ $3" >> "$TMP_TXT"
    json_entry "$2" "missing"
    SUGGESTIONS+=("$4")
  fi
}

html_header
start_json

info_hw=$(cat <<EOF
Modello: $(sudo dmidecode -s system-product-name 2>/dev/null)
CPU: $(lscpu | grep "Model name" | cut -d: -f2 | xargs)
RAM: $(free -h | grep Mem | awk '{print $2}')
GPU: $(lspci | grep -i 'vga\|3d\|display' | cut -d: -f3)
Disco: $(lsblk -o MODEL,SIZE | grep -i nvme)
EOF
)
section "🖥️ Informazioni Hardware" "$info_hw"

governor_bad=0
gov_json=""
for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
  gov=$(cat "$cpu/cpufreq/scaling_governor" 2>/dev/null)
  gov_json+="CPU ${cpu##*/}: $gov; "
  [[ "$gov" != "powersave" ]] && governor_bad=1
done

if [[ $governor_bad -eq 0 ]]; then
  echo "<p class='ok'>✔️ CPU governor impostato su powersave</p>" >> "$TMP_HTML"
  echo "✔️ CPU governor: powersave" >> "$TMP_TXT"
  json_entry "CPU governor" "powersave"
else
  echo "<p class='warn'>⚠️ Alcuni core non usano powersave</p>" >> "$TMP_HTML"
  echo "⚠️ CPU governor non uniforme" >> "$TMP_TXT"
  json_entry "CPU governor" "partial"
  SUGGESTIONS+=("Imposta tutti i core su powersave con: <code>for c in /sys/devices/system/cpu/cpu[0-9]*; do echo powersave | sudo tee \$c/cpufreq/scaling_governor; done</code>")
fi

section "⚙️ Stato CPU governor" "$gov_json"

check_status "systemctl is-active --quiet tlp"   "TLP attivo" "TLP non attivo"   "Installa e abilita TLP con: <code>sudo apt install tlp && sudo systemctl enable --now tlp</code>"

if [ -f /etc/tlp.conf ]; then
  if grep -v '^#' /etc/tlp.conf | grep -q .; then
    section "📜 Configurazioni tlp.conf" "$(grep -v '^#' /etc/tlp.conf | grep .)"
  else
    SUGGESTIONS+=("Personalizza <code>/etc/tlp.conf</code> per ottimizzare il risparmio energetico. Vedi: <code>man tlp</code>")
  fi
else
  SUGGESTIONS+=("Crea un file <code>/etc/tlp.conf</code> personalizzato per regolare il comportamento energetico avanzato.")
fi

check_status "systemctl is-enabled --quiet powertop.service"   "Powertop abilitato come servizio" "Powertop non abilitato"   "Abilita powertop come servizio con: <code>sudo systemctl enable --now powertop.service</code>"

if journalctl -u powertop --no-pager | grep -qi auto-tune; then
  echo "<p class='ok'>✔️ Powertop --auto-tune eseguito</p>" >> "$TMP_HTML"
  json_entry "Powertop auto-tune" "ok"
else
  echo "<p class='warn'>⚠️ Powertop --auto-tune non trovato nei log</p>" >> "$TMP_HTML"
  json_entry "Powertop auto-tune" "missing"
  SUGGESTIONS+=("Esegui powertop --auto-tune all'avvio. Aggiungi a systemd o usa un timer.")
fi

usb_state=$(grep . /sys/bus/usb/devices/*/power/control 2>/dev/null | sort | uniq -c)
section "🔌 Stato USB autosuspend" "$usb_state"

pcie_aspm=$(cat /sys/module/pcie_aspm/parameters/policy 2>/dev/null)
section "🔧 PCIe ASPM" "$pcie_aspm"
[[ "$pcie_aspm" != *powersave* ]] && SUGGESTIONS+=("Attiva PCIe ASPM impostando GRUB con: <code>pcie_aspm=force</code>")

wifi_state=""
for iface in $(iw dev | awk '$1=="Interface"{print $2}'); do
  wifi_state+="$iface: $(iw dev $iface get power_save 2>/dev/null)\n"
done
section "📡 Power Save Wi-Fi" "$wifi_state"

sleep_modes=$(cat /sys/power/mem_sleep 2>/dev/null)
section "🌙 Modalità sospensione" "$sleep_modes"

html_footer
end_json

if [[ "$FIX_MODE" -eq 1 ]]; then
  echo "📥 Salvo configurazioni correnti..."
  : > "$BACKUP_DIR/.bak_governor"
  for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    gov=$(cat "$cpu/cpufreq/scaling_governor" 2>/dev/null)
    echo "${cpu##*/}:$gov" >> "$BACKUP_DIR/.bak_governor"
  done

  : > "$BACKUP_DIR/.usb_suspend_state"
  for f in /sys/bus/usb/devices/*/power/control; do
    [ -f "$f" ] && echo "$f $(cat $f)" >> "$BACKUP_DIR/.usb_suspend_state"
  done

  : > "$BACKUP_DIR/.wifi_powersave_state"
  for iface in $(iw dev | awk '$1=="Interface"{print $2}'); do
    state=$(iw dev "$iface" get power_save | awk '{print $NF}')
    echo "$iface $state" >> "$BACKUP_DIR/.wifi_powersave_state"
  done

  [ -f /etc/tlp.conf ] && cp /etc/tlp.conf "$BACKUP_DIR/tlp.conf.bak"

  echo "⚙️ Modalità AUTO-TUNE attiva: applico ottimizzazioni..."
  for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    echo powersave > "$cpu/cpufreq/scaling_governor" 2>/dev/null
  done

  if ! dpkg -s tlp &>/dev/null; then
    echo "📦 Installo TLP..."
    apt install -y tlp
  fi
  systemctl enable --now tlp

  if ! dpkg -s powertop &>/dev/null; then
    echo "📦 Installo Powertop..."
    apt install -y powertop
  fi
  systemctl enable --now powertop.service

  echo "⚡ Eseguo powertop --auto-tune..."
  powertop --auto-tune

  echo "🔌 Abilito autosuspend per dispositivi USB..."
  for f in /sys/bus/usb/devices/*/power/control; do
    echo auto > "$f" 2>/dev/null
  done

  echo "📡 Attivo power_save sul Wi-Fi (se disponibile)..."
  for iface in $(iw dev | awk '$1=="Interface"{print $2}'); do
    iw dev "$iface" set power_save on 2>/dev/null
  done

  echo "✅ Ottimizzazioni applicate. Rigenera ora il report per verificare."
fi

mv "$TMP_HTML" "$HTML"
mv "$TMP_TXT" "$TXT"
mv "$TMP_JSON" "$JSON"

# Cambia proprietario e permessi dei file a utente "reale"
USER_NAME=$(logname 2>/dev/null || echo "$SUDO_USER")
USER_HOME=$(eval echo "~$USER_NAME")

chown "$USER_NAME":"$USER_NAME" "$HTML" "$TXT" "$JSON"
chmod 644 "$HTML" "$TXT" "$JSON"

chown -R "$USER_NAME":"$USER_NAME" "$BACKUP_DIR"
chmod -R u+rwX,g-rwx,o-rwx "$BACKUP_DIR"

echo "✅ Report generato:"
echo "📝 HTML: $HTML"
echo "🧾 TXT: $TXT"
echo "📊 JSON: $JSON"

# Durante la modalità --fix, se USE_TLP è 1, si installa/attiva TLP

if [[ "$FIX_MODE" == "1" ]]; then
  echo "⚙️ Modalità AUTO-TUNE attiva: applico ottimizzazioni..."

  # 🔧 TLP
  if [[ "$USE_TLP" == "1" ]]; then
    if ! dpkg -s tlp &>/dev/null; then
      echo "📦 TLP non trovato. Puoi installarlo con:"
      echo "sudo add-apt-repository ppa:linrunner/tlp && sudo apt update && sudo apt install tlp"
    else
      echo "✅ TLP installato. Abilito servizio..."
      systemctl enable --now tlp

      echo "📁 Applico configurazione TLP ottimizzata..."
      cp /etc/tlp.conf "$BACKUP_DIR/tlp.conf.bak"
      cat <<EOF > /etc/tlp.conf
CPU_SCALING_GOVERNOR_ON_AC=powersave
CPU_SCALING_GOVERNOR_ON_BAT=powersave
PCIE_ASPM_ON_AC=powersave
PCIE_ASPM_ON_BAT=powersupersave
USB_AUTOSUSPEND=1
USB_BLACKLIST_BTUSB=0
WIFI_PWR_ON_AC=on
WIFI_PWR_ON_BAT=on
SOUND_POWER_SAVE_ON_AC=1
SOUND_POWER_SAVE_ON_BAT=1
SATA_LINKPWR_ON_AC=min_power
SATA_LINKPWR_ON_BAT=min_power
EOF
    fi
  fi

  # ⚡ powertop --auto-tune systemd service
  echo "🛠️ Creo servizio powertop-autotune..."
  cat <<EOF > /etc/systemd/system/powertop-autotune.service
[Unit]
Description=Powertop auto-tune
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/powertop --auto-tune

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reexec
  systemctl enable --now powertop-autotune.service
fi

# Simula i report
echo "<html><body><h1>Report $DATE</h1></body></html>" > "$HTML"
echo "Report generato il $DATE" > "$TXT"
echo "{\"report\": \"$DATE\"}" > "$JSON"

# Imposta i permessi corretti all'utente
chown "$USER_NAME":"$USER_NAME" "$HTML" "$TXT" "$JSON"
chown -R "$USER_NAME":"$USER_NAME" "$BACKUP_DIR"

echo "✅ Report salvato in: $BASE_DIR"
