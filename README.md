GuildBankLogger

Track your guild bank activity and player contributions in WoW Classic & MoP Classic with ease.

Features

Tracks gold and item deposits/withdrawals per player.

Calculates contribution points based on gold/items deposited and withdrawn.

Supports stacked materials in MoP Classic.

Status indicator for players (green/yellow/red) based on contributions.

Copy-paste summary straight into Excel, with automatic calculations on a separate Overview sheet.

Optional adjustment for raid attendance (subtract points per raid).

Installation

Download or clone the repository:

git clone https://github.com/yourusername/GuildBankLogger.git


Copy the GuildBankLogger folder into your WoW AddOns directory:

World of Warcraft\_classic_\Interface\AddOns\


Reload your UI in-game (/reload) or restart WoW.

Usage

Open the addon in-game with /gbl.

Log transactions when depositing or withdrawing gold and items from the guild bank.

Click Export Summary to copy the summary text to your clipboard.

Open Excel:

Paste the text into the GuildBankLogs sheet.

The Overview sheet will automatically calculate:

Total gold deposited/withdrawn

Total items deposited/withdrawn (stack-aware)

Contribution points

Status color (conditional formatting in Excel)

Adjust contribution points or raid penalties if desired:

2 points per 100g deposited/withdrawn

0.25 points per item deposited/withdrawn

Subtract points per raid for attendance (optional)

Excel Sheets

GuildBankLogs: raw log data pasted from the addon.

Date | Player | GoldDeposit | GoldWithdraw | Item | ItemDeposit | ItemWithdraw


Overview: automatically calculated totals, contribution points, raid penalties, and status.

Contribution System
Action	Points
100g gold deposited	+2
100g gold withdrawn	-2
Item deposited (any stack)	+0.25/item
Item withdrawn (any stack)	-0.25/item
Raid attendance penalty	-5 or -10

Status Rules:

Positive points → Green

Zero points → Yellow

Negative points → Red

(Status uses Excel conditional formatting for colors.)

Support & Issues

If you encounter issues or have suggestions, please open a GitHub issue.

License

MIT License. Free to use, modify, and distribute.
