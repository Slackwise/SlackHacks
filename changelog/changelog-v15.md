# SlackHacks v15

## Players Online
- Replaced "Split Friend/Guildie Lists" with a "Stack Friend/Guildie List" checkbox, grouped directly above the Friends List/Guildies List visibility toggles in the window's cog menu. Uncheck it to split the lists into standalone windows.
- The standalone Friends and Guildie list cogs now use the same stacking checkbox and label.

## Self Vendor
- Requests are now also accepted from `/say` and whispers, not just party, raid, and instance chat.
- Added an "Only Vend to Fellow Guildies" option (below the Flask and Augments Source dropdown) to ignore requests from anyone outside your guild.
- The queue window now opens as soon as any request starts being handled, even with nobody else waiting, and shows who is currently being vended to above the waiting list.
- Every queue window row, including the player currently being vended to, now has a remove button and a vend button. The vend button vends to a waiting player immediately (the interrupted player goes back to the front of the queue) or retries the player currently being vended to.
- Closing the queue window now clears the entire queue, including the player currently being vended to.
- Saying a stat flask followed by "flask" (e.g. "crit flask", "mastery flask") now requests just that one flask instead of also adding a second, generic flask.

## Listview Bag
- The "Sell Trash" button is now only enabled while a merchant is open and you have marked trash a merchant will actually buy, and it disables itself once everything has been sold.
