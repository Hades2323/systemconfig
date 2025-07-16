


## powersave-report-fix.sh possibilità di utilizzare la gui gui-zenity.sh
### ✅ Funzionalità principali 
--fix	Applica le ottimizzazioni (governor, TLP, Powertop, USB, Wi-Fi) \
--no-tlp Applica le ottimizzazioni senza TLP \
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

---

## Script di Configurazione Multi-Account OneDrive con systemd
> Script realizzato per una gestione semplice e robusta di più account OneDrive su Linux.

Questo script bash consente di configurare facilmente più account OneDrive separati su Linux, ognuno con la propria cartella di sincronizzazione e servizio systemd utente dedicato.

### Funzionalità

- Pulizia automatica di tutte le vecchie configurazioni e servizi OneDrive residui.
- Configurazione guidata per un numero arbitrario di account OneDrive.
- Ogni account viene autenticato e configurato separatamente.
- Creazione e attivazione automatica dei servizi systemd per ogni account.
- Supporto a nomi account personalizzati (con vincolo di prefisso `onedrive-`).

### Utilizzo

1. **Rendi eseguibile lo script:**
   ```sh
   chmod +x setup-onedrive-multi.sh
   ```

2. **Esegui lo script:**
   ```sh
   ./setup-onedrive-multi.sh
   ```

3. **Segui le istruzioni:**
   - Inserisci il numero di account che vuoi configurare.
   - Per ogni account, inserisci un nome che inizi con `onedrive-` (es: `onedrive-personale`, `onedrive-lavoro`).
   - Completa la procedura di autenticazione per ogni account quando richiesto.

4. **Al termine:**
   - Verranno creati i servizi systemd utente per ogni account (es: `onedrive-personale.service`).
   - I servizi saranno attivi e partiranno automaticamente ad ogni login.

### Note

- **Terminale grafico:** Esegui lo script da un terminale all’interno della sessione desktop (es: xfce-terminal, gnome-terminal) per evitare errori relativi a systemd user/DBUS.
- **Pulizia:** Tutte le vecchie configurazioni e servizi OneDrive verranno rimossi prima della nuova configurazione.
- **Cartelle di sincronizzazione:** Ogni account avrà la propria cartella dedicata nella home, con nome corrispondente (es: `~/Onedrive-Personale`).

### Rimozione

Per rimuovere tutte le configurazioni e i servizi creati, basta rieseguire lo script: la fase iniziale effettua una pulizia completa.

