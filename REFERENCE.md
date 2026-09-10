# REFERENCE.md - the observed record

Gravewell has two references. One is our own game and the evidence is a playtest log rather
than a video. The other is the only well-reviewed mobile game that already has the structure
Gravewell is proposing. Both are recorded here as **observations, not inferences**, because
`CRAFT.md` says a rewrite is cheap only when the research lives in its own file.

---

## Reference 1: Coreward (ours, live at gideon6222.github.io/coreward)

Seven playtest sessions, 2026-09-06 to 2026-09-08. Source: `C:\dev\gamedev-notes\playtests\coreward.md`,
his words verbatim. `C:\dev\coreward\NOTES.md` is the build record.

### What the game is

2.5D grid miner, web, three.js 0.166.0, PWA. Fly a drill ship down through a cell grid toward
a planet core, sell ore at the surface pad, buy upgrades in a shop room, break the core, take
a chart to the next world. Fuel and heat push you up, depth and value pull you down. Fifteen
upgrades, three consumables, twelve planet palettes, five traits, a Jump Drive of five
components and a final world called the Heart.

### Verified likes, with the quote that proves each

| # | What | Quote |
|---|---|---|
| 1 | Light that propagates through the tunnels he dug | "I want the light look like it actually spreading from the ship... if it hits a corner or branch, it should cast a shadow down that tunnel" |
| 2 | Free flight over grid movement | "make the ship feel more like it is free to fly not on a grid" |
| 3 | Texture on rock that means something | "I like the sections of texture you added to the regular blocks. can you make it so most regular dirt and rock give you a very small amount of resource, and those textured areas give you more?" |
| 4 | A shop that is a room with physical objects | "make it look like a full room where upgrades have a physical model associated with it instead of a list of upgrades" |
| 5 | Upgrades visible on the ship in play | "when you upgrade thrusters and starts to change the way they look, it also changes the way that they look when you're actually playing the game" |
| 6 | Gritty realism over clean colour | "make the dirt and rocks look more like realistic minerals, make the colors and textures more gritty" |
| 7 | Interruptible commitment | "Blocks should stop being dug if you stop drilling but remember how much damage is already done to them" |
| 8 | Never blocked by a full hold | "make it so I can always dig but if the hull is full, just leave the resources floating in place for me to pick up later" |
| 9 | Darkness that justifies a tight camera | "make shadows and darkness denser... so it feels like we are only zoomed in vecause we can see any further out" |
| 10 | Light upgrades as framing, not radius | "If you make it so far away blocks are hard to tell what they are without light upgrades, or start zoomed in a bit and each light upgrade zooms out, that could be cool" |
| 11 | Version and patch notes in the pause screen | "add a more intuitive version number and patch notes to the pause screen" |
| 12 | Cost made visible, his own redesign | no return button, run dry and get towed for a cut, buy insurance to reduce the cut |

Number 3 is the only unprompted design compliment in six games, and he turned it into a
mechanic in the same sentence. Numbers 1, 4 and 10 he asked for repeatedly across sessions.

### Verified dislikes, with the diagnosed cause

| # | Quote | Cause, once found |
|---|---|---|
| 1 | "I can afford upgrades pretty early on for fuel and cooling so neither is a risk" | Counters priced against the first haul rather than against the depth where the threat starts |
| 2 | "Right now it doesnt say it costs anything, so it feels free" | The Return button charged fuel and never displayed it |
| 3 | "It is difficult to judge the price of the different blocks you are mining" | Cargo counted units, so dirt and rubies took the same slot |
| 4 | "The ship looks very bouncy when you change direction or stop" | A smoothing term added to velocity instead of assigned, plus lane pull running while coasting, plus a drill alignment writing position directly into the rock |
| 5 | "it looks like it is just fast forwarding" | Autopilot stepped cell to cell at high speed with no curvature, acceleration or heading |
| 6 | "The music has random higher pitch beeps that I dont like" | Melody notes picked at random from a pentatonic scale. Fast attack on a high sine is the shape of a notification sound |
| 7 | "the game looks a little cartoonie" | No roughness channel anywhere (Lambert), a sphere for a cockpit, and a shop that was a list. Never the amount of detail |
| 8 | "some of the words are cut off and it feels a bit cluttered" | Fifteen shop cases in a room laid out for ten, five of them unbuyable |
| 9 | "it doesnt seem very obvious that there is a distinct line" | The rock band changed at 60 m and heat started at 70 m, so the boundary had no visible marker |
| 10 | "it is still doing it"  (five rounds) | Occluder distance recorded per whole block, so one point lamp quantised into a cone per block. He supplied the mechanism and was right |
| 11 | "it looks like it is happening worse now than it was and I liked the art style before better" | A fix that removed the artefact by dimming everything. A fix that improves every scene equally is a dimmer switch |

