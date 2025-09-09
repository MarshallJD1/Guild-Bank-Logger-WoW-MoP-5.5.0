GuildBankLogger for Mists of Pandaria 5.5.0

A World of Warcraft Mists of Pandaria Classic addon to track guild bank deposits, withdrawals, and gold transactions — fully in-game with copyable export window.

📦 Contents

GuildBankLogger.lua – Addon code

GuildBankLogger.toc – Addon metadata

🚀 Setup

Copy the GuildBankLogger folder into:

World of Warcraft_classic_\Interface\AddOns\


Launch WoW and enable GuildBankLogger in your AddOns list.

Log into your character and open the Guild Bank.

🔄 Workflow

Open the Guild Bank.

Navigate to the Money Log or a Tab log.

Run /gbl scan to log the currently visible transactions.

Repeat for all tabs/money log pages.

Run /gbl export to open the in-game export window.

Copy the export text and paste it into your GuildBankLogs.csv (or directly into Google Sheets/Excel).

📊 Export Format

Player

Type (Gold Deposit / Gold Withdraw / Item Deposit / Item Withdraw)

Gold Deposit (G, S, C)

Gold Withdraw (G, S, C)

Item

Count

Timestamp (YYYY-MM-DD HH:00)

Index (unique transaction ID)

Tab

All transactions are logged individually, even if multiple identical items/gold occur in the same hour. Reloading the UI will not duplicate entries.

⚙️ Commands

/gbl scan → Scan the currently visible tab or money log

/gbl export → Open in-game export window (copy CSV-ready text)

🛠 Development

Built with Lua and WoW API

Deduplication uses Blizzard transaction IDs for reliability

Works fully in-game — no external tools required

📄 Using Your Logs in Google Sheets

Copy the exported CSV text into a .csv file (or paste directly into a Google Sheet).


✨ Credits

Created by MarshallJD
For tracking guild bank logs in WoW Mists of Pandaria Classic.
