// CX rain-only volume lookup from cx_vfog.glsl. See native/CX-LICENSE.txt.
vec4 cx_rain_haze_at(sampler3D volume, vec2 uv, float depth, float near_z, float inv_log) {
	float layers = float(textureSize(volume, 0).z);
	float slice = clamp(log(max(depth, near_z) / near_z) * inv_log, 0.0, 1.0) * layers;
	vec4 fog = texture(volume, vec3(uv, (max(slice, 1.0) - 0.5) / layers));
	return slice < 1.0 ? mix(vec4(0.0, 0.0, 0.0, 1.0), fog, slice) : fog;
}

// Express the integral as display-space premultiplied fog before mixing
// it into the native surface carrier.
vec4 cx_rain_haze_display(vec4 fog) {
	float amount = 1.0 - fog.a;
	return vec4(amount * pow(max(fog.rgb / max(amount, 1e-6), vec3(0.0)), vec3(1.0 / 2.2)), amount);
}