### The structural finding that outweighs all of the above

**In seven sessions he never played past about 60 m.** Every note in every session is about the
first sixty metres and the surface. Heat at 70 m, tremors at 85 m, the deep ore ladder, relics,
the chart, the Jump Drive, the Heart and the entire ending were built and have never been seen
by the person the game is for.

Coreward's content lives at the bottom of one shaft that takes a long uninterrupted sitting to
reach. He plays a phone game in the gaps of a day. The content was not too hard to reach, it
was too far in one direction.

### Numbers worth carrying over

| Thing | Value | Note |
|---|---|---|
| Heat threshold and rock band change | both exactly 70 m | Four things land on that metre and a test asserts the constants stay equal |
| Tremor rhythm past 85 m | one every ~27 s | Tuned, survived play |
| Hold capacity | 60 kg | Weight, not units. This is what made value a decision |
| Light field texture | 15x36 texels, LinearFilter, 2 KB | Sampled by world position |
| Shadow ray fan | a few hundred rays, uploaded as 512 texels | Runs every frame |
| Rock normal map | ambientCG at 384 px WebP q70, 45 KB | 1k was three quarters of a megabyte thrown away |
| Draw calls before missing 60 fps | ~3,200 at 5.0 us each | The "50 to 100 on mobile" folklore was wrong by 30x |

---

## Reference 2: Holedown (2018, Grapefrukt, iOS/Android, portrait, one thumb)

Not named by Gideon. Found by the genre research because it is the **only well-reviewed mobile
game that already has the structure Gravewell proposes**, and the structure is the risky part
of the plan. Observed from reviews rather than from play, and marked as such.

| Observation | Source |
|---|---|
| Each "planet" is one **one-way descent**. There is no return trip in the game at all | MacStories review |
| Six planets. Roughly five hours to see them all | App Unwrapper review |
| Crystals gathered on the way down buy permanent upgrades **between planets only**, never mid-descent | MacStories review |
| The upgrade ladder is all soft speedups (more balls, more shots). No hard tool-tier walls | App Unwrapper review |
| The final planet removes the win state and becomes endless: "how deep can you get" | MacStories review |
| Portrait, one thumb, aim and launch | App Unwrapper review |

**Why this matters to the plan.** The genre's PC ancestors (Motherload, SteamWorld Dig) put
their content at the bottom of one shaft and make you climb back up it, and the climb is the
single most-cited complaint in their reviews. Holedown removed the return trip entirely and
was well received for it. Gravewell's "each planet is a complete descent in one sitting, and
variety comes from moving between very different planets" is not an untested idea, it is the
shape of the one mobile game in this genre that worked.

**What Gravewell takes and what it does not.** It takes the one-way descent and the
between-planets-only shop. It does not take the soft-only upgrade ladder: the genre research
is clear that hard tool-tier gates are what make a place seen at hour one worth returning to
at hour six, and Gravewell wants that for its sealed vaults.

---

## The rest of the genre, observed

