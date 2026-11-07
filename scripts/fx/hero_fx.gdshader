// Magic gear on a hero (HeroLook's effects sheet, drawn over the hero sprite, additive).
// R = main weapon (1 on the blade, falling off around it), G = magic armour / shield, B = ranged weapon.
// Modes: 0 none, 1 shimmer (+1: a gleam runs along the blade), 2 glow (+2: soft pulsing halo),
// 3 fire (flickering flames rising), 4 frost (cold mist drifting down), 5 radiant (golden pulse + sparks).
// Everything is worked out per sheet pixel, so it stays pixel art.
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec2 sheet_px = vec2(160.0, 64.0);
uniform int main_mode = 0;
uniform vec4 main_color : source_color = vec4(1.0);
uniform int ranged_mode = 0;
uniform vec4 ranged_color : source_color = vec4(1.0);
uniform float glint = 0.0;
uniform vec4 glint_color : source_color = vec4(1.0);
uniform float phase = 0.0;          // per hero, so the party doesn't shimmer in step

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 weapon(int mode, vec3 col, float z, vec2 px, float t) {
	if (z <= 0.0 || mode == 0) {
		return vec3(0.0);
	}
	bool core = z > 0.99;
	if (mode == 1) {
		if (!core) return vec3(0.0);
		float band = pow(max(0.0, sin((px.x * 0.6 - px.y * 0.6) * 0.5 + t * 3.0)), 12.0);
		return col * (0.12 + band * 0.9);
	}
	if (mode == 2) {
		float pulse = 0.55 + 0.25 * sin(t * 3.0);
		return col * (core ? 0.35 + 0.25 * pulse : z * pulse * 0.8);
	}
	if (mode == 3) {
		// quantised time steps keep the flicker crisp, like the torch flames
		float tt = floor(t * 12.0) / 12.0;
		float n = noise(vec2(px.x * 0.8, px.y * 0.55 + tt * 7.0));
		float f = z * (0.45 + n * 0.95);
		f = step(0.4, f) * f;
		vec3 ramp = mix(vec3(0.75, 0.12, 0.04), vec3(1.0, 0.62, 0.18), smoothstep(0.45, 0.85, f));
		ramp = mix(ramp, vec3(1.0, 0.92, 0.55), smoothstep(0.9, 1.15, f));
		return ramp * clamp(f, 0.0, 1.0) * 1.1;
	}
	if (mode == 4) {
		float tt = floor(t * 8.0) / 8.0;
		float n = noise(vec2(px.x * 0.5 + tt * 0.6, px.y * 0.5 - tt * 2.0));
		float f = z * (0.25 + n * 0.75);
		f = step(0.3, f) * f;
		return col * f * (core ? 0.7 : 0.55);
	}
	if (mode == 5) {
		float pulse = 0.6 + 0.3 * sin(t * 2.5);
		vec3 c = col * z * pulse * 0.75;
		float tt = floor(t * 6.0);
		if (!core && hash(px + vec2(tt * 3.1, tt * 1.7)) > 0.93) {
			c += vec3(1.0, 0.97, 0.8) * z;
		}
		return c;
	}
	return vec3(0.0);
}

void fragment() {
	vec4 m = texture(TEXTURE, UV);
	vec2 px = floor(UV * sheet_px);
	float t = TIME + phase;
	vec3 c = weapon(main_mode, main_color.rgb, m.r, px, t);
	c += weapon(ranged_mode, ranged_color.rgb, m.b, px, t);
	if (m.g > 0.0 && glint > 0.0) {
		// a thin gleam sweeps across the armour now and then (~2 s in every 10)
		float cyc = mod(t * 22.0, 220.0) - 10.0;
		float d = abs(mod(px.x, 32.0) + mod(px.y, 32.0) * 0.5 - cyc);
		float band = d < 0.75 ? 1.0 : (d < 1.75 ? 0.3 : 0.0);
		vec3 shine = mix(glint_color.rgb, vec3(1.0), 0.45);
		c += (shine * band * 0.55 + glint_color.rgb * 0.03) * glint;
	}
	COLOR = vec4(c, 1.0);
}
