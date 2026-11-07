# BlazeTweaks

Two tweaks for WoW Forever: automatically open newly acquired clams/containers
and select a single available bank, taxi or vendor gossip option without quests.

Open settings with `/bt` or `/blazetweaks`.
The GUI matches BlazeMail's dark brown theme with light text, thin borders and
muted gold highlights. BlazeMail does not need to be installed.

- Toggle settings are saved **per character**. New settings are disabled;
  existing boolean choices for `autoOpenClams` and `autoGossip` are preserved.
- Changes apply immediately without a reload. Disabling a tweak makes its pending
  callbacks inactive. An item that has already been used cannot be recovered.
- The three default clams have item IDs 5523, 5524 and 7973.
- Additional item IDs are saved **account-wide** in `BlazeTweaksDB.containerItems`.
  Enter one ID in the small input field and press **Add** or Enter. Clicking the
  field focuses it and displays a blinking cursor. Additions and removals are
  saved immediately. Feedback appears beside Add and disappears after five seconds.
- The list displays default and additional items in **two columns**, with icons,
  names and item tooltips on hover. When needed, a scrollbar appears; both dragging
  the scrollbar and using the mouse wheel are supported. Remove an additional item
  with **X**; default items cannot be removed.
  Default items appear first, followed by additional items in insertion order,
  read from left to right in each row. This order is saved account-wide in
  `BlazeTweaksDB.containerItemOrder`. Removing and adding an item again places it
  last. Older saved lists have no insertion history and initially load in item-ID
  order; future additions are appended.
  Duplicate and invalid IDs are rejected. Missing item data is loaded asynchronously;
  existing saved items display a placeholder until their data is available.
  A lookup with no response times out after five seconds and can be retried.
  A valid item is not necessarily an openable container; only add containers you
  want the addon to use automatically.
- Only items acquired after enabling the tweak are queued. Items already in your
  bags at login, when enabling the tweak or when changing the list are not opened.
- Opening pauses during combat, while loot, merchant or bank windows are open,
  while items are locked, or when normal bags have no free slots.
  Each queue entry allows at most three use attempts.
- Hold Shift when opening gossip to skip automatic selection for that page.
- Gossip has separate **Bank**, **Taxi** and **Vendor** choices, saved per character
  in `BlazeTweaksCharDB.gossipTypes`. All three are enabled by default; the main
  toggle remains disabled by default. Individual choices can be changed without
  a reload, and existing choices are preserved when loading.

Removed tweaks are no longer loaded. Older SavedVariables fields, including chat
history, are not deleted automatically but are no longer used.

## Compatibility and testing

API reference: the repository's `api.json`, version 1.60.1, build 70790, interface
16001, exported on November 5, 2026. Container/gossip functions, item GUIDs,
events, timers and the documented fields used by the addon were checked there.
The GUI's `C_Item.GetItemInfo`, `RequestLoadItemDataByID`, `ITEM_DATA_LOAD_RESULT`,
input focus and `SetBlinkSpeed` were also checked against the snapshot. The tooltip
methods `SetOwner`/`SetHyperlink` are not fully documented there; their use was
checked against the [Forever UI source](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua)
and the previously reviewed DialogueUI code. The Forever branch reported build
70862 at that check, which is newer than snapshot 70790. Icons, the cursor and
tooltips still require visual verification in Forever.

`ItemLocation:CreateFromBagAndSlot` is not described in the snapshot. Its signature
was checked in [Blizzard's UI source mirrored by Gethe](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ObjectAPI/Mainline/ItemLocation.lua),
and availability is checked before enabling the tweak. That source is Mainline
and does not constitute a Forever runtime test. UI templates and all frame methods
are also not fully documented in the snapshot.

The DialogueUI integration is based on the reviewed version **1.0.7 b**.
Post-hooks on `DUIQuestFrame.ShowUI` and `HandleGossip` handle both deferred gossip
during loading and new pages in an already visible window. Hooks remain installed
but are inactive when gossip is disabled; they are not recreated on each enable.
This integration uses internal methods that future DialogueUI versions may change.

Local regression tests use a mock WoW API and Lua 5.1:

```text
lua BlazeTweaks/tests/regression.lua
```

Run this command from the repository root. The test file is not loaded by the
addon's TOC. Tests verify logic, not client permissions, UI layout or persistence
to disk.

Test in Forever after loading the updated files:

1. Use `/bt`, toggle the tweaks and verify immediate changes without a reload.
   Click the item-ID field, check the cursor, add items with the button and Enter,
   and test duplicate/invalid IDs. Check item icons, tooltips, scrolling and X buttons.
2. Acquire new clams and a known additional container item. Test locked items,
   full bags, combat, and open loot, merchant and bank windows. Check that the queue
   resumes afterward.
3. Test bank/taxi/vendor gossip with and without Shift, quest options and multiple
   gossip options. Toggle each gossip type separately and check that the main
   toggle still determines whether automation runs.
4. Test with and without DialogueUI, immediately after login and between pages
   in an already visible window.
5. Restart the client and check character settings and the shared item list on
   two characters.

Automatic item use from a timer still requires testing with the actual containers
in Forever. API presence does not prove permission to use it. Client protections
are respected; items requiring user input must be opened manually.
