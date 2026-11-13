extends RefCounted
# Native retail ovr.bif fslit / material / lighting / config, ordinary unmapped
# fragment-lit material at quality 1/2. Base archive and quality-0 vertex paths
# are different policies; do not substitute those equations for this revision.
static func code(quality: int) -> String:
	return "#define NWN_STANDARD_QUALITY "+str(clampi(quality,1,2))+"\n"+"""
varying vec3 nwn_specular_color;
varying float nwn_specularity;
varying float nwn_environment_specularity;
varying float nwn_roughness;
varying float nwn_effective_alpha;
varying vec2 nwn_environment_uv;
varying vec3 nwn_environment_rgb;
vec2 nwn_standard_environment_uv(vec3 normal,vec3 position_view){
 vec2 reflect_uv=normal.xy/(1.0+abs(normal.z));
 reflect_uv+=0.5*(position_view.xy/(-position_view.z+0.2));
 return 0.5*reflect_uv+vec2(0.5,0.25);
}
float nwn_fresnel(float cosine){
 float value=1.0-cosine;
 #if NWN_STANDARD_QUALITY>1
 float square=value*value; value*=square*square;
 #else
 value*=value; value*=value;
 #endif
 return value;
}
float nwn_standard_cosine(float ndotl){
 #if NWN_STANDARD_QUALITY>1
 return ndotl> -0.25?smoothstep(0.0,2.0,mix(ndotl,1.0,0.25/1.25))*2.0:0.0;
 #else
 return max(ndotl,0.0);
 #endif
}
float nwn_standard_translucence(float ndotl){
 #if NWN_STANDARD_QUALITY>1
 return ndotl<0.0?-ndotl*(1.0-nwn_effective_alpha):0.0;
 #else
 return 0.0;
 #endif
}
float nwn_standard_specular(vec3 normal,vec3 light,vec3 view,float ndotl){
 float ndotv=max(dot(normal,view),0.0);
 float vdoth=sqrt(dot(view,light)*0.5+0.5);
 float ndoth=clamp((max(ndotl,0.0)+ndotv)*0.5/vdoth,0.0,1.0);
 float roughness_sq=nwn_roughness*nwn_roughness;
 float denominator=ndoth*ndoth*-(1.0-roughness_sq)+1.0;
 float distribution=1.0/(denominator*denominator);
 float base=roughness_sq*0.25;
 #if NWN_STANDARD_QUALITY>1
 base*=1.0/mix(ndotv,1.0,nwn_roughness);
 distribution*=mix(nwn_specularity,1.0,nwn_fresnel(vdoth));
 distribution*=1.0/mix(ndotl,1.0,nwn_roughness);
 #else
 distribution*=nwn_environment_specularity;
 #endif
 float result=distribution*base;
 if(nwn_effective_alpha<1.0&&nwn_effective_alpha>0.001)result/=max(nwn_effective_alpha,0.1);
 return result;
}
float nwn_standard_environment_scale(){
 float value=nwn_environment_specularity;
 if(nwn_effective_alpha<1.0&&nwn_effective_alpha>0.001)value/=max(nwn_effective_alpha,0.1);
 return value;
}
"""
static func vertex_code() -> String:
	return "nwn_environment_uv=nwn_standard_environment_uv(normalize(MODELVIEW_NORMAL_MATRIX*NORMAL),(MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz);"
static func fragment_code() -> String:
	# Godot requires fragment->light varying writes in fragment() itself.
	return """
 nwn_specularity=0.04;
 nwn_roughness=0.55;
 float nwn_ndotv=dot(NORMAL,VIEW);
 if(nwn_ndotv<0.0){NORMAL=normalize(NORMAL-nwn_ndotv*VIEW);nwn_ndotv=0.0;}
 nwn_environment_specularity=nwn_specularity;
 nwn_environment_specularity=mix(mix(nwn_environment_specularity,1.0,nwn_fresnel(nwn_ndotv)),nwn_environment_specularity,sqrt(nwn_roughness));
 vec3 nwn_albedo=ALBEDO*native_diffuse;
 nwn_specular_color=vec3(min(1.0,max(nwn_albedo.r,max(nwn_albedo.g,nwn_albedo.b))/pow(0.5,2.2)));
 nwn_effective_alpha=texel.a*native_alpha;
 #if NWN_STANDARD_QUALITY>1
 vec2 nwn_sample_uv=nwn_standard_environment_uv(NORMAL,VERTEX);
 #else
 vec2 nwn_sample_uv=nwn_environment_uv;
 #endif
 vec3 nwn_sample_environment=texture(nwn_native_environment,nwn_sample_uv,clamp(nwn_roughness*30.0-1.0,0.0,10.0)).rgb;
 nwn_environment_rgb=sign(nwn_sample_environment)*pow(abs(nwn_sample_environment),vec3(2.2));
"""
