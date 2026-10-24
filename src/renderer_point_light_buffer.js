import {Material,Object3D,ShaderChunk,Sphere,Vector3} from 'three';
import {batchRendererHook,isLocalRendererHook,rendererBatchHook} from './renderer_local_hooks.js';
const limit=128,mb=Material.prototype,ob=Object3D.prototype;
const maps=['map','alphaMap','lightMap','aoMap','emissiveMap','bumpMap','normalMap','displacementMap','specularMap','envMap'];
function knownCompile(hook){const seen=new Set();while(hook!==mb.onBeforeCompile){const description=rendererBatchHook(hook);if(!description||!['keyhole','target-preview'].includes(description.kind)||seen.has(description.token))return false;seen.add(description.token);hook=description.before;}return true;}
export function pointBufferShader(shader,{compact=true}={}){
 const guard='NUM_POINT_LIGHTS > 0 && NUM_POINT_LIGHTS <= 128',declaration='uniform PointLight pointLights[ NUM_POINT_LIGHTS ];';
 if(!ShaderChunk.lights_pars_begin.includes(declaration))throw Error('Point light declaration changed');
 const block=`#if ${guard}\nlayout(std140) uniform NwnPointLights { vec4 nwnPointPositionDistance[128]; vec4 nwnPointColorDecay[128]; };\nuniform int nwnObjectPointCount;\nuniform int nwnObjectPointIndices[128];\nPointLight nwnReadPoint(int index){PointLight light;light.position=nwnPointPositionDistance[index].xyz;light.distance=nwnPointPositionDistance[index].w;light.color=nwnPointColorDecay[index].xyz;light.decay=nwnPointColorDecay[index].w;return light;}\n#else\n${declaration}\n#endif`;
 const original=ShaderChunk.lights_fragment_begin,match=original.match(/\t#pragma unroll_loop_start\s+\tfor \( int i = 0; i < NUM_POINT_LIGHTS; i \+\+ \) \{[\s\S]*?\t#pragma unroll_loop_end/);
 if(!match)throw Error('Point light loop changed');
 const shadow=match[0].replace('i < NUM_POINT_LIGHTS','i < NUM_POINT_LIGHT_SHADOWS').replace('pointLight = pointLights[ i ];','pointLight = nwnReadPoint( UNROLLED_LOOP_INDEX );');
 const localLoop=`for(int nwnLight=0;nwnLight<nwnObjectPointCount;nwnLight++){pointLight=nwnReadPoint(nwnObjectPointIndices[nwnLight]);getPointLightInfo(pointLight,geometryPosition,directLight);RE_Direct(directLight,geometryPosition,geometryNormal,geometryViewDir,geometryClearcoatNormal,material,reflectedLight);}`,globalLoop=match[0].replace('pointLight = pointLights[ i ];','pointLight = nwnReadPoint( UNROLLED_LOOP_INDEX );');
 shader.fragmentShader=shader.fragmentShader.replace('#include <lights_pars_begin>',ShaderChunk.lights_pars_begin.replace(declaration,block)).replace('#include <lights_fragment_begin>',original.replace(match[0],`#if ${guard}\n${compact?shadow+'\n'+localLoop:globalLoop}\n#else\n${match[0]}\n#endif`));
 shader.uniforms.nwnObjectPointCount={value:0};shader.uniforms.nwnObjectPointIndices={value:new Int32Array(limit)};
}

// Conservative rigid bounds. A Frobenius norm also bounds parent-induced shear.
// Dynamic/deformed producers stay unculled; lights with infinite range remain.
export function packPointLights(lights,data,states){
 for(let i=0;i<lights.length;i++){const light=lights[i],p=light.position,c=light.color,a=i*4,b=limit*4+a;data[a]=p.x;data[a+1]=p.y;data[a+2]=p.z;data[a+3]=light.distance;data[b]=c.r;data[b+1]=c.g;data[b+2]=c.b;data[b+3]=light.decay;
  const finite=Number.isFinite(data[a])&&Number.isFinite(data[a+1])&&Number.isFinite(data[a+2])&&Number.isFinite(data[a+3])&&Number.isFinite(data[b])&&Number.isFinite(data[b+1])&&Number.isFinite(data[b+2])&&Number.isFinite(data[b+3]);states[i]=finite?(data[b]===0&&data[b+1]===0&&data[b+2]===0?1:2):0;
 }
}
export function pointLightIndices(lights,shadowCount,object,material,indices,sphere=new Sphere(),packed=null){
 let bounded=object.isMesh&&!object.isSkinnedMesh&&!object.isInstancedMesh&&!object.isBatchedMesh&&!object.userData.animationOwnedGeometry&&!material.displacementMap;
 const geometry=object.geometry,p=geometry?.attributes.position;
 bounded=bounded&&p&&p.version===0&&!Object.values(geometry.morphAttributes).some(attributes=>attributes.length);
 if(bounded){if(!geometry.boundingSphere)geometry.computeBoundingSphere();const local=geometry.boundingSphere,m=object.modelViewMatrix.elements;
  bounded=local&&Number.isFinite(local.radius)&&local.radius>=0;
  if(bounded){sphere.center.copy(local.center).applyMatrix4(object.modelViewMatrix);sphere.radius=local.radius*Math.sqrt(m[0]**2+m[1]**2+m[2]**2+m[4]**2+m[5]**2+m[6]**2+m[8]**2+m[9]**2+m[10]**2);bounded=Number.isFinite(sphere.radius)&&Number.isFinite(sphere.center.x)&&Number.isFinite(sphere.center.y)&&Number.isFinite(sphere.center.z);}
 }
 let count=0;
 const baseEpsilon=1+Math.abs(sphere.center.x)+Math.abs(sphere.center.y)+Math.abs(sphere.center.z)+sphere.radius;
 for(let i=shadowCount;i<lights.length;i++){const light=lights[i],color=light.color,position=light.position,a=i*4,x=packed?packed.data[a]:Math.fround(position.x),y=packed?packed.data[a+1]:Math.fround(position.y),z=packed?packed.data[a+2]:Math.fround(position.z),distance=packed?packed.data[a+3]:Math.fround(light.distance);
  const finite=packed?packed.states[i]!==0:Number.isFinite(Math.fround(color.r))&&Number.isFinite(Math.fround(color.g))&&Number.isFinite(Math.fround(color.b))&&Number.isFinite(x)&&Number.isFinite(y)&&Number.isFinite(z)&&Number.isFinite(Math.fround(light.decay))&&Number.isFinite(distance);
  if(packed?packed.states[i]===1:finite&&color.r===0&&color.g===0&&color.b===0)continue;
  // model_light's negative-decay marker selects an infinite-support legacy
  // curve. Its authored distance is not a cutoff, even for rigid receivers.
  const decay=packed?packed.data[limit*4+a+3]:Math.fround(light.decay);
  if(bounded&&finite&&decay>=0&&distance>0){const epsilon=1e-4*(baseEpsilon+Math.abs(x)+Math.abs(y)+Math.abs(z)+distance),reach=sphere.radius+distance+epsilon,dx=sphere.center.x-x,dy=sphere.center.y-y,dz=sphere.center.z-z;if(dx*dx+dy*dy+dz*dz>reach*reach)continue;}
  indices[count++]=i;
 }return count;
}

// EXPERIMENT: never enabled by the production client. Exact Three shadow slots
// stay unrolled (sampler indices must be constant). Only nonshadow lights use a
// compact per-object list. One UBO per pass replaces repeated point-light field
// uploads, without adding a texture unit or changing source light admission.
export class RendererPointLightBuffer{
 constructor(renderer,{enabled=false,compact=true}={}){
  this.renderer=renderer;this.gl=renderer.getContext();this.enabled=enabled;this.compact=compact;this.bindings=new Map();this.programs=new WeakMap();this.data=new Float32Array(limit*8);this.packed={data:this.data,states:new Uint8Array(limit)};this.indices=new Int32Array(limit);this.indexViews=Array.from({length:limit+1},(_,count)=>this.indices.subarray(0,Math.max(1,count)));this.sphere=new Sphere(new Vector3());this.running=false;this.buffer=null;this.stats={draws:0,uploads:0,considered:0,selected:0};
  const gl=this.gl;this.supported=typeof gl.uniformBlockBinding==='function'&&gl.getParameter(gl.MAX_UNIFORM_BLOCK_SIZE)>=this.data.byteLength&&(!compact||renderer.capabilities.maxFragmentUniforms>=512);this.binding=this.supported?gl.getParameter(gl.MAX_UNIFORM_BUFFER_BINDINGS)-1:0;
  this.lost=()=>{this.buffer=null;this.programs=new WeakMap();};renderer.domElement?.addEventListener('webglcontextlost',this.lost);
 }
 bind(scene){if(!this.enabled||!this.supported)return;scene.traverse(object=>{for(const material of Array.isArray(object.material)?object.material:object.material?[object.material]:[]){
  if(this.bindings.has(material)||!material.isMeshLambertMaterial)continue;
  const inherited=rendererBatchHook(material.onBeforeCompile),inheritedKey=rendererBatchHook(material.customProgramCacheKey),before=inherited?.kind==='point-light-buffer'&&inherited.token===this?inherited.before:material.onBeforeCompile,key=inheritedKey?.kind==='point-light-buffer-key'&&inheritedKey.token===this?inheritedKey.before:material.customProgramCacheKey,owner=this;
  if(!knownCompile(before))continue;
  const hook=batchRendererHook(function(shader,renderer){before.call(this,shader,renderer);pointBufferShader(shader,{compact:owner.compact});},{kind:'point-light-buffer',token:this,before});
  const cache=batchRendererHook(function(){return key.call(this)+'|nwn-point-buffer-v2-'+owner.compact;},{kind:'point-light-buffer-key',token:this,before:key});
  const dispose=()=>{if(material.onBeforeCompile===hook){material.onBeforeCompile=before;material.customProgramCacheKey=key;}material.removeEventListener('dispose',dispose);owner.bindings.delete(material);};
  this.bindings.set(material,{before,key,hook,cache,dispose});material.onBeforeCompile=hook;material.customProgramCacheKey=cache;material.needsUpdate=true;material.addEventListener('dispose',dispose);
 }});}
 compatible(scene,camera){let safe=!scene.overrideMaterial&&!camera.isArrayCamera&&!this.renderer.xr?.enabled&&scene.onBeforeRender===ob.onBeforeRender&&scene.onAfterRender===ob.onAfterRender;
  scene.traverseVisible(object=>{if(object.onAfterRender!==ob.onAfterRender||object.onBeforeRender!==ob.onBeforeRender&&!isLocalRendererHook(object.onBeforeRender))safe=false;
   for(const material of Array.isArray(object.material)?object.material:object.material?[object.material]:[]){if(material.onBeforeRender!==mb.onBeforeRender||material.uniformsGroups?.length)safe=false;for(const key of maps)if(material[key]?.onUpdate)safe=false;}
  });return safe;
 }
 plain(draw){const restored=[];for(const [material,record]of this.bindings)if(material.onBeforeCompile===record.hook){material.onBeforeCompile=record.before;material.customProgramCacheKey=record.key;material.needsUpdate=true;restored.push([material,record]);}
  try{return draw();}finally{for(const [material,record]of restored){material.onBeforeCompile=record.hook;material.customProgramCacheKey=record.cache;material.needsUpdate=true;}}
 }
 upload(lights){const gl=this.gl;if(!this.buffer){this.buffer=gl.createBuffer();if(!this.buffer)throw Error('Point-light buffer allocation failed');gl.bindBuffer(gl.UNIFORM_BUFFER,this.buffer);gl.bufferData(gl.UNIFORM_BUFFER,this.data.byteLength,gl.DYNAMIC_DRAW);}
  packPointLights(lights,this.data,this.packed.states);
  gl.bindBuffer(gl.UNIFORM_BUFFER,this.buffer);gl.bufferSubData(gl.UNIFORM_BUFFER,0,this.data);gl.bindBufferBase(gl.UNIFORM_BUFFER,this.binding,this.buffer);this.stats.uploads++;this.lightSource=lights;
 }
 apply(material,object,program){const gl=this.gl,properties=this.renderer.properties.get(material),uniforms=properties.uniforms,lights=uniforms?.pointLights?.value;if(!lights?.length||lights.length>limit)return;
  let block=this.programs.get(program);if(block===undefined){block=gl.getUniformBlockIndex(program.program,'NwnPointLights');this.programs.set(program,block);if(block!==gl.INVALID_INDEX)gl.uniformBlockBinding(program.program,block,this.binding);}if(block===gl.INVALID_INDEX)return;
  if(this.lightSource!==lights)this.upload(lights);
  if(!this.compact){this.stats.draws++;this.stats.considered+=lights.length;this.stats.selected+=lights.length;return;}
  const shadows=uniforms.pointLightShadows?.value.length??0,count=pointLightIndices(lights,shadows,object,material,this.indices,this.sphere,this.packed),gpu=program.getUniforms(),indices=this.indexViews[count];
  // Returning from an ordinary fallback can reuse an existing program while
  // Three still holds the previous variant's uniform dictionary.
  const countUniform=uniforms.nwnObjectPointCount??={value:0},indicesUniform=uniforms.nwnObjectPointIndices??={value:indices};countUniform.value=count;indicesUniform.value=indices;countUniform.needsUpdate=indicesUniform.needsUpdate=false;
  gpu.setValue(gl,'nwnObjectPointCount',count);gpu.setValue(gl,'nwnObjectPointIndices',indices);this.stats.draws++;this.stats.considered+=Math.max(0,lights.length-shadows);this.stats.selected+=count;
 }
 render(scene,camera,draw=()=>this.renderer.render(scene,camera)){
  this.stats={draws:0,uploads:0,considered:0,selected:0};if(!this.enabled||!this.supported)return draw();this.bind(scene);
  if(this.running||!this.compatible(scene,camera)){this.stats.fallback=true;return this.plain(draw);}
  const renderer=this.renderer,gl=this.gl,before=renderer.renderBufferDirect,use=renderer.state.useProgram,indexed=gl.getIndexedParameter(gl.UNIFORM_BUFFER_BINDING,this.binding),generic=gl.getParameter(gl.UNIFORM_BUFFER_BINDING);let current=null;this.running=true;this.lightSource=null;
  renderer.renderBufferDirect=(c,s,g,m,o,group)=>{const previous=current;current=s===scene&&c===camera&&this.bindings.has(m)?{material:m,object:o}:null;try{return before.call(renderer,c,s,g,m,o,group);}finally{current=previous;}};
  renderer.state.useProgram=function(program){const changed=use.call(this,program);if(current){const compiled=renderer.properties.get(current.material).currentProgram;if(compiled?.program===program)owner.apply(current.material,current.object,compiled);}return changed;};const owner=this;
  try{return draw();}finally{renderer.renderBufferDirect=before;renderer.state.useProgram=use;gl.bindBufferBase(gl.UNIFORM_BUFFER,this.binding,indexed);gl.bindBuffer(gl.UNIFORM_BUFFER,generic);this.running=false;this.lightSource=null;}
 }
 reset(){for(const [material,record]of [...this.bindings]){record.dispose();material.needsUpdate=true;}if(this.buffer&&this.gl.isBuffer(this.buffer))this.gl.deleteBuffer(this.buffer);this.buffer=null;this.programs=new WeakMap();this.lightSource=null;this.stats={draws:0,uploads:0,considered:0,selected:0};}
 snapshot(){return{...this.stats,enabled:this.enabled,compact:this.compact,supported:this.supported,materials:this.bindings.size,bufferBytes:this.buffer?this.data.byteLength:0};}
 dispose(){this.reset();this.renderer.domElement?.removeEventListener('webglcontextlost',this.lost);}
}
