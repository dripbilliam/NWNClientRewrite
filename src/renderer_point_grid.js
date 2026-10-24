import {Material,ShaderChunk,Vector3,Vector4} from 'three';
import {buildPointLightGrid} from './point_light_grid.js';
import {batchRendererHook,isLocalRendererHook,localRendererHook} from './renderer_local_hooks.js';
const leases=new WeakMap(),owners=new WeakMap(),base=Material.prototype;
export function pointGridShader(source,words){
 if(!Number.isInteger(words)||words<4||words%4)throw Error('Invalid grid block size');
 const start=source.indexOf('\t#pragma unroll_loop_start\n\tfor ( int i = 0; i < NUM_POINT_LIGHTS; i ++ ) {'),end=source.indexOf('\n\t}\n\t#pragma unroll_loop_end',start);
 if(start<0||end<0)throw Error('Point light shader loop changed');
 const body=source.slice(source.indexOf('{',start)+1,end),shadowStart=body.indexOf('\t\t#if defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_POINT_LIGHT_SHADOWS )'),shadowEnd=body.indexOf('\t\t#endif',shadowStart);
 if(shadowStart<0||shadowEnd<0)throw Error('Point shadow shader block changed');
 const plain=(body.slice(0,shadowStart)+body.slice(shadowEnd+'\t\t#endif'.length)).replace('pointLights[ i ]','pointLights[ nwnGridIndex ]');
 const replacement=`
 #pragma unroll_loop_start
 for ( int i = 0; i < NUM_POINT_LIGHT_SHADOWS; i ++ ) {${body}
 }
 #pragma unroll_loop_end
 bool nwnGridValid = nwnPointGridEnabled == 1 && nwnPointGridLightCount == NUM_POINT_LIGHTS && nwnPointGridShadowCount == NUM_POINT_LIGHT_SHADOWS;
 ivec2 nwnGridCell = ivec2(floor((gl_FragCoord.xy - vec2(nwnPointGridViewport.xy)) / nwnPointGridTile));
 nwnGridValid = nwnGridValid && all(greaterThanEqual(nwnGridCell,ivec2(0))) && all(lessThan(nwnGridCell,nwnPointGridViewport.zw));
 uint nwnGridOffset = 0u; uint nwnGridCount = uint(NUM_POINT_LIGHTS - NUM_POINT_LIGHT_SHADOWS);
 if(nwnGridValid){uint cell=uint(nwnGridCell.y*nwnPointGridViewport.z+nwnGridCell.x);nwnGridOffset=nwnReadPointGrid(cell*2u);nwnGridCount=nwnReadPointGrid(cell*2u+1u);if(nwnGridCount==0xffffffffu)nwnGridValid=false;}
 if(!nwnGridValid)nwnGridCount=uint(NUM_POINT_LIGHTS - NUM_POINT_LIGHT_SHADOWS);
 for(int nwnGridK=0;nwnGridK<NUM_POINT_LIGHTS;nwnGridK++){
  if(uint(nwnGridK)>=nwnGridCount)break;
  int nwnGridIndex=nwnGridValid?int(nwnReadPointGrid(nwnGridOffset+uint(nwnGridK))):NUM_POINT_LIGHT_SHADOWS+nwnGridK;
 ${plain}
 }
`;
 const declarations=`
 #if NUM_POINT_LIGHTS > 0
 layout(std140) uniform NwnPointGrid { uvec4 nwnPointGridWords[${words/4}]; };
 uniform int nwnPointGridEnabled;
 uniform int nwnPointGridLightCount;
 uniform int nwnPointGridShadowCount;
 uniform ivec4 nwnPointGridViewport;
 uniform float nwnPointGridTile;
 uint nwnReadPointGrid(uint word){return nwnPointGridWords[int(word>>2u)][int(word&3u)];}
 #endif
`;
 return{fragment:source.slice(0,start)+replacement+source.slice(end+'\n\t}\n\t#pragma unroll_loop_end'.length),declarations};
}
export function pointGridMaskShader(source,words){
 const {declarations}=pointGridShader(source,words),head='\t#pragma unroll_loop_start\n\tfor ( int i = 0; i < NUM_POINT_LIGHTS; i ++ ) {',start=source.indexOf(head),tail='\n\t}\n\t#pragma unroll_loop_end',end=source.indexOf(tail,start),body=source.slice(start+head.length,end);
 const prefix=`
 bool nwnGridValid=nwnPointGridEnabled==1 && nwnPointGridLightCount==NUM_POINT_LIGHTS && nwnPointGridShadowCount==NUM_POINT_LIGHT_SHADOWS && NUM_POINT_LIGHTS<=128;
 ivec2 nwnGridCell=ivec2(floor((gl_FragCoord.xy-vec2(nwnPointGridViewport.xy))/nwnPointGridTile));
 nwnGridValid=nwnGridValid && all(greaterThanEqual(nwnGridCell,ivec2(0))) && all(lessThan(nwnGridCell,nwnPointGridViewport.zw));
 uvec4 nwnGridMask=uvec4(0u);if(nwnGridValid)nwnGridMask=nwnPointGridWords[nwnGridCell.y*nwnPointGridViewport.z+nwnGridCell.x];
`;
 const replacement=prefix+head+'\n if(UNROLLED_LOOP_INDEX < NUM_POINT_LIGHT_SHADOWS || !nwnGridValid || (nwnGridMask[(UNROLLED_LOOP_INDEX >> 5) & 3] & (1u << uint(UNROLLED_LOOP_INDEX & 31)))!=0u){'+body+'\n }'+tail;
 return{declarations,fragment:source.slice(0,start)+replacement+source.slice(end+tail.length)};
}

