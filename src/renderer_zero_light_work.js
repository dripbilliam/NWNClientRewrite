// EXPERIMENT: retain the authored light list and Three's exact shading for
// every contributing point light. Skip only finite, provably zero terms.
// No nearest-N truncation, different falloff, light packet or CPU bounds scan.
export function conservativePointLightWork(source){
 const marker='\t\tpointLight = pointLights[ i ];',start=source.indexOf(marker),end=source.indexOf('\n\t}\n\t#pragma unroll_loop_end',start);
 if(start<0||end<0||source.indexOf(marker,start+marker.length)>=0)throw Error('Point lighting loop changed');
 const body=source.slice(start+marker.length,end);
 const helper=`
uniform int nwnSkipZeroLightWork;
bool nwnPointHasWork(PointLight light,vec3 position){
 if(nwnSkipZeroLightWork==0)return true;
 vec3 delta=light.position-position;
 // Invalid inputs retain Three's original behavior instead of hiding NaNs.
 if(any(isnan(delta))||any(isinf(delta))||any(isnan(light.color))||any(isinf(light.color))||isnan(light.distance)||isinf(light.distance)||isnan(light.decay)||isinf(light.decay))return true;
 // Negative decay selects model_light's infinite legacy falloff, regardless
 // of the positive authored radius carried in distance.
 if(light.decay>=0.0&&light.distance>0.0&&any(greaterThan(abs(delta),vec3(light.distance*1.0001+0.0001))))return false;
 // Avoid the undefined normalization of a zero/overflowed vector. Neutral
 // padding elsewhere has exactly zero color and contributes exactly zero.
 float squared=dot(delta,delta);
 if(all(equal(light.color,vec3(0.0)))&&squared>0.0000000001&&!isinf(squared))return false;
 return true;
}
`;
 // lights_fragment_begin occurs inside main; the helper belongs with the
 // PointLight declaration in lights_pars_begin (returned separately).
 return{fragment:source.slice(0,start)+marker+'\n\t\tif(nwnPointHasWork(pointLight,geometryPosition)){'+body+'\n\t\t}'+source.slice(end),helper};
}

export class RendererZeroLightWork{
 constructor(renderer,ShaderChunk){
  this.renderer=renderer;this.chunk=ShaderChunk;this.beforeFragment=ShaderChunk.lights_fragment_begin;this.beforePars=ShaderChunk.lights_pars_begin;
  if(this.beforeFragment.includes('nwnPointHasWork'))throw Error('Zero-light experiment is already installed');
  const transformed=conservativePointLightWork(this.beforeFragment),site='uniform PointLight pointLights[ NUM_POINT_LIGHTS ];';
  if(!this.beforePars.includes(site))throw Error('Point light declaration changed');
  this.fragment=transformed.fragment;this.pars=this.beforePars.replace(site,site+'\n'+transformed.helper);
  ShaderChunk.lights_fragment_begin=this.fragment;ShaderChunk.lights_pars_begin=this.pars;
  this.enabled=false;this.disposed=false;this.programs=new Map();this.stats={uploads:0};const owner=this;this.state=renderer.state;this.beforeUse=renderer.state.useProgram;
  this.hook=function(program){
   const changed=owner.beforeUse.call(this,program);if(owner.disposed)return changed;let record=owner.programs.get(program);
   if(!record){const p=renderer.info.programs.find(p=>p.program===program),uniforms=p?.getUniforms();if(!uniforms)return changed;record={uniforms,owned:Boolean(uniforms.map.nwnSkipZeroLightWork),enabled:undefined};owner.programs.set(program,record);}
   if(record.owned&&record.enabled!==owner.enabled){record.uniforms.setValue(renderer.getContext(),'nwnSkipZeroLightWork',Number(owner.enabled));record.enabled=owner.enabled;owner.stats.uploads++;}
   return changed;
  };renderer.state.useProgram=this.hook;
  this.lost=()=>{if(this.state.useProgram===this.hook)this.state.useProgram=this.beforeUse;this.programs.clear();};
  this.restored=()=>{this.state=renderer.state;this.beforeUse=this.state.useProgram;this.state.useProgram=this.hook;};
  renderer.domElement?.addEventListener('webglcontextlost',this.lost);renderer.domElement?.addEventListener('webglcontextrestored',this.restored);
 }
 snapshot(){const live=new Set(this.renderer.info.programs.map(p=>p.program));for(const program of this.programs.keys())if(!live.has(program))this.programs.delete(program);return{enabled:this.enabled,programs:this.programs.size,...this.stats};}
 dispose(){
  if(this.disposed)return;this.disposed=true;
  const gl=this.renderer.getContext(),state=this.renderer.state;
  try{
   // Already-compiled guarded programs may survive this experimental owner.
   // Return them to the ordinary path before releasing the program hook.
   if(!gl.isContextLost()){
    const previous=gl.getParameter(gl.CURRENT_PROGRAM);
    try{for(const [program,record]of this.programs)if(record.owned&&record.enabled&&gl.isProgram(program)){this.beforeUse.call(state,program);record.uniforms.setValue(gl,'nwnSkipZeroLightWork',0);}}
    finally{this.beforeUse.call(state,previous);}
   }
  }finally{
   if(state.useProgram===this.hook)state.useProgram=this.beforeUse;
   if(this.chunk.lights_fragment_begin===this.fragment)this.chunk.lights_fragment_begin=this.beforeFragment;
   if(this.chunk.lights_pars_begin===this.pars)this.chunk.lights_pars_begin=this.beforePars;
   this.renderer.domElement?.removeEventListener('webglcontextlost',this.lost);this.renderer.domElement?.removeEventListener('webglcontextrestored',this.restored);this.programs.clear();
  }
 }
}