| Game | The observation that mattered | Source |
|---|---|---|
| **Motherload** (2004) | Starts with about 30 seconds of fuel. Nine fuel tanks, six cargo bays, eight drills, nine engines. Guides name the $750 Medium Tank as the correct first buy. At 1,000 ft the game pays $3,000 and starts earthquakes, and an NPC tells you so | GameFAQs walkthrough, XGen wiki |
| **SteamWorld Dig** (2013) | Hard gates are tool tiers needed for new rock types. Soft gates are cargo, water and light. The most repeated review complaint is that the deeper you dig the longer the climb back, only partly fixed by purchasable teleporters | Games Asylum review |
| **Dome Keeper** (2022) | Goal stated at mode select, before minute one. No hard gates at all, and a design analysis calls the repeat runs "predictable" because of it. A natural stop every 2 to 3 minutes on the wave cycle. A full run is 20 to 38 minutes | joshanthony.info, Shacknews |
| **Deep Rock Galactic** | Variety is horizontal: eight biomes, caves regenerated every mission, and the trip ends on an extraction call rather than a climb. Reviewers credit this for avoiding repetition | Steam community guide |
| **Terraria** | Ore splits by depth **and** by horizontal biome, with absolute pickaxe-tier gates. A copper pickaxe never mines hellstone | Official wiki |
| **Subnautica** | Depth is gated by vehicle pressure limit, not by a shaft. Seamoth 900 m, Prawn Suit about 1,300 m with the Mk1 module | Subnautica wiki |
| **Downwell** | A pure one-way descent with no return, 5 to 20 minutes a session, carried a whole well-reviewed roguelike on its own | Nintendo Life review |

### The three findings that go straight into the design

1. **Attention in this genre is held by upgrades unlocking capability, or by timer pressure.
   Not by the ore and not by the danger.** Nobody credits either as the retention driver past
   the first hour.
2. **Every top title states its meta-goal in the first one to two minutes** and puts a tool in
   your hand with a visible pressure already ticking within seconds.
3. **The return trip is the genre's most-hated element wherever it exists.** The best-reviewed
   cases either make it instant (extraction call, teleporter) or cut it entirely.

Finding 3 is the one that changed Gravewell's design after the research came back. See
`PLAN.md` under "The loop" for what it changed.

---

## Design research: economy, secrets, dread

Not reference games, but the sourced findings that shaped `PLAN.md`. Kept here so the
citations survive.

### Economy

| Finding | Source |
|---|---|
| Motherload's upgrade ladder is $750, $2,000, $5,000, $20,000, $100,000, $500,000: 2.67x, 2.5x, 4x, 5x, 5x. The multiplier **rises** with depth, so late rungs demand more trips than early ones | Motherload wiki, Game Values |
| Rogue Legacy raises the cost of the *next* purchase by a flat amount on every purchase, so the currency inflates per purchase and not only per tier. Rogue Legacy 2 added "Labor Costs" at Manor 30, where every purchase raises every other line, explicitly to fix a single currency trivialising late upgrades | Rogue Legacy and Rogue Legacy 2 wikis |
| **SteamWorld Dig 2 splits gold (mined, spent freely) from cogs (found by exploring, required regardless of gold)**, so a player who only grinds the fast loop cannot buy every counter. This is the direct fix for his complaint | SteamWorld wiki. Tier structure confirmed, exact gold values not recoverable |
| Dome Keeper raises cobalt costs *during* the run's final stretch so the currency's value collapses near the finish. Even an IGF winner needed live rebalancing to get this by feel | Dome Keeper version history, Steam balance thread |
| Deep Rock Galactic is the failure in the other direction: a specific overclock takes a community-estimated 16 weeks, and players report the cost "discourages trying new overclocks" | Steam discussion |
| The documented anti-pattern behind his exact complaint: **a currency fungible across every threat**. If mining buys both cargo and survival and mining is the fastest grind, the player buys immunity before any threat bites | Machinations, game economy inflation |
| **2 to 4 trips per rung early, 4 to 6 late.** Reasoning from the bracket between Motherload's early multipliers and DRG's frustration point, not a published figure. Marked as inference | — |

### Secrets

