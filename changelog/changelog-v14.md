# SlackHacks v14

## Players Online
- Replaced "Split Friend/Guildie Lists" with a "Stack Friend/Guildie List" checkbox, grouped directly above the Friends List/Guildies List visibility toggles in the window's cog menu. Uncheck it to split the lists into standalone windows.
- The standalone Friends and Guildie list cogs now use the same stacking checkbox and label.

## Self Vendor
- Requests are now also accepted from `/say` and whispers, not just party, raid, and instance chat.
- Added an "Only Serve to Fellow Guildies" option (below the Flask and Augments Source dropdown) to ignore requests from anyone outside your guild.
- The queue window now opens as soon as any request starts being handled, even with nobody else waiting, and shows who is currently being served above the waiting list.
- Saying a stat flask followed by "flask" (e.g. "crit flask", "mastery flask") now requests just that one flask instead of also adding a second, generic flask.

## Listview Bag
- The "Sell Trash" button is now only enabled while a merchant is open and you have marked trash a merchant will actually buy, and it disables itself once everything has been sold.
