# GuildBankLogger For Mists of Pandaria 5.5.0

A World of Warcraft Mists of Pandaria Classic addon + export tool to track guild bank deposits, withdrawals, and gold transactions.  
Includes a one-click `.exe` exporter that writes logs into a CSV, ready for Google Sheets or Excel.

---

## 📦 Contents
- `GuildBankLogger.lua` – Addon code  
- `GuildBankLogger.toc` – Addon metadata  
- `UpdateGBLExport.exe` – Exporter tool (Windows, no Python needed)  
- `config.txt` – Paths configuration file  
- `GuildBankLogs.csv` – Blank CSV (will fill over time)  
- `Instructions.txt` – Quick setup guide  

---

## 🚀 Setup

1. Copy the **GuildBankLogger** folder into:"World of Warcraft_classic_\Interface\AddOns\"
2. Open `config.txt` and update:
- `SAVED_VARIABLES_PATH` → path to your `GuildBankLogger.lua` SavedVariables file.
- `CSV_PATH` → path to your `GuildBankLogs.csv` (usually inside the addon folder).

3. Launch WoW and enable **GuildBankLogger** in your AddOns list.

---

## 🔄 Workflow

1. Log into WoW.  
2. Open the Guild Bank.  
 - Open The Money Log/Tab1 Log
 - '/gbl scan' On each of the log pages. 
3. Exit the game.  
4. Double-click `UpdateGBLExport.exe`.  
- Updates `GuildBankLogs.csv` with any new transactions.  
5. Open the CSV in **Google Sheets** or **Excel**.  
- In Google Sheets: `File → Import → Upload CSV`.  
- In Excel: open the CSV directly.  

---

## 📊 Sharing Logs

- Sync `GuildBankLogs.csv` with Google Drive/Dropbox/OneDrive.  
- Link it into Google Sheets for live sharing with guildmates.  
- All entries have a unique index, so no duplicates across sessions.  

---

## ⚙️ Commands

- `/gblscanall` → Scan all logs (also happens automatically).  
- `/gbl clear` → Wipe stored data + reset index.  
- `/gbl exportreset` → Reset export string only.  

---

## 🛠 Development

- Built with Lua (WoW API) + Python exporter.  
- Packaged with PyInstaller for no-dependency `.exe`.  

---

## 📄 Using Your Logs in Google Sheets

You can easily view your guild bank logs in Google Sheets with your exported CSV.

1. Upload your `GuildBankLogs.csv` to **Google Drive**.  
2. Right-click the file → **Share → Anyone with the link** → set as **Viewer**.  
3. Copy the **file ID** from the share link.  
   - Example link:  
     ```
     https://drive.google.com/file/d/1AbCDEfgHiJKlMnOPQrsTuvWXyz/view?usp=sharing
     ```
   - File ID: `1AbCDEfgHiJKlMnOPQrsTuvWXyz`
4. In a Google Sheet, paste the following formula into cell A1:  
   ```excel
   =IMPORTDATA("https://drive.google.com/uc?export=download&id=YOUR_FILE_ID_HERE")


## ✨ Credits

Created by MarshallJD and various AI Tools for tracking guild bank logs in WoW Mists of Pandaria Classic.  
<a href="https://www.flaticon.com/free-icons/log" title="log icons">Log icons created by Freepik - Flaticon</a> for use of icon 

