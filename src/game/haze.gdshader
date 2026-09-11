shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;

// **Light in the AIR**: the beam you can see, the fill behind it, the shadows
// corners throw, and the thickness of the air it travels through.
//
// A dug cell contains no geometry, so the space itself stays dead however well
// the walls around it are lit: the tunnel reads as a black slot with bright
// edges. This quad sits behind the ship and behind the rock's front face, so
// both occlude it, and it puts light INTO the tunnel volume.
//
// ## What this is built to, in his words
//
//   "forward light creates a dispersed beam, but also fills the rest of the
//    tunnel behind. as you pass corners, it should create shadows. the air
//    should start looking thick in the tunnels."
//
// Four things, and each is its own term below:
//
//   BEAM    a wide soft cone along the drill. Dispersed, not a spotlight.
//   FILL    omnidirectional, shorter, weaker: the rest of the tunnel behind.
//   SHADOW  the ray fan. A corner throws a wedge into the passage behind it.
//   THICK   the air itself, scaling with depth, with motes moving in it.
//
// ## What the previous version got wrong, measured rather than guessed
//
// Rendering each term to the screen on its own showed two faults at once.
//
// **The beam was not directional.** `mix(0.18, 1.0, smoothstep(...))` over a
// 2.4-radian cone saturated almost everywhere, so the term came out near-flat
// across the whole tunnel and there was no forward shape at all.
//
// **The near-field ramp ran to 1.8 m**, which is most of a ship's length, so the
// nearest visible air light began well BEHIND the drill. Combined with a shaft
// that is open behind and solid rock ahead, the composite read as a lamp
// pointing backwards, which is exactly what it was reported as.
//
// ## The two rules this file exists to obey
//
// **Combine the beam and the fill with `max()`, never by multiplying two
// floors.** Multiplying "how much survives behind the player" by "how much
// survives in shadow" lands anywhere that is both on the product, which is
// black, and that erases the shaft the player came down: the way home.
//
// **Give the fill its OWN falloff.** Sharing the beam's pool makes the glow
// behind the player end exactly where the beam does, with the same hard edge,
// which is the one thing the soft half must not do.

uniform sampler2D field : filter_linear, source_color, hint_default_black;
uniform vec2 field_origin;
uniform float field_side;
uniform float field_radius;

// Per bearing, how far light gets before something stops it, normalised against
// `fan_reach` and NOT against the lamp's reach. Those were different numbers:
// the fan was cast to 1.8x the lamp's reach and decoded with 1x, so every shadow
// began at 55% of its true distance and the lit pool was cut short everywhere.
// One number, passed in, used at both ends.
uniform sampler2D fan : filter_linear, source_color, hint_default_white;
uniform float fan_reach = 12.0;

uniform vec2 lamp_pos;
uniform vec2 lamp_dir;
uniform float lamp_reach;
uniform vec3 tint : source_color = vec3(1.0, 0.93, 0.82);
uniform float strength : hint_range(0.0, 4.0) = 1.9;
uniform float density = 0.05;

// The beam is DISPERSED: a wide, soft angular profile rather than a cone with an
// edge. These are dot products with the heading, so -1 is directly behind.
uniform float cone_lo = -0.35;
uniform float cone_hi = 0.75;
// Barely above nothing. The air behind the ship is the AMBIENT term's job now,
// so the beam does not need a floor holding it up; this only keeps the edge of
// the cone from being a line.
uniform float beam_floor : hint_range(0.0, 0.5) = 0.03;

// **The beam is the air scattering, so it scales with the air.** In clear air
// you would see only what the lamp lands on: the visible shaft of a headlight
// is entirely a fog effect. Tying its strength to the same density that drags
// the ship and muffles the sound is what makes it read as headlights cutting
// through something rather than as a cone painted on the screen.
uniform float beam_scatter_lo : hint_range(0.0, 2.0) = 0.55;
uniform float beam_scatter_gain : hint_range(0.0, 2.0) = 0.55;
uniform float beam_scatter_max : hint_range(0.5, 4.0) = 2.2;
// Overall beam brightness. Separate from `strength`, which scales the ambient
// too: measured at 1.0 the beam saturated at 220 of 255 down the middle of a
// shaft, and a blown-out core cannot show grit moving in it.
uniform float beam_gain : hint_range(0.0, 2.0) = 0.5;

