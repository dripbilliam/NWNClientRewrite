// Godot world Y corresponds to NWN world Z.
float cx_fog_amount(float enabled, vec2 ramp, vec4 origin, vec2 layer, vec3 world, float depth) {
	if (enabled == 0.0) return 0.0;
	float d = origin.w > 0.0 ? distance(world, origin.xyz) : depth;
	float amount = max((d - ramp.x) * ramp.y, 0.0);
	if (layer.x > 0.0) amount *= exp(-max(world.y - layer.y, 0.0) * layer.x);
	return min(amount, 1.0);
}

vec3 cx_fog_display_color(vec3 raw, vec4 sky, vec4 sun, vec3 sun_color, vec3 ray, float amount) {
	if (amount <= 0.0 || sky.w <= 0.0) return raw;
	vec3 direction = ray * inversesqrt(max(dot(ray, ray), 1e-20));
	float weight = sky.w * smoothstep(-0.35, 0.0, direction.y) * amount;
	vec3 target = mix(pow(max(raw, vec3(0.0)), vec3(2.2)), sky.rgb, weight);
	if (sun.w > 0.0) target += sun_color * (amount * pow(max(dot(direction, sun.xyz), 0.0), sun.w));
	return pow(max(target, vec3(0.0)), vec3(1.0 / 2.2));
}
