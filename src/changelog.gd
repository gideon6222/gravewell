class_name Changelog
extends RefCounted

## What changed, in the player's terms. Newest first, one line each, describe
## what the player can now do or see. The build stamp says whether an update
## landed; this says what it was.
##
## This is one fact in three places - here and `version/name` in each export
## preset - and `test_version.gd` asserts they agree, because nothing derives
## one from the other and they have drifted in a sibling game already.

const VERSION := "0.9.0"

const RELEASES := [
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