// **The beam's profile ACROSS itself, which the cone cannot give it.**
//
// A cone is an angular test from the lamp. In a shaft one cell wide the whole
// shaft sits well inside any usable cone, so the cone is constant across it and
// the beam comes out a flat slab with a razor edge at each wall: an object in
// the tunnel rather than light in the air. A headlight has an intensity profile
// across the beam, brightest on the axis, and it WIDENS as it goes, which is
// what "dispersed" means.
//
// `core_width` is the half-width at the lamp in metres and `core_spread` is how
// many metres wider it gets per metre travelled.
uniform float core_width : hint_range(0.05, 3.0) = 0.35;
uniform float core_spread : hint_range(0.0, 1.5) = 0.30;
uniform float core_edge : hint_range(0.0, 1.0) = 0.22;

// **The ambient: the whole tunnel, lit, with no falloff of its own.**
//
// This replaced a "fill" term that was a second pool around the ship on a
// second radius, and his reply to that was: "Instead of thick air, this looks
// more similar to a beam coming from the ship. Can you make it so that the
// there is a soft dispersed light throughout the whole tunnel."
//
// A distance falloff measured from the LAMP is the thing that makes light look
// like it belongs to the ship. `flood` already carries the right quantity: how
// much lamp light reached this open cell ALONG THE PASSAGE, which is 1 down an
// open shaft however long it is and falls only where the route bends. Used raw
// it is light present in the tunnel, not light thrown from a lamp.
uniform float ambient_gain : hint_range(0.0, 1.0) = 0.045;
// How far a corner's shadow can darken the ambient. Never to nothing: air in a
// shadow is still air, and a black wedge in fog is a hole cut in the fog.
uniform float ambient_shadow : hint_range(0.0, 1.0) = 0.35;

// How much thicker the air looks per unit of density, and how strongly the
// motes drifting in it read.
uniform float thick_gain = 0.32;
uniform float mote_gain : hint_range(0.0, 1.0) = 0.5;

