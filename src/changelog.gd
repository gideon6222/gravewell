class_name Changelog
extends RefCounted

## What changed, in the player's terms. Newest first, one line each, describe
## what the player can now do or see. The build stamp says whether an update
## landed; this says what it was.
##
## This is one fact in three places - here and `version/name` in each export
## preset - and `test_version.gd` asserts they agree, because nothing derives
## one from the other and they have drifted in a sibling game already.

const VERSION := "0.3.0"

const RELEASES := [
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
