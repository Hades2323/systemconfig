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
  TRUE "Genera report" \
  FALSE "Applica ottimizzazioni (--fix)" \
  FALSE "Ripristina configurazioni (--restore)" \
  --width=400 --height=250)

case "$CHOICE" in
  "Genera report")
    pkexec "$SCRIPT"
    ;;
  "Applica ottimizzazioni (--fix)")
    pkexec "$SCRIPT" --fix
    ;;
  "Ripristina configurazioni (--restore)")
    pkexec "$SCRIPT" --restore
    ;;
  *)
    zenity --info --text="Operazione annullata."
    ;;
esac
