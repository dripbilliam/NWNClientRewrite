import {Material,Object3D,ShaderChunk,Sphere} from 'three';
import {batchRendererHook,isLocalRendererHook,rendererBatchHook} from './renderer_local_hooks.js';
import {pointLightIndices,packPointLights} from './renderer_point_light_buffer.js';
const mb=Material.prototype,ob=Object3D.prototype;
const maps=['map','alphaMap','lightMap','aoMap','emissiveMap','bumpMap','normalMap','displacementMap','specularMap','envMap'];
function knownCompile(hook){const seen=new Set();while(hook!==mb.onBeforeCompile){const description=rendererBatchHook(hook);if(!description||!['keyhole','target-preview'].includes(description.kind)||seen.has(description.token))return false;seen.add(description.token);hook=description.before;}return true;}
export function pointPacketShader(shader,capacity){
 const chunk=ShaderChunk.lights_fragment_begin,match=chunk.match(/\t#pragma unroll_loop_start\s+\tfor \( int i = 0; i < NUM_POINT_LIGHTS; i \+\+ \) \{[\s\S]*?\t#pragma unroll_loop_end/);if(!match)throw Error('Point light loop changed');
 const shadow=match[0].replace('i < NUM_POINT_LIGHTS','i < NUM_POINT_LIGHT_SHADOWS');
 const packet=`\n#pragma unroll_loop_start\nfor ( int i = 0; i < ${capacity}; i ++ ) {\nif(UNROLLED_LOOP_INDEX < nwnPacketCount){\npointLight.position=nwnPacketPositions[ i ].xyz;pointLight.distance=nwnPacketPositions[ i ].w;pointLight.color=nwnPacketColors[ i ].rgb;pointLight.decay=nwnPacketColors[ i ].w;getPointLightInfo(pointLight,geometryPosition,directLight);RE_Direct(directLight,geometryPosition,geometryNormal,geometryViewDir,geometryClearcoatNormal,material,reflectedLight);\n}\n}\n#pragma unroll_loop_end\n`;
 const body=`${shadow}\n${packet}`;
 shader.fragmentShader=`uniform int nwnPacketCount;uniform vec4 nwnPacketPositions[${capacity}];uniform vec4 nwnPacketColors[${capacity}];\n`+shader.fragmentShader.replace('#include <lights_fragment_begin>',chunk.replace(match[0],body));
 shader.uniforms.nwnPacketCount={value:0};shader.uniforms.nwnPacketPositions={value:new Float32Array(capacity*4)};shader.uniforms.nwnPacketColors={value:new Float32Array(capacity*4)};
}
// EXPERIMENT: ordinary Three light uniforms and shadow sampler order remain
// intact. Two small vec4 arrays use constant indices in the nonshadow path.
// No UBO lookup, indirect per-fragment light index or source material clone.
export class RendererPointLightPackets{
 constructor(renderer,{enabled=false,capacity=16}={}){
  if(![8,16,32,64].includes(capacity))throw Error('Invalid light packet capacity');Object.assign(this,{renderer,enabled,capacity});this.gl=renderer.getContext();this.supported=renderer.capabilities.maxFragmentUniforms>=1024;this.bindings=new Map();this.indices=new Int32Array(128);this.positions=new Float32Array(capacity*4);this.colors=new Float32Array(capacity*4);this.packed={data:new Float32Array(128*8),states:new Uint8Array(128)};this.sphere=new Sphere();this.running=false;this.stats={};
 }
 bind(scene){if(!this.enabled||!this.supported)return;scene.traverse(object=>{for(const material of Array.isArray(object.material)?object.material:object.material?[object.material]:[]){
  if(this.bindings.has(material)||!material.isMeshLambertMaterial)continue;
  const inherited=rendererBatchHook(material.onBeforeCompile),inheritedKey=rendererBatchHook(material.customProgramCacheKey),before=inherited?.kind==='point-light-packets'&&inherited.token===this?inherited.before:material.onBeforeCompile,key=inheritedKey?.kind==='point-light-packets-key'&&inheritedKey.token===this?inheritedKey.before:material.customProgramCacheKey,owner=this;if(!knownCompile(before))continue;
  const record={before,key,packet:false};
  const hook=batchRendererHook(function(shader,renderer){before.call(this,shader,renderer);if(record.packet)pointPacketShader(shader,owner.capacity);},{kind:'point-light-packets',token:this,before});
  const cache=batchRendererHook(function(){return key.call(this)+(record.packet?'|nwn-point-packets-v2-'+owner.capacity:'');},{kind:'point-light-packets-key',token:this,before:key});
  const dispose=()=>{if(material.onBeforeCompile===hook){material.onBeforeCompile=before;material.customProgramCacheKey=key;}material.removeEventListener('dispose',dispose);owner.bindings.delete(material);};
  Object.assign(record,{hook,cache,dispose});this.bindings.set(material,record);material.onBeforeCompile=hook;material.customProgramCacheKey=cache;material.needsUpdate=true;material.addEventListener('dispose',dispose);
 }});}
 compatible(scene,camera){let safe=!scene.overrideMaterial&&!camera.isArrayCamera&&!this.renderer.xr?.enabled&&scene.onBeforeRender===ob.onBeforeRender&&scene.onAfterRender===ob.onAfterRender;
  const materials=new Set();scene.traverseVisible(object=>{if(object.onAfterRender!==ob.onAfterRender||object.onBeforeRender!==ob.onBeforeRender&&!isLocalRendererHook(object.onBeforeRender))safe=false;
   for(const material of Array.isArray(object.material)?object.material:object.material?[object.material]:[]){if(materials.has(material))continue;materials.add(material);if(material.onBeforeRender!==mb.onBeforeRender||material.uniformsGroups?.length)safe=false;for(const key of maps)if(material[key]?.onUpdate)safe=false;for(const uniform of Object.values(material.uniforms??{})){const value=uniform?.value;if(value?.isTexture&&value.onUpdate||Array.isArray(value)&&value.some(texture=>texture?.isTexture&&texture.onUpdate))safe=false;}}
  });return safe;
 }
 plain(draw){const restored=[];for(const [material,record]of this.bindings)if(material.onBeforeCompile===record.hook){material.onBeforeCompile=record.before;material.customProgramCacheKey=record.key;material.needsUpdate=true;restored.push([material,record]);}try{return draw();}finally{for(const [material,record]of restored){material.onBeforeCompile=record.hook;material.customProgramCacheKey=record.cache;material.needsUpdate=true;}}}
 apply(material,object,program,current){
  const uniforms=this.renderer.properties.get(material).uniforms,lights=uniforms?.pointLights?.value;if(!uniforms||!lights)return;
  // Three can return a cached packet program after ordinary fallback while
  // retaining that fallback's uniform dictionary. Restore our dictionary
  // entries too; the actual GPU values are always uploaded explicitly below.
  const shadows=uniforms.pointLightShadows?.value.length??0;
  if(this.lightSource!==lights||this.shadowCount!==shadows){
   if(this.lightSource)this.packetCache=new WeakMap();
   this.lightSource=lights;this.shadowCount=shadows;this.active=[];for(let i=shadows;i<lights.length;i++){const light=lights[i],c=light.color;if(c.r===0&&c.g===0&&c.b===0&&Number.isFinite(light.distance)&&Number.isFinite(light.decay)&&[light.position.x,light.position.y,light.position.z].every(Number.isFinite))continue;this.active.push(light);}packPointLights(this.active,this.packed.data,this.packed.states);
  }
  const count=current.count,overflow=!current.packet,gpu=program.getUniforms(),gl=this.gl;
  this.stats.draws++;this.stats.considered+=lights.length-shadows;this.stats.selected+=overflow?lights.length-shadows:count;if(overflow){this.stats.overflowDraws++;return;}
  uniforms.nwnPacketCount??={value:0};uniforms.nwnPacketPositions??={value:this.positions};uniforms.nwnPacketColors??={value:this.colors};uniforms.nwnPacketCount.value=count;uniforms.nwnPacketCount.needsUpdate=false;gpu.setValue(gl,'nwnPacketCount',count);
  uniforms.nwnPacketPositions.needsUpdate=uniforms.nwnPacketColors.needsUpdate=false;
  if(!overflow){const previous=this.packetCache.get(program.program);let same=previous?.length===count;if(same)for(let i=0;i<count;i++)if(previous[i]!==this.indices[i]){same=false;break;}
   if(!same){this.positions.fill(0);this.colors.fill(0);for(let i=0;i<count;i++){const source=this.indices[i]*4,destination=i*4;for(let c=0;c<4;c++){this.positions[destination+c]=this.packed.data[source+c];this.colors[destination+c]=this.packed.data[512+source+c];}}
    uniforms.nwnPacketPositions.value=this.positions;uniforms.nwnPacketColors.value=this.colors;gpu.setValue(gl,'nwnPacketPositions',this.positions);gpu.setValue(gl,'nwnPacketColors',this.colors);this.packetCache.set(program.program,this.indices.slice(0,count));this.stats.uploadedPackets++;
   }else this.stats.reusedPackets++;this.stats.packetDraws++;
  }
 }
 render(scene,camera,draw=()=>this.renderer.render(scene,camera)){
  this.stats={draws:0,packetDraws:0,overflowDraws:0,considered:0,selected:0,uploadedPackets:0,reusedPackets:0};if(!this.enabled||!this.supported)return draw();this.bind(scene);
  if(this.running||!this.compatible(scene,camera)){this.stats.fallback=true;return this.plain(draw);}
  const renderer=this.renderer,before=renderer.renderBufferDirect,use=renderer.state.useProgram,owner=this;let current=null;this.running=true;this.lightSource=null;this.packetCache=new WeakMap();
  renderer.renderBufferDirect=(c,s,g,m,o,group)=>{const previous=current,record=s===scene&&c===camera?this.bindings.get(m):null;current=null;
   if(record){const count=this.lightSource&&this.lightSource.length<=128?pointLightIndices(this.active,0,o,m,this.indices,this.sphere,this.packed):-1,packet=count>=0&&count<=this.capacity;if(record.packet!==packet){record.packet=packet;m.needsUpdate=true;}current={material:m,object:o,count,packet};}
   try{return before.call(renderer,c,s,g,m,o,group);}finally{current=previous;}};
  renderer.state.useProgram=function(program){const changed=use.call(this,program);if(current){const compiled=renderer.properties.get(current.material).currentProgram;if(compiled?.program===program)owner.apply(current.material,current.object,compiled,current);}else owner.packetCache.delete(program);return changed;};
  try{return draw();}finally{renderer.renderBufferDirect=before;renderer.state.useProgram=use;this.running=false;this.lightSource=null;this.active=null;}
 }
 reset(){for(const [material,record]of [...this.bindings]){record.dispose();material.needsUpdate=true;}this.lightSource=null;this.active=null;this.stats={};}
 snapshot(){return{...this.stats,enabled:this.enabled,supported:this.supported,capacity:this.capacity,materials:this.bindings.size,bufferBytes:0};}
 dispose(){this.reset();}
}
