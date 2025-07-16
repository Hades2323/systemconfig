# systemconfig
Script per controllo e possibile fix dei diversi aspetti del sistema operativo


# powersave-report-fix.sh
### ✅ Funzionalità principali 
--fix	Applica le ottimizzazioni (governor, TLP, Powertop, USB, Wi-Fi) \
--restore	Ripristina le configurazioni originali salvate prima del fix \
Backup automatico	Salva configurazioni modificate in una cartella dedicata \
Report multipli	Genera .html, .txt, .json nella home dell’utente

### 📁 Percorsi dei file salvati
Report generati in: ~/report_risparmio/

### Backup dei file modificati in: ~/report_risparmio/backup_config/

### 🔧 CONFIGURAZIONI SALVATE DURANTE --fix
/etc/tlp.conf	backup se presente/modificato \
governor per ogni core CPU	salva valori in .bak_governor \
USB autosuspend per ogni device	salva valori .usb_suspend_state \
Stato Wi-Fi powersave	salvato per ogni interfaccia \

#### 📝 Script (testato su Ubuntu)