// **Term isolation, kept rather than hacked in twice.** 0 is the game; 1..5
// render one term on its own so a fault can be SEEN instead of argued about.
// `scripts/shot_term.gd` drives it. Both faults this file has had were found
// this way and neither was visible by reading the code: a beam that turned out
// not to be directional at all, and a black stretch of shaft that turned out to
// be a real ceiling four cells up rather than a broken shadow.
uniform int debug_term : hint_range(0, 5) = 0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
	           mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = vec2(world_pos.x, -world_pos.y);

	// Godot does not allow `return` in the fragment processor, so the
	// out-of-field case is a multiply rather than an early out.
	vec2 uv = (p - field_origin + vec2(field_radius)) / field_side;
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	// R is the flood: light in OPEN cells. The air term reads this and never the
	// spill, so a rock face never adds glow to the space in front of it.
	float flood = texture(field, clamp(uv, vec2(0.0), vec2(1.0))).r * inside;

	vec2 away = p - lamp_pos;
	float dist = length(away);
	vec2 to = dist > 0.0001 ? away / dist : lamp_dir;
	float forward = dot(to, lamp_dir);

	// ── SHADOW: what a corner throws ──────────────────────────────────────
	// Sampled the way the fan was built: the bearing indexes the texture and
	// linear filtering blends the two nearest rays, which is what the headless
	// test reproduces when it asserts the lit-face fraction.
	float ang = atan(away.y, away.x);
	float fan_u = fract(ang / 6.2831853 + 1.0);
	float occ = texture(fan, vec2(fan_u, 0.5)).r * fan_reach;
	// A soft edge rather than a step: a hard binary shadow on a 1080-wide phone
	// aliases into a staircase along every wedge.
	// The soft edge WIDENS with distance. A fixed 0.30 m band is a crisp line at
	// ten metres, where the fan's own angular resolution is coarser than the
	// line it is drawing, so the wedge aliases into a staircase; and a crisp
	// wedge in fog is a cut rather than a shadow.
	float edge = 0.25 + dist * 0.12;
	float shadow = 1.0 - smoothstep(occ - edge, occ + edge, dist);

	// ── AMBIENT: the whole tunnel, everywhere the light got to ────────────
	// No distance term at all. `flood` is the distance term, and it measures the
	// right distance: along the passage rather than through the rock.
	float ambient = flood * ambient_gain * mix(ambient_shadow, 1.0, shadow);

	// ── BEAM: the headlights ──────────────────────────────────────────────
	// Squared, so the middle of the cone is genuinely brighter than its edge and
	// the beam has a SHAPE rather than being a lit region with a boundary.
	float cone = smoothstep(cone_lo, cone_hi, forward);
	cone *= cone;
	float beam_reach = lamp_reach / (1.0 + density * 0.35);
	// CUBED, not squared. A beam that holds its brightness to the end of its
	// reach and then stops has an end, and an end is what makes it read as an
	// object rather than as light dissolving into air. Measured: squared, the
	// beam was still at 148 of 255 where it left the frame.
	float beam_fall = clamp(1.0 - dist / max(beam_reach, 0.001), 0.0, 1.0);
	beam_fall = beam_fall * beam_fall * beam_fall;
	// Perpendicular distance from the beam's axis, and a Gaussian across it whose
	// width grows with how far down the beam the pixel is.
	float along = max(dot(away, lamp_dir), 0.0);
	float off = length(away - lamp_dir * along);
	float w = core_width + core_spread * along;
	float core = exp(-(off * off) / max(2.0 * w * w, 1.0e-4));

	float beam = mix(beam_floor, 1.0, cone) * mix(core_edge, 1.0, core)
		* beam_fall * flood * shadow * beam_gain;
	// It exists because the air does.
	beam *= min(beam_scatter_lo + density * beam_scatter_gain, beam_scatter_max);

	// **Added, not `max`ed.** Fog scatters the ambient and the beam at the same
	// point in the same air, and what you see is the sum; taking the larger of
	// the two puts a visible seam along the cone's edge where one term overtakes
	// the other. `max()` is still the rule for two terms that are the SAME light
	// counted twice, which is what the rock's three are.
	float lit = ambient + beam;

	// ── THICK: the air itself ─────────────────────────────────────────────
	// The same density that thickens the fog, shortens the lamp and drags the
	// ship makes the tunnel air visibly scatter. The motes are anchored to the
	// WORLD and drift slowly, so they read as air the ship is moving through
	// rather than as dirt on the lens.
	float thick = 1.0 + density * thick_gain;
	float motes = noise(p * 0.55 + vec2(0.0, TIME * 0.11))
		* noise(p * 1.3 - vec2(TIME * 0.07, 0.0));
	// The motes scale with the SAME density, so the surface air is nearly clear
	// and the deep is soup. A constant grain everywhere is dirt on the lens; a
	// grain that arrives as you descend is the air getting thick.
	// Stronger INSIDE the cone, because that is where a headlight shows you what
	// is floating in front of it. Outside, the same air is a flat glow.
	float grit = mote_gain * clamp(0.30 + density * 0.55, 0.30, 1.6) * mix(0.6, 1.5, cone);
	lit *= thick * (1.0 - grit * 0.5 + grit * motes * 1.6);

	// A very SHORT ramp, only enough that the quad cannot wash the hull at a
	// grazing angle. At 1.8 m it put the nearest visible light behind the drill.
	lit *= smoothstep(0.0, 0.55, dist);

	// Each branch replaces the composite with ONE term, unscaled by the others,
	// which is the whole point: a term that is wrong is usually wrong flat.
	if (debug_term == 1) { lit = beam; }
	else if (debug_term == 2) { lit = ambient; }
	else if (debug_term == 3) { lit = flood; }
	else if (debug_term == 4) { lit = shadow * flood; }
	else if (debug_term == 5) { lit = (thick - 1.0) * 0.5; }

	ALBEDO = tint * lit * strength;
	ALPHA = 1.0;
}
