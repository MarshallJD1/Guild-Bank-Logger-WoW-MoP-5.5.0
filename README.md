GuildBankLogger (MoP Classic 5.5.0)

A World of Warcraft Mists of Pandaria Classic addon to track guild bank deposits, withdrawals, and gold transactions.

Exports your logs directly in-game into a spreadsheet-ready format (Google Sheets / Excel).
No external tools or executables required. 🎉

📦 Contents

GuildBankLogger.lua – Addon code

GuildBankLogger.toc – Addon metadata

🚀 Installation

Download or clone this repo.

Place the GuildBankLogger folder into your WoW AddOns directory:

World of Warcraft\_classic_\Interface\AddOns\


Launch WoW and enable GuildBankLogger in your AddOns list.

🔄 Workflow

Log into WoW.

Open the Guild Bank.

Go to the Money Log or any Tab Log.

Run /gbl scan on each visible log page.

When finished, run /gbl export.

A window will appear containing all exportable data in tab-separated format.

Copy & paste this into Google Sheets or Excel.

📊 Sharing Logs

Paste the export into a shared Google Sheet for guild-wide tracking.

All entries include a unique index to avoid duplicates across sessions.

⚙️ Commands

/gbl scan → Scan the currently visible log (tab or money).

/gbl export → Open a window with spreadsheet-ready export text.

📄 Using with Google Sheets

Open a new Google Sheet.

Paste the exported data into the sheet.

Format as needed (freeze header row, apply filters, etc.).

🛠 Development

Written in Lua using the WoW API.

Data stored in SavedVariables for persistence.

Export window created via standard WoW UI API.

✨ Credits

Created by MarshallJD with the help of AI-assisted coding tools.
<a href="https://www.flaticon.com/free-icons/log" title="log icons">Log icons created by Freepik - Flaticon</a>
