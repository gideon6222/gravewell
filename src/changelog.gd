class_name Changelog
extends RefCounted

## What changed, in the player's terms. Newest first, one line each, describe
## what the player can now do or see. The build stamp says whether an update
## landed; this says what it was.
##
## This is one fact in three places - here and `version/name` in each export
## preset - and `test_version.gd` asserts they agree, because nothing derives
## one from the other and they have drifted in a sibling game already.

const VERSION := "0.12.0"

const RELEASES := [
	{
		"version": "0.12.0",
		"date": "2026-09-11",
		"title": "Drown",
		"notes": [
			"A third world, and its rule is water. Below about forty-six metres every tunnel you cut fills up, and the shaft you came down becomes a well.",
			"The surface climbs as you open room beneath it, so a long dig floods the way home. It is the one pressure in the game that you cause rather than meet, and standing still costs nothing.",
			"Under water the ship is dragged and pushed upward, so going down is the expensive direction for once.",
			"The seals take it while you are under: the hull drains faster the deeper you go, and it stops the moment you surface.",
			"The lamp closes right in through water, the sound goes away, and the surface is a bright line you drop through.",
			"Rock the lamp has never reached keeps its texture instead of going flat.",
		],
	},
	{
		"version": "0.11.0",
		"date": "2026-09-11",
		"title": "Rock comes away in smaller pieces",
		"notes": [
			"The rock is cut at a third of a metre instead of a whole one, so the wall comes away in pieces a third the size and recedes steadily instead of in chunks.",
			"Digging is slower again: a full descent is about four minutes of cutting against three.",
			"The ship is stopped by exactly the rock you can see, rather than by a whole metre that is mostly gone.",
			"The lamp solves faster and the ground is rebuilt in small pieces, so the hitch when you cross a metre is gone.",
		],
	},
	{
		"version": "0.10.1",
		"date": "2026-09-11",
		"title": "Rock you can feel the weight of",
		"notes": [
			"Denser material is genuinely harder to cut. Ore slows you more than rock, and a rich seam more again, so a vein is something you feel in the drill before you see what it paid.",
			"Digging is slower than it was: about 2.2 m/s through surface rock against 7 m/s flying, so cutting reads as work rather than as driving.",
			"The drill, the rumble and the shake now run from the first metre. They were silent for the whole first forty metres of every planet.",
			"The lamp no longer goes out while you are buried in the rock you are cutting, which is most of the time now that the drill plows.",
		],
	},
	{
		"version": "0.10.0",
		"date": "2026-09-11",
		"title": "The drill is a plow",
		"notes": [
			"Digging is continuous. The ship moves on every frame instead of stopping to finish a block, and what changes with the rock is how fast you get through it.",
			"The deepest rock plows about four and a half times slower than the surface, and it never stops.",
			"The drill is one sound that gets lower and louder as the material gets harder, not a hit per block, and the rumble in your hand tracks the same thing.",
			"Tunnels come out smooth, so the lamp no longer catches on jagged edges you left behind.",
			"The lamp reads as one glow instead of a fan of separate beams: shadows are filtered across bearings rather than snapping between rays.",
			"A PAUSE button, so you do not need the back gesture.",
		],
	},
	{
		"version": "0.9.2",
		"date": "2026-09-10",
		"title": "Headlights in thick air",
		"notes": [
			"The whole tunnel now holds a soft light, not just the part near you. A side passage is dim because it bends away, not because it is far off.",
			"The lamp reads as headlights: a bright core that spreads as it goes, and it only shows because the air is thick enough to catch it.",
			"Deeper air catches more of it, so the beam gets shorter, brighter and grittier as you go down.",
			"Corners throw softer, wider shadows, and they no longer alias into a staircase at a distance.",
			"Tunnel walls and ceilings show real rock instead of vertical streaking.",
		],
	},
	{
		"version": "0.9.1",
		"date": "2026-09-10",
		"title": "The lamp points where you are going",
		"notes": [
			"The lamp throws a wide, soft beam ahead of the drill instead of a hard cone.",
			"Behind you the tunnel stays lit, dimmer and edgeless, so the way home never goes black.",
			"A second, shorter light with no direction picks out the rock face whenever you are beside it.",
			"Pass a side branch and its corner throws a wedge of shadow down the passage.",
			"The air thickens as you descend: the beam gets shorter, brighter and full of drifting grit.",
		],
	},
	{
		"version": "0.9.0",
		"date": "2026-09-10",
		"title": "A way in and a way out",
		"notes": [
			"A title screen over the live world, with CONTINUE greyed until you have a run.",
			"Progress saves itself: when a descent ends, when you fit a part, when you put the phone down.",
			"Settings live in their own file, so erasing progress never touches your volume.",
			"The pause screen carries the version, the build and everything that changed.",
			"The back button unwinds one screen at a time and never quits without asking.",
			"An icon, a splash in the game's own dark, and the screen stays awake while you dig.",
		],
	},
	{
		"version": "0.8.0",
		"date": "2026-09-10",
		"title": "Sound, and the dark it happens in",
		"notes": [
			"Every action makes a sound, and the drill is pitched by how hard the rock is.",
			"The room you are in is the room you hear: a tight shaft is dry, a cavern is enormous.",
			"The deep is muffled, because the air down there is thicker.",
			"A written theme, and it goes quiet as the pressure rises rather than louder.",
			"During the climb out there is no music at all.",
			"A vignette, film grain and lifted blacks, so the dark reads as a place.",
			"Haptics on every impact, on the phone.",
		],
	},
	{
		"version": "0.7.0",
		"date": "2026-09-10",
		"title": "Rime",
		"notes": [
			"A second kind of world, and it is a different world rather than a different colour.",
			"Ice cuts in half the time, so a Rime descent is quick.",
			"And the ceilings do not hold: cut wide and the rock above you starts to go.",
			"A one-cell shaft is safe forever. The wide cut is the gamble.",
			"Ice carries light much further than rock, so you can see where you are going.",
			"Cold instead of heat below the Line, and the whole world reads blue.",
		],
	},
	{
		"version": "0.6.0",
		"date": "2026-09-10",
		"title": "The Hold",
		"notes": [
			"A room inside your own ship, with the real ship in the middle of it.",
			"Upgrade parts sit on plinths as objects, not as rows in a list.",
			"Tap a case to fit the part. Drag to see the rest of the rack.",
			"The Gravewell Drive is on the wall from the first hour: seven slots, one per world.",
			"Two currencies. Credits are mined and buy the ladder.",
			"Filament is only ever FOUND, and it is the only thing that buys safety.",
			"So grinding the shallow band buys a bigger hold and never once buys survival.",
		],
	},
	{
		"version": "0.5.0",
		"date": "2026-09-10",
		"title": "Instruments, the Line, and getting out",
		"notes": [
			"Real instruments: power and hull up the left edge where your thumb never goes.",
			"Depth large at the top, and the load reads out in kilograms you can tap for a manifest.",
			"A drawn d-pad with eight directions, and buttons that go IN when you press them.",
			"The Line at 80 m: the rock changes colour, the air warms and the hull starts draining, all on the same metre.",
			"A cache shows through one layer of rock as a discolouration. Read the wall.",
			"Cut the core free and the world starts dying from the bottom up.",
			"The climb out is timed from the route you actually dug, so it is never impossible and never a stroll.",
			"Fail it and you lose the core and the planet. You never lose the save.",
		],
	},
	{
		"version": "0.4.0",
		"date": "2026-09-10",
		"title": "A real ship",
		"notes": [
			"The ship is a machine now: a plated hull, a cockpit, a drill assembly and two thrusters.",
			"The drill spins while it is cutting and the nozzles light with the throttle.",
			"The nose turns to face whatever you are digging into.",
			"The frame is tighter, and the dark is what justifies it.",
		],
	},
	{
		"version": "0.3.0",
		"date": "2026-09-10",
		"title": "Light that travels down the tunnel",
		"notes": [
			"The rock is real rock now: an eroded surface with relief under a moving lamp.",
			"Light spreads through the tunnels you cut instead of shining through stone.",
			"A shaft you dug an hour ago still carries light down it.",
			"Rock three layers deep is black, and a side tunnel you never opened is blacker.",
			"Corners throw a shadow down the passage behind them.",
			"Ore runs through the stone as veins rather than sitting in it as blocks.",
			"The air thickens as you go down, and it dims the lamp as it does.",
		],
	},
	{
		"version": "0.2.0",
		"date": "2026-09-10",
		"title": "The first descent",
		"notes": [
			"Fly a drill ship down through a dead world, one metre at a time.",
			"Cut rock and it remembers the damage, so you can stop and finish it later.",
			"Ore has weight, not slots, and the manifest says what each mineral is worth.",
			"Uplink the hold from wherever you are standing instead of flying it home.",
			"Three clocks that are not interchangeable: power, hull and what you carry.",
			"The lamp has three modes, and going dark gives you power back.",
			"Run low on power and the lamp dims, so the world closes in around you.",
			"Run out and you are recovered: you keep what you banked, and every tunnel stays open.",
		],
	},
	{
		"version": "0.1.0",
		"date": "2026-09-10",
		"title": "First playable",
		"notes": [
			"The first build of Gravewell.",
		],
	},
]
