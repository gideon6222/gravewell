# Notes - Gravewell

Decisions specific to this game, what has been measured, and what to do next. General
lessons go to `C:\dev\gamedev-notes\inbox\` via `/record-lesson`, never here.

## Decisions made without asking

From `PLAN.md` "Open decisions I made for him", verbatim, plus anything decided during the
build. One line each with the alternative, so he can reverse any of them.

1. **Name and slug: Gravewell / `gravewell`.** A gravity well is what you dig down through and
   a grave is what these worlds are. *Alternative:* anything he prefers. Renaming is cheap now.
2. **No mid-descent return trip.** *Alternative:* Coreward's climb back to the pad. Rejected on
   the research: it is the genre's most-cited complaint and it is the mechanism behind him never
   playing past 60 m of Coreward in seven sessions.
3. **The d-pad stays; no virtual joystick.** *Alternative:* Godot 4.7's built-in
   `VirtualJoystick`, if the first playtest asks for finer control.
4. **Collision stays on the cell grid while the visible rock is a marching-squares contour.**
   *Alternative:* collision on the contour, which is more correct, needs concave decomposition
   and cannot be tested nearly as cleanly.
5. **Seven world classes, two in phase one.** *Alternative:* more classes shallower, which is
   the Coreward mistake of twelve palettes over one cave.
6. **One room, not two shops.** The Hold is both the upgrade room and the hub.
   *Alternative:* a pad shop for refits and a separate hub, which is two chances to get wrong
   the screen he opens first.
7. **The core at about 200 m and five bands.** Provisional until the probe measures the real
   descent time. *Alternative:* whatever the probe says makes a descent five to ten minutes.
8. **Audio generated at build time into committed WAVs**, with sampled impacts where a sample
   is better. *Alternative:* fully sampled, if a pack fits the brief.

Decided during the build:

9. **Maaack's Menus Template is fetched at M10, not at scaffold.** It was fetched once at
   scaffold and taken straight back out: the tag ships **8.4 MB across 524 files**, most of it
   examples, media and docs, and carrying that through nine milestones of diffs and imports
   buys nothing while the shell is not wired in. It is one command at M10:
   `python C:\dev\gamedev-notes\scripts\assets.py get addon Maaack/Godot-Menus-Template v1.7.0 --into addons`,
   and `.gdignore` goes into `examples/`, `media/` and `docs/` the moment it lands.
   *Alternative:* fetch at scaffold, which the scaffold skill suggests, at the cost of 8.4 MB in
   history and a menu in front of every harness before there is a game behind it.
   **Its credits line is not in `assets/CREDITS.md` yet, on purpose:** the credits screen must
   never name something the build does not contain.
10. **`permissions/vibrate=true` set in both export presets at scaffold.** The plan uses
    haptics and `Input.vibrate_handheld` silently does nothing without it.

## Measured

| Date | What | Number | How |
|---|---|---|---|
| 2026-09-10 | Fresh copy of the template | tests and smoke green | `scripts\check.ps1` |

## Playtests (desk and phone)

(One dated section per `/playtest`: the six answers with frame numbers, the phone
percentiles and thermal, what changed because of it.)

## Ship log

(One dated section per `/ship`: POLISH.md lines that were no and what fixed them, deferred
lines with their phase, the release tag.)

## Next

See the first unticked milestone in `PLAN.md`.
