shader_type canvas_item;
// Dims the screen except an elliptical spotlight (dice scene: time freezes on the target).
uniform vec2 spot = vec2(320.0, 180.0);   // screen pixels (640x360)
uniform float radius = 64.0;
uniform float amount = 0.0;               // 0 = no dimming, 1 = full
uniform float darkness = 0.62;

void fragment() {
	vec2 p = UV * vec2(640.0, 360.0);
	float d = length((p - spot) * vec2(1.0, 1.25));
	float a = darkness * smoothstep(radius * 0.45, radius, d) * amount;
	COLOR = vec4(0.02, 0.0, 0.05, a);
}