| Finding | Source |
|---|---|
| **Animal Well is layered:** layer 1 is completable by any player in 10 to 15 hours with zero hint-reading, and layers 2 to 4 are for a self-selected audience. The core loop never depends on a secret | Thinky Games interview with Billy Basso |
| Tunic's working title was "Secret Legend" and the goal was that players "not understand the boundaries" of the world, with an in-fiction manual giving partial pictograph information that must be interpreted | Game Developer interview |
| La-Mulana guards secrets with **consequence** rather than obscurity: puzzles are built to make the player think twice before a risky action | PlayStation Blog interview with Takumi Naramura |
| Outer Wilds delivered its story through physical processes and locations rather than text, and **still had to patch specific clues after launch** because players missed them. Clue strength is verified by playtest, never assumed | GDC 2021, Alex Beachum |
| Achievement data suggests planning for roughly a quarter to a third of players to find any well-hidden secret, and single digits for the deepest. Even Elden Ring's optional endings only reach 32 to 40 per cent | Steam Hunters achievement data |
| Metroid Dread's weakest abilities are the ones that only unlock a door. **A tool that reopens a sealed place must also give a new verb** | Sequence-break analysis |

### Dread without combat

| Finding | Source |
|---|---|
| Subnautica starts you with **45 seconds of oxygen**. Darkness hides real spatial threat, creature vocalisations arrive before the creature, and every light source is also a trap. The academic reading is that the dread comes from **agency**: "it's your decision to swim down, not that of a script" | Game Studies, "Too Afraid to Go Deeper"; GDC 2019, The Design of Subnautica |
| Sunless Sea's Terror is a **numeric consequence of a choice** (being out of sight of land), warned continuously, and nearly impossible to bring back down. The director's method: suggest something terrible with lighting and sound, then let fear do the rest | Inverse interview with Liam Welton |
| SOMA built its ambience from white noise and subtle tonal texture rather than musical stings, with heavy reverb simulating reflections in enclosed metal, and over 2,000 real footstep recordings run through impulse responses for per-space acoustics | Frictional Games, SOMA Behind the Sound |
| **Iron Lung** removes continuous vision entirely: an incomplete map, a proximity sensor, sound, and a low-resolution camera that takes one still at a time. Reviewers credit that with being scarier than anything shown. The most directly transferable reference for a game whose only light points one way | Coverage of Iron Lung's design |
| Alien: Isolation makes the flashlight two-sided: it is scarce **and** it draws the Alien. Darkwood gives several light tools trading brightness against runtime, so which light to bring is a loadout decision. **A light source should not be a single depleting bar** | Alien Isolation and Darkwood wikis |

### The technique

| Finding | Source |
|---|---|
| Interpolated marching squares: sixteen cases, the contour vertex placed by interpolating the two corner values rather than snapping to the midpoint. Ambiguous cases 5 and 10 need a fixed tie-break | Wikipedia, Marching squares; Boris the Brave, Marching Cubes Tutorial |
| A filmed build from cellular automata through marching squares to mesh to walls to colliders | Sebastian Lague, Procedural Cave Generation, episodes 2 and 3 |
| A Godot 4 implementation that already chunks meshes so only touched chunks rebuild, and decomposes concave contour polygons for collision | `richardhyy/Godot-4-Destructable-Terrain` |
| **Volumetric fog is Forward+ only, not Mobile or Compatibility.** SDFGI, VoxelGI, SSAO and SSIL are likewise Forward+ only | Godot docs, Volumetric fog |
| `DEPTH_TEXTURE` and `SCREEN_TEXTURE` return corrupt or zeroed data on Forward Mobile whenever MSAA is enabled | Godot issues 80991 and 103425 |

The last two are the reason the air-density stack in `PLAN.md` is built from `Environment`
depth fog, additive tunnel-glow quads, dust motes and a full-screen pass that reads the
simulation's own light field, rather than from `FogVolume`. **The asset scout asserted the
opposite in passing, so M2 settles it with a measurement in the real project rather than with
a citation.**
