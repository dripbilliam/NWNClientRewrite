namespace cx_particle {
constexpr int grid_x=32,grid_y=18,grid_z=24,grid_group=64;
constexpr int grid_cells=grid_x*grid_y*grid_z;
constexpr size_t light_header_floats=12;
constexpr size_t light_record_floats=12;

constexpr const char* light_rows=R"glsl(
struct PointLight {
 vec4 position_range;
 vec4 color_ambient;
 vec4 attenuation;
};
layout(set=LIGHT_SET,binding=LIGHT_BINDING,std430) readonly buffer ParticleLights {
 vec4 ambient_enabled;
 vec4 diffuse;
 vec4 direction_count;
 PointLight lights[];
} lighting;
const ivec3 light_grid=ivec3(GRID_X,GRID_Y,GRID_Z);
const uint light_cells=uint(GRID_X*GRID_Y*GRID_Z);
)glsl";

std::string light_shader_prefix(int set,int binding){
 return std::string("#version 450\n#define LIGHT_SET ")+std::to_string(set)+
  "\n#define LIGHT_BINDING "+std::to_string(binding)+"\n#define GRID_X "+std::to_string(grid_x)+
  "\n#define GRID_Y "+std::to_string(grid_y)+"\n#define GRID_Z "+std::to_string(grid_z)+
  "\n#define GRID_GROUP "+std::to_string(grid_group)+"\n"+light_rows;
}

constexpr size_t grid_bytes(size_t light_count){
 // The final cell holds the complete list for a corner outside the frustum.
 return 4*sizeof(float)+(grid_cells+1)*((light_count+31)/32)*sizeof(uint32_t);
}

constexpr const char* grid_shader=R"glsl(
layout(local_size_x=GRID_GROUP) in;
layout(set=0,binding=1,std430) writeonly buffer LightGrid {
 vec4 depth;
 uint masks[];
} grid;
layout(push_constant,std430) uniform Params {
 mat4 projection;
 vec4 view_rows[3];
 vec4 depth;
} params;
shared vec4 spheres[GRID_GROUP];

vec2 unproject_xy(vec2 ndc,float depth){
 vec4 center=params.projection[2]*(-depth)+params.projection[3];
 return (ndc*center.w-center.xy)/vec2(params.projection[0].x,params.projection[1].y);
}

void main(){
 uint cell=gl_GlobalInvocationID.x;
 uint lane=gl_LocalInvocationIndex;
 uint count=uint(lighting.direction_count.w);
 uint words=(count+31u)/32u;
 if(cell==0u) grid.depth=params.depth;
 // A selected lamp stays eligible at the frustum boundary, where clipped
 // geometry still interpolates the shading of its outside corners.
 if(cell<words){
  uint bits=min(count-cell*32u,32u);
  grid.masks[light_cells*words+cell]=bits==32u?0xffffffffu:(1u<<bits)-1u;
 }
 if(params.depth.x<=0.0)return;
 ivec3 xyz=ivec3(int(cell)%GRID_X,(int(cell)/GRID_X)%GRID_Y,int(cell)/(GRID_X*GRID_Y));
 vec2 tile=2.0/vec2(light_grid.xy);
 vec2 low_ndc=-1.0+vec2(xyz.xy)*tile;
 vec2 high_ndc=low_ndc+tile;
 float low_depth=params.depth.x*exp(float(xyz.z)*params.depth.z);
 float high_depth=params.depth.x*exp(float(xyz.z+1)*params.depth.z);
 vec2 a=unproject_xy(low_ndc,low_depth),b=unproject_xy(high_ndc,low_depth);
 vec2 c=unproject_xy(low_ndc,high_depth),d=unproject_xy(high_ndc,high_depth);
 vec3 lo=vec3(min(min(a,b),min(c,d)),-high_depth);
 vec3 hi=vec3(max(max(a,b),max(c,d)),-low_depth);
 vec3 slack=vec3(0.001)+0.0001*max(abs(lo),abs(hi));
 lo-=slack;
 hi+=slack;
 for(uint base=0u;base<count;base+=GRID_GROUP){
  uint light=base+lane;
  if(light<count){
   vec4 sphere=lighting.lights[light].position_range;
   vec4 p=vec4(sphere.xyz,1.0);
   spheres[lane]=vec4(dot(params.view_rows[0],p),dot(params.view_rows[1],p),dot(params.view_rows[2],p),sphere.w);
  }
  barrier();
  uint block=min(count-base,GRID_GROUP);
  for(uint first=0u;first<block;first+=32u){
   uint mask=0u;
   for(uint i=0u;i<min(block-first,32u);++i){
    vec4 sphere=spheres[first+i];
    vec3 delta=sphere.xyz-clamp(sphere.xyz,lo,hi);
    if(dot(delta,delta)<=sphere.w*sphere.w)mask|=1u<<i;
   }
   if(cell<light_cells)grid.masks[cell*words+(base+first)/32u]=mask;
  }
  barrier();
 }
}
)glsl";
}
