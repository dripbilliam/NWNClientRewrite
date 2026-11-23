#include "cx_particle_light_grid.hpp"
namespace cx_particle {
struct alignas(16) Record {
 V3 near_center;
 uint32_t near_color;
 V3 far_center;
 uint32_t far_color;
 V3 right;
 float softness;
 V3 up;
 float render_type;
 V3 center;
 float center_padding=0;
 std::array<float,4> uv;
 V3 previous_center;
 float previous_padding=0;
};
static_assert(sizeof(Record)==112);

constexpr size_t bytes_for_vertices(int64_t count){
 return static_cast<size_t>(count/6)*sizeof(Record);
}

V3 to_world(const V3& value){
 return {value[0],value[2],-value[1]};
}

float softness(bool splat,int64_t mode,float largest_half_extent){
 if(splat||mode==1||mode==2||!(largest_half_extent>0))return 0;
 return 1.0f/(0.2f*std::min(largest_half_extent,1.0f));
}

// RenderDevice has no first-vertex argument for procedural draws. Keep the
// affine view transform and the base corner together in 128 push bytes.
constexpr const char* vertex_shader=R"glsl(
struct Particle {
 uvec4 near_color;
 uvec4 far_color;
 vec4 right_softness;
 vec4 up_type;
 vec4 center;
 vec4 uv_rect;
 vec4 previous_center;
};
layout(set=2,binding=0,std430) readonly buffer Particles { Particle records[]; };
layout(set=2,binding=1,std430) readonly buffer DrawOrder { uint indices[]; };
layout(set=2,binding=3,std430) readonly buffer LightGrid {
 vec4 depth;
 uint masks[];
} grid;
layout(set=1,binding=2) uniform sampler2D sun_near_depth;
layout(set=1,binding=3) uniform sampler2D sun_far_depth;
layout(set=1,binding=5) uniform sampler2D sun_moving_near_depth;
layout(set=1,binding=6) uniform sampler2D sun_moving_far_depth;
layout(set=1,binding=7) uniform sampler2D omni_shadow_depth;
layout(set=1,binding=4,std140) uniform SunFits {
 mat4 near_view_projection;
 mat4 far_view_projection;
 vec4 focus_strength;
 vec4 radii_enabled;
} sun;
struct OmniShadow {
 vec4 rect;
 vec4 sample_params;
 vec4 world_to_light[3];
 vec4 opacity;
};
layout(set=2,binding=4,std430) readonly buffer OmniShadows {
 uvec4 header;
 OmniShadow lights[];
} omni;
layout(push_constant,std430) uniform Params { mat4 projection; vec4 view_rows[3]; uvec4 draw; } params;
layout(constant_id=3) const bool lit=false;
layout(location=0) out vec4 tint;
layout(location=1) out vec2 uv;
layout(location=2) out vec3 fog_world;
layout(location=3) out float view_depth;
layout(location=4) flat out float softness;
layout(location=5) out vec3 particle_light;
layout(location=6) flat out vec3 fog_eye;

vec3 safe_normalize(vec3 v){
 return v*inversesqrt(max(dot(v,v),1e-20));
}

uint light_cell(vec4 clip,float depth){
 if(grid.depth.x<=0.0||clip.w<=0.0||depth<grid.depth.x||depth>grid.depth.y)return light_cells;
 vec2 ndc=clip.xy/clip.w;
 if(any(greaterThan(abs(ndc),vec2(1.0))))return light_cells;
 ivec2 tile=clamp(ivec2((ndc*0.5+0.5)*vec2(light_grid.xy)),ivec2(0),light_grid.xy-1);
 int slice=clamp(int(log(depth/grid.depth.x)*grid.depth.w),0,GRID_Z-1);
 return uint(tile.x+GRID_X*(tile.y+GRID_Y*slice));
}

float omni_visibility(uint light_index,vec3 point){
 if(light_index>=omni.header.x)return 1.0;
 OmniShadow shadow=omni.lights[light_index];
 if(shadow.opacity.x<=0.0)return 1.0;
 vec4 world=vec4(point,1.0);
 vec3 local=vec3(dot(shadow.world_to_light[0],world),dot(shadow.world_to_light[1],world),dot(shadow.world_to_light[2],world));
 float distance_to_light=length(local);
 if(distance_to_light<1e-4)return 1.0;
 vec3 direction=local/distance_to_light;
 vec2 hemisphere=direction.z>=0.0?shadow.sample_params.xy:vec2(0.0);
 vec2 uv=(direction.xy/(1.0+abs(direction.z)))*0.5+0.5;
 ivec2 size=textureSize(omni_shadow_depth,0);
 vec2 low=(shadow.rect.xy+hemisphere)*vec2(size)+1.0;
 vec2 high=low+shadow.rect.zw*vec2(size)-2.0;
 ivec2 base=ivec2(floor(mix(low,high,uv)-0.5));
 float receiver=1.0-(distance_to_light-shadow.sample_params.w)*shadow.sample_params.z;
 float lit=0.0;
 for(int y=0;y<2;++y)for(int x=0;x<2;++x){
  ivec2 tap=clamp(base+ivec2(x,y),ivec2(low),ivec2(high)-1);
  lit+=step(texelFetch(omni_shadow_depth,tap,0).r,receiver);
 }
 // The media normal faces the eye, so apply only the depth bias. CX's
 // diffuse floor scales with area luminance to preserve dark night scenes.
 float ambient_luminance=dot(lighting.ambient_enabled.rgb,vec3(0.2126,0.7152,0.0722));
 float floor_light=0.35*clamp(2.0*ambient_luminance,0.0,1.0);
 return mix(1.0,mix(floor_light,1.0,lit*0.25),shadow.opacity.x);
}

vec3 point_light(uint index,vec3 point,vec3 normal){
 PointLight p=lighting.lights[index];
 vec3 to_light=p.position_range.xyz-point;
 float distance_squared=dot(to_light,to_light);
 float range_squared=p.position_range.w*p.position_range.w;
 if(distance_squared>=range_squared)return vec3(0.0);
 float f2=distance_squared/range_squared;
 float attenuation=(1.0-f2)/(p.attenuation.x+p.attenuation.y*f2);
 if(p.color_ambient.w>0.0)return p.color_ambient.rgb*attenuation;
 float inv_distance=inversesqrt(max(distance_squared,1e-8));
 float dot_light=dot(normal,to_light*inv_distance);
 float wrap=min(inv_distance,1.0);
 float wrapped=(dot_light+wrap)/(1.0+wrap);
 float softened=min(2.0*smoothstep(0.0,2.0,(wrapped+0.25)/1.25),1.0);
 const float sss=0.25;
 float scatter=max(dot_light+sss,0.0)*(2.0/(2.0+3.14159265359*sss));
 return p.color_ambient.rgb*(attenuation*(softened+scatter)*omni_visibility(index,point));
}

// CX media uses four depth comparisons and a constant bias. Godot stores
// reversed depth, so a larger receiver depth is closer to the sun.
float sun_depth_visibility(sampler2D depths,vec3 ndc,float radius){
 ivec2 size=textureSize(depths,0);
 ivec2 base=ivec2(floor((ndc.xy*0.5+0.5)*vec2(size)-0.5));
 float receiver=ndc.z+0.04/(4.0*radius);
 float lit_count=0.0;
 for(int y=0;y<2;++y)for(int x=0;x<2;++x){
  ivec2 texel=clamp(base+ivec2(x,y),ivec2(0),size-1);
  lit_count+=step(texelFetch(depths,texel,0).r,receiver);
 }
 return 0.25*lit_count;
}

bool in_sun_fit(vec3 ndc){
 return all(lessThanEqual(abs(ndc.xy),vec2(0.985)))&&ndc.z>=0.0&&ndc.z<=1.0;
}

float sample_sun_fit(sampler2D static_depth,sampler2D moving_depth,int layers,vec3 ndc,float radius){
 float fixed_shadow=(layers&1)!=0?sun_depth_visibility(static_depth,ndc,radius):1.0;
 float moving_shadow=(layers&2)!=0?sun_depth_visibility(moving_depth,ndc,radius):1.0;
 return min(fixed_shadow,moving_shadow);
}

float particle_sun_visibility(vec3 point){
 if(sun.focus_strength.w<=0.0)return 1.0;
 float distance_to_focus=distance(point,sun.focus_strength.xyz);
 float near_radius=sun.radii_enabled.x;
 float fade=clamp((distance_to_focus-0.70*near_radius)/(0.20*near_radius),0.0,1.0);
 vec4 world=vec4(point,1.0);
 vec3 near_ndc=(sun.near_view_projection*world).xyz;
 bool has_near=sun.radii_enabled.z>0.0&&in_sun_fit(near_ndc);
 float visibility=1.0;
 vec3 far_ndc=(sun.far_view_projection*world).xyz;
 bool has_far=sun.radii_enabled.w>0.0&&in_sun_fit(far_ndc);
 if(has_near&&(!has_far||fade<1.0))
  visibility=sample_sun_fit(sun_near_depth,sun_moving_near_depth,int(sun.radii_enabled.z),near_ndc,near_radius);
 if(has_far&&(!has_near||fade>0.0)){
  float outer=sample_sun_fit(sun_far_depth,sun_moving_far_depth,int(sun.radii_enabled.w),far_ndc,sun.radii_enabled.y);
  visibility=mix(visibility,outer,has_near?fade:1.0);
 }
 return mix(1.0,visibility,sun.focus_strength.w);
}

// CX selects one cluster for the quad, including when its corners cross the
// viewport or the near plane. Range and hemisphere lighting stay per corner.
vec3 shade_particle(vec3 point,vec3 normal,vec3 center){
 float ndl=clamp(dot(normal,lighting.direction_count.xyz),0.0,1.0);
 vec3 light=lighting.ambient_enabled.rgb*mix(0.15,1.0,ndl);
 if(ndl>0.0)light+=lighting.diffuse.xyz*(ndl*particle_sun_visibility(point));
 uint words=(uint(lighting.direction_count.w)+31u)/32u;
 if(words==0u)return light;
 vec4 world_center=vec4(center,1.0);
 vec4 view_center=vec4(dot(params.view_rows[0],world_center),dot(params.view_rows[1],world_center),dot(params.view_rows[2],world_center),1.0);
 uint start=light_cell(params.projection*view_center,-view_center.z)*words;
 for(uint word=0u;word<words;++word){
  uint mask=grid.masks[start+word];
  while(mask!=0u){
   uint bit=uint(findLSB(mask));
   light+=point_light(word*32u+bit,point,normal);
   mask&=mask-1u;
  }
 }
 return light;
}

void main(){
 uint vertex=uint(gl_VertexIndex)+params.draw.x;
 uint corner=vertex%6u;
 Particle part=records[indices[vertex/6u]];
 bool near_end=corner==0u||corner==1u||corner==4u;
 bool right=corner==0u||corner==2u||corner==3u;
 uvec4 endpoint=near_end?part.near_color:part.far_color;
 precise vec3 point=uintBitsToFloat(endpoint.xyz)+(right?part.right_softness.xyz:-part.right_softness.xyz);
 point=point+(near_end?part.up_type.xyz:-part.up_type.xyz);
 vec4 world=vec4(point,1.0);
 vec4 view=vec4(dot(params.view_rows[0],world),dot(params.view_rows[1],world),dot(params.view_rows[2],world),1.0);
 gl_Position=params.projection*view;
 view_depth=-view.z;
 tint=unpackUnorm4x8(endpoint.w);
 uv=vec2(right?part.uv_rect.y:part.uv_rect.x,near_end?part.uv_rect.w:part.uv_rect.z);
 fog_world=point;
 fog_eye=uintBitsToFloat(params.draw.yzw);
 softness=part.right_softness.w;
 particle_light=vec3(1.0);
 if(lit&&lighting.ambient_enabled.w>0.0){
  vec3 horiz=safe_normalize(part.right_softness.xyz);
  vec3 vert=safe_normalize(part.up_type.xyz);
  vec3 normal=safe_normalize((right?horiz:-horiz)+(near_end?vert:-vert)+safe_normalize(fog_eye-part.center.xyz));
  particle_light=shade_particle(point,normal,part.center.xyz);
 }
}
)glsl";
}
