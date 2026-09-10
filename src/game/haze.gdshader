shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;

// **Light in the AIR**, which is the half that lighting a tunnel's walls does
// not give you.
//
// A dug cell contains no geometry, so the space itself stays dead however well
// the walls around it are lit: the tunnel reads as a black slot with bright
// edges. This quad sits just behind the rock's front face, so the rock occludes
// it and it shows only through the openings, and it puts an additive glow in
// the tunnel volume.
//
// Coreward's playtest note asked for both halves in one sentence and only one
// was built, and the reply was three more rounds about the shadow being wrong,
// which it was not: the shadow was on the wrong SURFACE.
//
//     SURFACE = spill * falloff * beam           <- rock.gdshader
//     AIR     = flood * falloff * beam * shadow  <- here
//
// The shadow belongs to this term ONLY. Handing it to the rock is what carved
// hard-edged wedges across every wall face in the frame.

uniform sampler2D field : filter_linear, source_color, hint_default_black;
uniform vec2 field_origin;
uniform float field_side;
uniform float field_radius;

// Per bearing, how far light gets before something stops it, normalised against
// the reach. One dimension, so it is 256 texels wide and one tall.
uniform sampler2D fan : filter_linear, source_color, hint_default_white;

uniform vec2 lamp_pos;
uniform vec2 lamp_dir;
uniform float lamp_reach;
uniform float lamp_cos;
uniform vec3 tint : source_color = vec3(1.0, 0.93, 0.82);
uniform float strength : hint_range(0.0, 3.0) = 1.7;
uniform float density = 0.05;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = vec2(world_pos.x, -world_pos.y);

	// Godot does not allow `return` in the fragment processor, so the
	// out-of-field case is a multiply rather than an early out.
	vec2 uv = (p - field_origin + vec2(field_radius)) / field_side;
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	// R is the flood: light in OPEN cells. The air term reads this and never
	// the spill, so a rock face never adds glow to the space in front of it.
	float flood = texture(field, clamp(uv, vec2(0.0), vec2(1.0))).r * inside;

	vec2 away = p - lamp_pos;
	float dist = length(away);
	float reach = lamp_reach / (1.0 + density * 0.45);
	float falloff = clamp(1.0 - dist / max(reach, 0.001), 0.0, 1.0);
	falloff *= falloff;

	vec2 to = dist > 0.0001 ? away / dist : lamp_dir;
	float beam = smoothstep(lamp_cos - 0.30, lamp_cos + 0.15, dot(to, lamp_dir));
	beam = mix(0.18, 1.0, beam);

	// The shadow, sampled the way the fan was built: the bearing indexes the
	// texture and linear filtering blends the two nearest rays, which is
	// exactly what the headless test reproduces when it asserts the lit-face
	// fraction.
	float ang = atan(away.y, away.x);
	float fan_u = fract(ang / 6.2831853 + 1.0);
	float occ = texture(fan, vec2(fan_u, 0.5)).r * reach;
	// A soft edge rather than a step: a hard binary shadow on a 1080-wide phone
	// aliases into a staircase along every wedge.
	float shadow = 1.0 - smoothstep(occ - 0.35, occ + 0.35, dist);

	// Denser air scatters more, so the deep glows more and sees less. One
	// number driving both is the whole point of the air being simulated.
	float scatter = 1.0 + density * 0.8;

	// **A near-field ramp.** Without one the air term is brightest at zero
	// distance, which is exactly where the ship is, and the ship renders as a
	// white blob with no readable shape whatever its own materials say. Two
	// rounds went into the hull's metallic and albedo before the blob turned out
	// to be an additive quad drawn over it.
	//
	// It is also the physically right shape: you do not see a beam in the air at
	// its own source, because there is no path length there to scatter along.
	float near = smoothstep(0.0, 1.8, dist);

	float lit = flood * falloff * beam * shadow * strength * scatter * near;
	ALBEDO = tint * lit;
	ALPHA = 1.0;
}
