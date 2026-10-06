shader_type canvas_item;
// Slow zone: superheated liquid. Bubbles (same size as track bubbles) keep appearing and
// vanishing; the boundary is a ring of short dashes that shiver.
uniform vec2 zone_size = vec2(174.0, 172.0);
uniform float cell = 14.0;
uniform float bubble_radius = 3.0;
uniform vec4 ink : source_color = vec4(0.93, 0.93, 0.9, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * zone_size;
	vec2 id = floor(p / cell);
	float phase = fract(TIME * (0.3 + hash(id + 13.1) * 0.6) + hash(id));
	vec2 centre = (id + 0.5 + (vec2(hash(id + 5.0), hash(id + 9.0)) - 0.5) * 0.5) * cell;
	float bubble = (1.0 - smoothstep(bubble_radius - 0.8, bubble_radius + 0.4, length(p - centre)))
			* step(phase, 0.55) * 0.8;
	float tick = floor(TIME * 10.0);
	vec2 edge = min(p, zone_size - p);
	float along = (edge.x < edge.y) ? p.y : p.x;
	float shiver = (hash(vec2(floor(along / 9.0), tick)) - 0.5) * 2.0;
	float dist = min(edge.x, edge.y) + shiver;
	float dash = step(abs(dist - 1.5), 1.2) * step(0.45, fract(along / 9.0));
	// multiply by COLOR so node modulate (scan-in, power-off) still applies
	COLOR *= vec4(ink.rgb, max(bubble, dash));
}
