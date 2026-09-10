shader_type canvas_item;

// Post-processing, and it goes UNDER the HUD.
//
// `CRAFT.md` calls this the cheapest mood tool there is, and the four things it
// asks for are all here: a vignette in three stops, animated mid-tone grain, a
// touch of aberration, and blacks lifted toward the scene colour.
//
// The last one is the one people leave out. A game this dark spends most of its
// frame at zero, and a true black reads as a hole in the screen rather than as
// unlit rock; lifting it a few per cent toward the scene's own colour is what
// makes the dark feel like a place. It also hides the banding that a gradient
// into pure black gets on an 8-bit panel.
//
// The grain is on the MID-TONES only. Grain in the shadows is noise in the one
// place the player is straining to see, and grain in the highlights is dirt on
// the lens.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float vignette : hint_range(0.0, 2.0) = 0.85;
uniform float grain : hint_range(0.0, 0.2) = 0.035;
uniform float aberration : hint_range(0.0, 4.0) = 1.1;
uniform vec3 lift : source_color = vec3(0.020, 0.023, 0.032);
uniform float pressure : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centred = uv - vec2(0.5);

	// Aberration, scaled by how far from the centre the pixel is, so the middle
	// of the frame stays clean and only the edges soften.
	float r2 = dot(centred, centred);
	vec2 off = centred * r2 * aberration * 0.004;
	vec3 col;
	col.r = texture(screen_texture, uv + off).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - off).b;

	// **A vignette in three stops**, not one smooth falloff: a single smoothstep
	// reads as a lens, and three reads as the limit of the light.
	float d = length(centred * vec2(1.0, 0.62));
	float v = 1.0;
	v *= 1.0 - smoothstep(0.30, 0.95, d) * 0.45 * vignette;
	v *= 1.0 - smoothstep(0.55, 1.10, d) * 0.40 * vignette;
	v *= 1.0 - smoothstep(0.78, 1.35, d) * 0.55 * vignette;
	// Past the Line it closes further, which is the fourth thing landing on that
	// metre and the only one the player feels rather than sees.
	v *= 1.0 - smoothstep(0.20, 1.0, d) * 0.35 * pressure;
	col *= v;

	// Mid-tone grain, animated, so a still frame is never quite still.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float mid = smoothstep(0.02, 0.22, luma) * (1.0 - smoothstep(0.45, 0.85, luma));
	float n = hash(uv * vec2(1920.0, 1080.0) + fract(TIME) * 97.0) - 0.5;
	col += n * grain * mid;

	// Blacks lifted toward the scene colour.
	col = mix(lift, vec3(1.0), clamp(col, vec3(0.0), vec3(1.0)));

	COLOR = vec4(col, 1.0);
}
