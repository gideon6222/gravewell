class_name Fragments
extends RefCounted

## The log fragments, and the keepsakes: the two things in this game that are not
## a number.
##
## Pure data. No Node, no scene, nothing that needs a game running, so the wall
## that shows them is a renderer reading a table rather than a second copy of the
## story.
##
## ## Why it is a wall and not a cutscene
##
## From the plan: *"The story is not told, it is assembled. Log fragments from
## vaults and from Verge structures answer what killed these worlds. The
## objective is stated in the first two minutes because every top game in the
## genre does; the explanation is withheld, because mystery is withholding the
## explanation and never the goal."*
##
## So the player always knows what they are doing - seven cores, one drive, one
## way out - and never knows why the worlds are dead until they open the places
## that hold the answer. A fragment is therefore never required for anything.

## What each world's keepsake is. One per planet, in the deepest vault on it, and
## the only object in the game that is a memento rather than a resource.
const KEEPSAKES: Array[Dictionary] = [
	{"name": "Ledger Plate", "note": "a shift roster. every name struck through in the same hand."},
	{"name": "Frost Lantern", "note": "still cold. it was made to be carried by someone walking out."},
	{"name": "Tide Bell", "note": "rung from below. the clapper is worn on one side only."},
	{"name": "Ballast Seal", "note": "a counterweight, cast with a child's handprint in it."},
	{"name": "Span Marker", "note": "surveyor's brass. the far side was never marked."},
	{"name": "Relay Key", "note": "it still has charge. whatever it opened is not here."},
	{"name": "Quiet Spore", "note": "warm. it has not stopped moving since it was found."},
]

## The fragments, in the order they were left. Several per world, and a run finds
## them out of order, which is the point: the wall assembles as you go.
const LINES: Array[Dictionary] = [
	{"planet": 1, "text": "CORE LOG 1. The drive takes seven. We were told six."},
	{"planet": 1, "text": "CORE LOG 2. Nobody asked what the seventh was for."},
	{"planet": 2, "text": "RIME 1. The ice was not weather. It arrived."},
	{"planet": 2, "text": "RIME 2. We cut wide because we were in a hurry. That is the whole story."},
	{"planet": 3, "text": "DROWN 1. The water is not rising. We are letting it in."},
	{"planet": 3, "text": "DROWN 2. Every shaft we sank became a well. We kept sinking them."},
	{"planet": 4, "text": "CRUSH 1. There was never a safe depth. Only a shallower one."},
	{"planet": 4, "text": "CRUSH 2. The hull logs read the same at ten metres as at a hundred. Slower, that is all."},
	{"planet": 5, "text": "HOLLOW 1. Something ate this one from the inside and then left."},
	{"planet": 5, "text": "HOLLOW 2. We never found a wall it had not already been through."},
	{"planet": 6, "text": "VERGE 1. The current is still on. We turned nothing off."},
	{"planet": 6, "text": "VERGE 2. It draws from whatever is lit. Run dark and it forgets you."},
	{"planet": 7, "text": "QUICK 1. The cuts closed behind the last crew too."},
	{"planet": 7, "text": "QUICK 2. It is not healing. It is deciding we were never here."},
]


static func keepsake_of(planet: int) -> Dictionary:
	var i := clampi(planet - 1, 0, KEEPSAKES.size() - 1)
	return KEEPSAKES[i]


## The fragments belonging to one planet, in order.
static func lines_of(planet: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l in LINES:
		if int(l["planet"]) == planet:
			out.append(l)
	return out


## **How many of a planet's fragments the player has**, given how many they have
## picked up there. Capped at what exists, so a planet with three vaults and two
## fragments written does not print a fourth.
static func found_on(planet: int, picked: int) -> int:
	return mini(picked, lines_of(planet).size())


## How many fragments exist in the whole game, for the wall's counter.
static func total() -> int:
	return LINES.size()