// EXPERIMENT ONLY. Per-owned-material shader hooks, one bounded UBO and original
// point-light uniforms/math/order. Shader/texture families without a supported
// hook retain ordinary lighting. Disabled, unsupported and overflow cells use
// the complete original tail. No material/texture sampler is consumed.
export class RendererPointGrid{
 constructor(renderer,{tileSize=96,maxBytes=65536,layout='mask'}={}){
  if(owners.has(renderer))throw Error('Point grid already owns this renderer');if(!Number.isInteger(tileSize)||tileSize<1||!Number.isFinite(maxBytes)||maxBytes<16||!['mask','indices'].includes(layout))throw Error('Invalid point grid capacity');this.layout=layout;this.renderer=renderer;this.gl=renderer.getContext();this.tileSize=tileSize;this.enabled=false;this.disposed=false;this.records=new Map();this.programs=new Map();this.position=new Vector3();this.viewport=new Vector4();this.active=null;this.running=false;this.stats={};
  const gl=this.gl;this.words=Math.floor(Math.min(maxBytes,gl.getParameter(gl.MAX_UNIFORM_BLOCK_SIZE))/16)*4;if(this.words<4)throw Error('Point grid block unavailable');this.data=new Uint32Array(this.words);this.shader=(layout==='mask'?pointGridMaskShader:pointGridShader)(ShaderChunk.lights_fragment_begin,this.words);this.tag='|nwn-point-grid-'+layout+'-v1-'+this.words;this.allocate();owners.set(renderer,this);
  this.beforeRender=renderer.render;this.beforeDirect=renderer.renderBufferDirect;this.beforeCompile=renderer.compile;this.beforeCompileAsync=renderer.compileAsync;const owner=this;
  this.renderHook=function(scene,camera){return owner.render(scene,camera,()=>owner.beforeRender.call(this,scene,camera));};renderer.render=this.renderHook;
  this.directHook=function(...args){if(owner.enabled&&!owner.disposed)owner.attach(args[3]);return owner.beforeDirect.apply(this,args);};renderer.renderBufferDirect=this.directHook;
  this.compileHook=function(scene,...args){if(owner.enabled)owner.attachScene(scene);return owner.beforeCompile.call(this,scene,...args);};renderer.compile=this.compileHook;
  this.compileAsyncHook=function(scene,...args){if(owner.enabled)owner.attachScene(scene);return owner.beforeCompileAsync.call(this,scene,...args);};renderer.compileAsync=this.compileAsyncHook;
  this.beforeBindBase=gl.bindBufferBase;this.beforeBindRange=gl.bindBufferRange;
  this.bindBaseHook=function(target,index,buffer){const result=owner.beforeBindBase.call(this,target,index,buffer);if(target===gl.UNIFORM_BUFFER&&index===owner.binding)owner.bound=buffer===owner.buffer;return result;};gl.bindBufferBase=this.bindBaseHook;
  this.bindRangeHook=function(target,index,...args){const result=owner.beforeBindRange.call(this,target,index,...args);if(target===gl.UNIFORM_BUFFER&&index===owner.binding)owner.bound=false;return result;};gl.bindBufferRange=this.bindRangeHook;
  this.attachState();this.lost=()=>{this.detachState();this.programs.clear();this.releaseLease();this.buffer=null;};this.restored=()=>{try{this.allocate();this.attachState();}catch{this.setEnabled(false);this.stats.failure='context-capacity';}};renderer.domElement?.addEventListener('webglcontextlost',this.lost);renderer.domElement?.addEventListener('webglcontextrestored',this.restored);
 }
 allocate(){const gl=this.gl;let used=leases.get(gl);if(!used)leases.set(gl,used=new Set());const maximum=gl.getParameter(gl.MAX_UNIFORM_BUFFER_BINDINGS);let index=maximum-1;while(index>=0&&(used.has(index)||gl.getIndexedParameter(gl.UNIFORM_BUFFER_BINDING,index)!==null))index--;if(index<0)throw Error('Point grid binding unavailable');this.binding=index;this.bound=false;used.add(index);const before=gl.getParameter(gl.UNIFORM_BUFFER_BINDING);this.buffer=gl.createBuffer();try{if(!this.buffer)throw Error('Point grid buffer allocation failed');gl.bindBuffer(gl.UNIFORM_BUFFER,this.buffer);gl.bufferData(gl.UNIFORM_BUFFER,this.words*4,gl.DYNAMIC_DRAW);}catch(error){this.releaseLease();if(this.buffer)gl.deleteBuffer(this.buffer);this.buffer=null;throw error;}finally{gl.bindBuffer(gl.UNIFORM_BUFFER,before);}}
 releaseLease(){if(this.binding!==undefined)leases.get(this.gl)?.delete(this.binding);this.binding=undefined;}
 setEnabled(value){value=Boolean(value)&&!this.disposed;if(value===this.enabled)return;this.enabled=value;for(const [material,record]of this.records){if(!value){if(material.onBeforeCompile===record.compile)material.onBeforeCompile=record.before;if(material.customProgramCacheKey===record.key)material.customProgramCacheKey=record.beforeKey;}material.needsUpdate=true;}}
 attachScene(scene){scene.traverse(object=>{for(const material of Array.isArray(object.material)?object.material:object.material?[object.material]:[])this.attach(material);});}
 attach(material){
  if(!material||!this.enabled||!(material.isMeshLambertMaterial||material.isMeshPhongMaterial||material.isMeshStandardMaterial))return;
  const old=this.records.get(material);if(old&&material.onBeforeCompile===old.compile&&material.customProgramCacheKey===old.key)return;
  const before=material.onBeforeCompile,beforeKey=material.customProgramCacheKey;if(before!==base.onBeforeCompile&&!isLocalRendererHook(before)||beforeKey!==base.customProgramCacheKey&&!isLocalRendererHook(beforeKey))return;
  if(old)material.removeEventListener('dispose',old.retire);const owner=this;
  const compile=function(shader,renderer){before.call(this,shader,renderer);if(renderer!==owner.renderer||!owner.enabled||owner.disposed||shader.fragmentShader.includes('uniform NwnPointGrid'))return;const source=shader.fragmentShader;if(source.split('#include <lights_fragment_begin>').length!==2||source.split('#include <lights_pars_begin>').length!==2)return;let fragment=owner.shader.fragment,declarations=owner.shader.declarations;if(Number.isInteger(shader.numPointLights)&&Number.isInteger(shader.numPointLightShadows)){const marker='nwnPointGridExpected_'+shader.numPointLights+'_'+shader.numPointLightShadows;declarations+='\nuniform int '+marker+';\n';fragment=fragment.replace('nwnPointGridEnabled==1','nwnPointGridEnabled==1 && '+marker+'>=0').replace('nwnPointGridEnabled == 1','nwnPointGridEnabled == 1 && '+marker+'>=0');}shader.fragmentShader=source.replace('#include <lights_fragment_begin>',fragment).replace('#include <lights_pars_begin>','#include <lights_pars_begin>\n'+declarations);};
  const key=function(){const current=material.onBeforeCompile;material.onBeforeCompile=before;let value;try{value=beforeKey.call(material);}finally{if(material.onBeforeCompile===before)material.onBeforeCompile=current;}return owner.enabled&&!owner.disposed&&!value.includes(owner.tag)?value+owner.tag:value;};
  const retire=()=>{if(material.onBeforeCompile===compile)material.onBeforeCompile=before;if(material.customProgramCacheKey===key)material.customProgramCacheKey=beforeKey;material.removeEventListener('dispose',retire);owner.records.delete(material);};
  batchRendererHook(compile,{kind:'point-grid',token:this,before});localRendererHook(key);material.onBeforeCompile=compile;material.customProgramCacheKey=key;material.needsUpdate=true;material.addEventListener('dispose',retire);this.records.set(material,{before,beforeKey,compile,key,retire});
 }
 prepare(scene,camera){
  if(!this.buffer||camera.isArrayCamera||!camera.isPerspectiveCamera&&!camera.isOrthographicCamera||!Number.isFinite(camera.far)||camera.far>1e12||!(camera.near>0))return null;
  const lights=[];scene.traverseVisible(light=>{if(light.isPointLight&&light.layers.test(camera.layers))lights.push(light);});if(lights.some(light=>light.map))return null;lights.sort((a,b)=>Number(b.castShadow)-Number(a.castShadow));
  const inputs=lights.map(light=>{this.position.setFromMatrixPosition(light.matrixWorld).applyMatrix4(camera.matrixWorldInverse);return{position:[Math.fround(this.position.x),Math.fround(this.position.y),Math.fround(this.position.z)],radius:Math.fround(light.distance),decay:light.decay,neutral:Boolean(light.userData.rendererLightSlot&&light.intensity===0&&Number.isFinite(light.color.r)&&Number.isFinite(light.color.g)&&Number.isFinite(light.color.b))};}),firstShadow=lights.filter(light=>light.castShadow).length;
  this.renderer.getCurrentViewport(this.viewport);const [x,y,width,height]=this.viewport.toArray();if(![x,y,width,height].every(Number.isInteger)||width<1||height<1)return null;
  const grid=buildPointLightGrid({lights:inputs,firstShadow,width,height,near:camera.near,perspective:camera.isPerspectiveCamera===true,projection:camera.projectionMatrix.elements,tileSize:this.tileSize,data:this.data,bits:this.bits});this.bits=grid.bits;if(this.layout==='mask'&&grid.enabled){if(lights.length>128||grid.cols*grid.rows*4>this.words)grid.enabled=false;else{const count=Math.ceil(lights.length/32);for(let cell=0;cell<grid.cols*grid.rows;cell++)for(let word=0;word<4;word++)this.data[cell*4+word]=word<count?grid.bits[cell*count+word]:0;grid.usedWords=grid.cols*grid.rows*4;grid.fallbackCells=0;}}
  this.stats={...this.stats,enabled:this.enabled,layout:this.layout,active:grid.enabled,lights:lights.length,firstShadow,cols:grid.cols,rows:grid.rows,fallbackCells:grid.fallbackCells,averageLights:grid.averageLights,maxLights:grid.maxLights,usedBytes:grid.usedWords*4};if(!grid.enabled)return null;
  const gl=this.gl,before=gl.getParameter(gl.UNIFORM_BUFFER_BINDING);try{gl.bindBuffer(gl.UNIFORM_BUFFER,this.buffer);gl.bufferSubData(gl.UNIFORM_BUFFER,0,this.data,0,grid.usedWords);}finally{gl.bindBuffer(gl.UNIFORM_BUFFER,before);}return{...grid,viewport:[x,y,grid.cols,grid.rows]};
 }
 attachState(){const owner=this;this.state=this.renderer.state;this.beforeUse=this.state.useProgram;this.useHook=function(program){const result=owner.beforeUse.call(this,program);owner.use(program);return result;};this.state.useProgram=this.useHook;}
 detachState(){if(this.state?.useProgram===this.useHook)this.state.useProgram=this.beforeUse;}
 use(program){
  if(this.disposed||!this.buffer)return;let record=this.programs.get(program);if(!record){const source=this.renderer.info.programs.find(p=>p.program===program);if(!source)return;const uniforms=source.getUniforms(),marker=Object.keys(uniforms.map).map(name=>/^nwnPointGridExpected_(\d+)_(\d+)$/.exec(name)).find(Boolean);record={uniforms,owned:Boolean(uniforms.map.nwnPointGridEnabled),lights:marker?Number(marker[1]):null,shadows:marker?Number(marker[2]):null};if(record.owned){const block=this.gl.getUniformBlockIndex(program,'NwnPointGrid');if(block===this.gl.INVALID_INDEX)record.owned=false;else this.gl.uniformBlockBinding(program,block,this.binding);}this.programs.set(program,record);}if(!record.owned)return;
  const gl=this.gl,grid=this.active,active=Boolean(this.enabled&&grid&&grid.lights===record.lights&&grid.firstShadow===record.shadows);if(active)this.stats.activeDraws=(this.stats.activeDraws??0)+1;if(!this.bound)gl.bindBufferBase(gl.UNIFORM_BUFFER,this.binding,this.buffer);record.uniforms.setValue(gl,'nwnPointGridEnabled',Number(active));if(grid){record.uniforms.setValue(gl,'nwnPointGridLightCount',grid.lights);record.uniforms.setValue(gl,'nwnPointGridShadowCount',grid.firstShadow);record.uniforms.setValue(gl,'nwnPointGridViewport',grid.viewport);record.uniforms.setValue(gl,'nwnPointGridTile',this.tileSize);}
 }
 render(scene,camera,draw){
  if(this.disposed)return draw();const previous=this.active,wasRunning=this.running,gl=this.gl,generic=gl.getParameter(gl.UNIFORM_BUFFER_BINDING),auto=scene.matrixWorldAutoUpdate;let prepared=false;this.running=true;
  try{
   if(this.enabled&&!wasRunning){if(auto){scene.updateMatrixWorld();prepared=true;scene.matrixWorldAutoUpdate=false;}if(camera.parent===null&&camera.matrixWorldAutoUpdate)camera.updateMatrixWorld();const foreign=this.binding!==undefined?gl.getIndexedParameter(gl.UNIFORM_BUFFER_BINDING,this.binding):null;if(foreign&&foreign!==this.buffer){const old=this.buffer;this.releaseLease();this.allocate();if(old&&gl.isBuffer(old))gl.deleteBuffer(old);this.programs.clear();}this.active=this.prepare(scene,camera);}else this.active=null;
   if(!wasRunning){this.stats.active=Boolean(this.active);this.stats.activeDraws=0;}return draw();
  }finally{if(prepared)scene.matrixWorldAutoUpdate=auto;this.active=previous;this.running=wasRunning;if(!wasRunning&&this.binding!==undefined)gl.bindBufferBase(gl.UNIFORM_BUFFER,this.binding,null);gl.bindBuffer(gl.UNIFORM_BUFFER,generic);}
 }
 snapshot(){const live=new Set(this.renderer.info.programs.map(p=>p.program));for(const key of this.programs.keys())if(!live.has(key))this.programs.delete(key);return{...this.stats,enabled:this.enabled,materials:this.records.size,programs:this.programs.size,ownedPrograms:[...this.programs.values()].filter(p=>p.owned).length,bytes:this.buffer?this.words*4:0};}
 dispose(){
  if(this.disposed)return;this.setEnabled(false);this.disposed=true;this.detachState();const r=this.renderer;for(const [key,hook,before]of [['render',this.renderHook,this.beforeRender],['renderBufferDirect',this.directHook,this.beforeDirect],['compile',this.compileHook,this.beforeCompile],['compileAsync',this.compileAsyncHook,this.beforeCompileAsync]])if(r[key]===hook)r[key]=before;
  for(const record of [...this.records.values()])record.retire();this.records.clear();this.programs.clear();r.domElement?.removeEventListener('webglcontextlost',this.lost);r.domElement?.removeEventListener('webglcontextrestored',this.restored);if(this.gl.bindBufferBase===this.bindBaseHook)this.gl.bindBufferBase=this.beforeBindBase;if(this.gl.bindBufferRange===this.bindRangeHook)this.gl.bindBufferRange=this.beforeBindRange;if(this.buffer&&this.gl.isBuffer(this.buffer))this.gl.deleteBuffer(this.buffer);this.buffer=null;this.releaseLease();owners.delete(r);
 }
}
