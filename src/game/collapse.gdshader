shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;

// What comes up behind you once the core is free.
//
// The clock and the picture are **one quantity**: `rising` is the depth the
// world has died up to, the simulation kills the player when it passes them, and
// this draws that same number. There is no second value that could disagree, and
// a player who thinks they had another second is a player the game lied to.
//
// Additive over the scene rather than opaque, so the rock the player is climbing
// through stays legible right up to the moment it goes. A wall of flat colour
// would hide the route out at exactly the moment the route out is the game.

uniform float rise_depth = 999.0;   // sim depth, positive downward
uniform float band = 7.0;           // how tall the glowing front is, in metres
uniform vec3 hot : source_color = vec3(1.0, 0.42, 0.13);
uniform vec3 deep_core : source_color = vec3(0.55, 0.06, 0.02);
uniform float time_scale = 1.7;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Cheap value noise. The front has to boil rather than slide, or a rising line
// reads as a loading bar rather than as a planet coming apart.
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
	float depth = -world_pos.y;

	// The front's own edge wanders, so it is a tide of rock rather than a line.
	float wobble = (noise(vec2(world_pos.x * 0.35, TIME * 0.6)) - 0.5) * 2.4;
	float front = rise_depth + wobble;

	// Below the front: gone. Above it: a glow that falls off over `band`.
	float below = step(front, depth);
	float glow = clamp(1.0 - (front - depth) / band, 0.0, 1.0);
	glow *= glow;

	float boil = noise(vec2(world_pos.x * 0.8, depth * 0.8 - TIME * time_scale));
	vec3 col = mix(hot, deep_core, clamp(boil * 0.85, 0.0, 1.0));

	ALBEDO = col * (glow * 1.35 + below * 1.9);
	ALPHA = 1.0;
}
