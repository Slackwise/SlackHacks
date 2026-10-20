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
- Added an "Automatic Trade Response" dropdown. Set it to any Self Vendor mode (including the specific stat flasks) and anyone who opens a trade with you is automatically traded those items, whether or not that mode's checkbox is enabled, and even while chat requests are turned off. They jump to the front of the queue; whoever was being vended to is put back at #1. Trades you open yourself are left alone, and Only Vend to Fellow Guildies still applies.
- Added "Turn Off Automatic Trade Response After Leaving Group" to set Automatic Trade Response back to Off when you leave a party or raid.
- Added `/slack vend <mode>` to set Automatic Trade Response from chat, e.g. `/slack vend vantus`, `/slack vend crit flask`, or `/slack vend off`.
- If a requester opens the trade with you before their items are ready, their items are now added to that trade window once prepared instead of failing.

## Listview Bag
- The "Sell Trash" button is now only enabled while a merchant is open and you have marked trash a merchant will actually buy, and it disables itself once everything has been sold.
