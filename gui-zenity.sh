#!/bin/bash

SCRIPT="./powersave-report-fix.sh"
if [[ ! -x "$SCRIPT" ]]; then
  zenity --error --text="Lo script $SCRIPT non è eseguibile o mancante."
  exit 1
fi

CHOICE=$(zenity --list \
  --title="Ottimizzazione Energetica" \
  --text="Scegli un'azione da eseguire" \
  --radiolist \
  --column "✓" --column "Azione" \
  TRUE "Genera report (solo verifica)" \
  FALSE "Applica ottimizzazioni (Powertop + TLP)" \
  FALSE "Applica solo Powertop (senza TLP)" \
  FALSE "Ripristina configurazioni" \
  --width=460 --height=460)

case "$CHOICE" in
  "Genera report (solo verifica)")
    pkexec "$SCRIPT"
    ;;
  "Applica ottimizzazioni (Powertop + TLP)")
    pkexec "$SCRIPT" --fix
    ;;
  "Applica solo Powertop (senza TLP)")
    pkexec "$SCRIPT" --no-tlp --fix
    ;;
  "Ripristina configurazioni")
    pkexec "$SCRIPT" --restore
    ;;
  *)
    zenity --info --text="Operazione annullata."
    ;;
esac
