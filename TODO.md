# TODO / decisions to come back to

## Story and progression
- **Where abilities come from.** New games start with no abilities, and Heal and
  Super Jump (price 0, so no shop sells them) can't be learned anywhere yet.
  Decide the source for each: shop price, quest reward or story moment. Also add
  a way for dialogue/quests to teach an ability (`Hotbar.learn(id)` exists).
- **Where the first gear comes from.** New games start with no armor, shield or
  weapon, and can't start fights without a weapon. Wire up the first weapon (and
  armor/shield) through the story, a quest reward or a shop.
- **Desert level.** Main quest "Water for the Desert" stops at step 3: no desert
  level yet. Needs the level, a `QuestTrigger` with `place_id = desert_town`, and
  the desert mayor NPC using `dialogue/npcs/desert_mayor.dlg` (`dialogue_file`).

## Side quest ideas (not built yet)
- **Night Watch.** After dark, strange glowing lights appear at the edge of town and a
  guard asks the player to check them. Follow a trail of glowing waypoints to find out
  what they are (fireflies, or spirits escaped from the well). Reuses the motes/glow/fog
  work. Needs a decision on time of day (check whether a day cycle exists).
- Others suggested but not chosen: Escort to the Gate,
  The Slime Elder (first mini boss), The Thirsty Traveller (give up a spirit or not),
  Mayor Arse's Complaint (comedy chain), Wanted: Dry Socks (swim retrieval),
  The Bell Ringer (mystery), Bounty Board (repeatable jobs).

## Other
- Boss-only finisher (deferred earlier).
- Credits still missing: Super Whales font author/licence; composer + licence for
  `sounds/Music` (title_track, chesburg, combat_theme).
- The repo is public and contains the raw ithappy furniture models; their licence
  forbids redistributing the assets as-is. Make the repo private or keep those
  files out of it.
- `staff_magic_sheet.xlsx` (the magic numbers spreadsheet) was last regenerated
  on 2026-10-30 and doesn't track the code automatically.
