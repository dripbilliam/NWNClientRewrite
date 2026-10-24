import {Group,Mesh,BufferGeometry,GLBufferAttribute,Object3D,Material,Sphere,ShaderChunk} from 'three';
import {RendererPaletteArrays} from './renderer_palette_arrays.js';
import {isLocalRendererHook,rendererBatchHook} from './renderer_local_hooks.js';
const objectBase=Object3D.prototype,materialBase=Material.prototype;
const materialFields=['blending','side','vertexColors','alphaHash','blendSrc','blendDst','blendEquation','blendSrcAlpha','blendDstAlpha','blendEquationAlpha','blendAlpha','depthFunc','depthTest','depthWrite','stencilWriteMask','stencilFunc','stencilRef','stencilFuncMask','stencilFail','stencilZFail','stencilZPass','stencilWrite','clipIntersection','clipShadows','colorWrite','precision','polygonOffset','polygonOffsetFactor','polygonOffsetUnits','dithering','alphaToCoverage','premultipliedAlpha','forceSinglePass','allowOverride','toneMapped','alphaTest','flatShading','fog'];
const streams=[['position',3],['normal',3],['uv',2],['nwnBatchIndex',1]];
const mapFields=['map','lightMap','aoMap','emissiveMap','bumpMap','normalMap','displacementMap','specularMap','alphaMap','envMap'];
function shader(material,uniforms,limit,extension){
 material.onBeforeCompile=(program,renderer)=>{
  extension?.compile(program,renderer);
  if(extension?.keyhole)for(const stage of ['vertexShader','fragmentShader']){const source=program[stage],declaration=/uniform\s+lowp\s+int\s+nwnKeyhole_keyholeCanDissolve\s*;/;if(!declaration.test(source))throw Error('Unsupported keyhole batch declaration');program[stage]=source.replace(declaration,'flat varying lowp int nwnBatchKeyholeCan;').replaceAll('nwnKeyhole_keyholeCanDissolve','nwnBatchKeyholeCan');}
  Object.assign(program.uniforms,uniforms);const declarations=`attribute float nwnBatchIndex;\nuniform mat4 nwnBatchViews[${limit}];\nuniform mat3 nwnBatchNormals[${limit}];\nuniform mat4 nwnBatchWorlds[${limit}];\nuniform vec4 nwnBatchColors[${limit}];\nuniform vec4 nwnBatchEmissionLayers[${limit}];\nuniform vec3 nwnBatchUvScales[${limit}];\nflat varying vec4 nwnBatchColor;\nflat varying vec4 nwnBatchEmissionLayer;\nflat varying vec2 nwnBatchUvScale;\n`;
  program.vertexShader=declarations+program.vertexShader.replace('void main() {',`void main() {\n nwnBatchColor=nwnBatchColors[int(nwnBatchIndex)];nwnBatchEmissionLayer=nwnBatchEmissionLayers[int(nwnBatchIndex)];nwnBatchUvScale=nwnBatchUvScales[int(nwnBatchIndex)].xy;${extension?.keyhole?'nwnBatchKeyholeCan=int(nwnBatchUvScales[int(nwnBatchIndex)].z);':''}`)
   .replace('#include <defaultnormal_vertex>',ShaderChunk.defaultnormal_vertex.replace('normalMatrix * transformedNormal','nwnBatchNormals[int(nwnBatchIndex)] * transformedNormal'))
   .replace('#include <project_vertex>','vec4 mvPosition = nwnBatchViews[int(nwnBatchIndex)] * vec4(transformed,1.0); gl_Position=projectionMatrix*mvPosition;')
   .replace('#include <worldpos_vertex>',ShaderChunk.worldpos_vertex.replace('modelMatrix * worldPosition','nwnBatchWorlds[int(nwnBatchIndex)] * worldPosition'))
   .replace('vec4 nwnTarget_world = modelMatrix * vec4(transformed, 1.0);','vec4 nwnTarget_world = nwnBatchWorlds[int(nwnBatchIndex)] * vec4(transformed, 1.0);');
  program.fragmentShader='flat varying vec4 nwnBatchColor;\nflat varying vec4 nwnBatchEmissionLayer;\nflat varying vec2 nwnBatchUvScale;\n'+program.fragmentShader
   .replace('#include <map_pars_fragment>',ShaderChunk.map_pars_fragment.replace('uniform sampler2D map;','uniform highp sampler2DArray map;'))
   .replace('#include <map_fragment>',ShaderChunk.map_fragment.replace('texture2D( map, vMapUv )','texture( map, vec3(vMapUv*nwnBatchUvScale,nwnBatchEmissionLayer.w) )'))
   .replace('vec4 diffuseColor = vec4( diffuse, opacity );','vec4 diffuseColor = nwnBatchColor;')
   .replace('vec3 totalEmissiveRadiance = emissive;','vec3 totalEmissiveRadiance = nwnBatchEmissionLayer.rgb;');
 };
 material.customProgramCacheKey=()=>`nwn-ordered-palette-batch-v3-${limit}-${extension?.cacheKey??'plain'}`;
}
export class RendererMainBatches{
 constructor(renderer,{enabled=true,maxBytes=64*1024*1024,maxVertexBytes=64*1024*1024,maxVertices=16384,minRepeatSize=128,staticOnly=false,compressed=false,maxBatchMembers=32,maxTextureLayers=32}={}){
  if(!Number.isInteger(maxBatchMembers)||maxBatchMembers<2||maxBatchMembers>256||!Number.isInteger(maxTextureLayers)||maxTextureLayers<1||maxTextureLayers>256)throw Error('Invalid ordered batch capacity');
  this.enabled=enabled;this.staticOnly=staticOnly;this.renderer=renderer;this.gl=renderer.getContext();this.limit=Math.max(0,Math.min(maxBatchMembers,Math.floor(((renderer.capabilities.maxVertexUniforms??0)-512)/14)));this.maxVertices=maxVertices;this.maxVertexBytes=maxVertexBytes;this.palettes=new RendererPaletteArrays({maxBytes,minRepeatSize,compressed,maxLayers:Math.min(maxTextureLayers,this.gl.getParameter(this.gl.MAX_ARRAY_TEXTURE_LAYERS))});this.root=new Group();this.root.name='Renderer ordered main batches';this.root.matrixAutoUpdate=false;this.root.matrixWorldAutoUpdate=false;this.reset();this.lost=()=>this.reset();renderer.domElement?.addEventListener('webglcontextlost',this.lost);
 }
 reset(){for(const batch of this.batches??[])if(batch)this.destroy(batch);this.batches=[];this.vertexBytes=0;this.root?.removeFromParent();this.root?.clear();this.palettes?.reset();this.disabled=false;this.failure=null;this.textureFields=new WeakMap();this.materialKeys=new WeakMap();this.extensions=new WeakMap();this.extensionIds=new WeakMap();this.extensionProfiles=new Map();this.ownerSerial=0;this.extensionSerial=0;this.stats={originalDraws:0,draws:0,batches:0,instances:0,vertices:0,uploads:0,pending:0,keyholeStates:0,keyEncodings:0};}
 materialKey(material,palette,extension,receiveShadow){
  let entry=this.materialKeys.get(material),same=entry&&entry.palette===palette.array.id&&entry.extension===(extension?.id??0)&&entry.receiveShadow===receiveShadow;
  if(same)for(let i=0;i<materialFields.length;i++)if(!Object.is(entry.values[i],material[materialFields[i]])){same=false;break;}
  if(same){const i=materialFields.length,c=material.blendColor;same=Object.is(entry.values[i],c.r)&&Object.is(entry.values[i+1],c.g)&&Object.is(entry.values[i+2],c.b);}
  if(!same){const values=materialFields.map(field=>material[field]);values.push(material.blendColor.r,material.blendColor.g,material.blendColor.b);entry={palette:palette.array.id,extension:extension?.id??0,receiveShadow,values,key:[palette.array.id,receiveShadow,extension?.id??0,...values].join('|')};this.materialKeys.set(material,entry);this.stats.keyEncodings++;}return entry.key;
 }
 extension(material){
  let record=this.extensions.get(material);if(record&&record.before===material.onBeforeCompile&&record.key===material.customProgramCacheKey&&record.version===material.version)return record.value;
  const tokens=[];let hook=material.onBeforeCompile,keyhole=null;
  while(hook!==materialBase.onBeforeCompile){const d=rendererBatchHook(hook);if(!d||!['target-preview','keyhole'].includes(d.kind)||tokens.includes(d.token))return undefined;tokens.push(d.token);if(d.kind==='keyhole'){if(keyhole)return undefined;keyhole=d;}hook=d.before;}
  if(!tokens.length){if(material.customProgramCacheKey!==materialBase.customProgramCacheKey)return undefined;return null;}
  if(!isLocalRendererHook(material.customProgramCacheKey))return undefined;
  const cacheKey=material.customProgramCacheKey(),owners=tokens.map(token=>{let id=this.extensionIds.get(token);if(!id){id=++this.ownerSerial;this.extensionIds.set(token,id);}return id;}).join(','),signature=owners+'|'+cacheKey;
  let id=this.extensionProfiles.get(signature);if(!id){id=++this.extensionSerial;this.extensionProfiles.set(signature,id);}
  const compile=material.onBeforeCompile,value={id,cacheKey,keyhole,compile:(program,renderer)=>compile.call(material,program,renderer)};this.extensions.set(material,{before:material.onBeforeCompile,key:material.customProgramCacheKey,version:material.version,value});return value;
 }
 uploadHook(material){let fields=this.textureFields.get(material);if(fields?.version!==material.version){fields={version:material.version,keys:Object.keys(material).filter(k=>material[k]==null||material[k]?.isTexture)};this.textureFields.set(material,fields);}for(const k of fields.keys)if(material[k]?.isTexture&&material[k].onUpdate)return true;for(const entry of Object.values(material.uniforms??{})){const value=entry?.value;if(value?.isTexture&&value.onUpdate||Array.isArray(value)&&value.some(v=>v?.isTexture&&v.onUpdate))return true;}return false;}
 descriptor(item){
  const {object,geometry,material,group}=item;
  if(this.staticOnly){let tile=object;while(tile&&!tile.userData.nativeStaticTile)tile=tile.parent;if(!tile)return null;}
  const extension=this.extension(material),renderHook=rendererBatchHook(object.onBeforeRender);
  if(extension===undefined||!object.isMesh||object.isSkinnedMesh||object.isInstancedMesh||object.isBatchedMesh||object.children.length||object.userData.animationOwnedGeometry||object.onAfterRender!==objectBase.onAfterRender||!material.isMeshLambertMaterial||!material.visible||material.transparent||material.wireframe||material.vertexColors||material.alphaHash||material.stencilWrite||material.clippingPlanes?.length||material.defines||material.uniforms||material.onBeforeRender!==materialBase.onBeforeRender||!Number.isFinite(material.alphaTest)||geometry.index)return null;
  if(extension?.keyhole){if(renderHook?.kind!=='keyhole-state'||renderHook.token!==extension.keyhole.token||renderHook.can!==extension.keyhole.can)return null;}else if(object.onBeforeRender!==objectBase.onBeforeRender)return null;
  for(const field of mapFields)if(field!=='map'&&material[field])return null;
  for(const name in geometry.morphAttributes)if(geometry.morphAttributes[name]?.length)return null;
  if(!(object.matrixWorld.determinant()>0)||!object.matrixWorld.elements.every(Number.isFinite))return null;
  if(geometry.isInstancedBufferGeometry)return null;
  for(const [name,size]of streams.slice(0,3)){const a=geometry.attributes[name];if(!a||a.itemSize!==size||a.normalized||a.isInstancedBufferAttribute||a.isInterleavedBufferAttribute||a.version>(name==='normal'?1:0)||!(a.array instanceof Float32Array))return null;}
  const count=geometry.attributes.position.count;if(geometry.attributes.normal.count!==count||geometry.attributes.uv.count!==count)return null;
  const start=Math.max(0,geometry.drawRange.start,group?.start??0),end=Math.min(count,geometry.drawRange.start+geometry.drawRange.count,group?group.start+group.count:Infinity),length=Math.max(0,end-start);
  if(!Number.isInteger(start)||start%3||!Number.isInteger(length)||length%3||!length||length>this.maxVertices)return null;
  const palette=this.palettes.get(material.map);if(!palette)return null;
  const key=this.materialKey(material,palette,extension,object.receiveShadow);return{item,palette,key,start,count:length,extension,renderHook:extension?.keyhole?object.onBeforeRender:null};
 }
 audit(list){
  const reasons={},textures={},samples=[];let tiles=0;
  for(const item of list.opaque){const{object:o,material:m,geometry:g,group}=item;let tile=o;while(tile&&!tile.userData.nativeStaticTile)tile=tile.parent;if(!tile)continue;tiles++;
   const extension=this.extension(m),hook=rendererBatchHook(o.onBeforeRender),checks={extension:extension===undefined,object:!o.isMesh||o.isSkinnedMesh||o.isInstancedMesh||o.isBatchedMesh||o.children.length||o.userData.animationOwnedGeometry||o.onAfterRender!==objectBase.onAfterRender,material:!m.isMeshLambertMaterial||!m.visible||m.transparent||m.wireframe||m.vertexColors||m.alphaHash||m.stencilWrite||m.clippingPlanes?.length||m.defines||m.uniforms||m.onBeforeRender!==materialBase.onBeforeRender||!Number.isFinite(m.alphaTest)||g.index,hook:extension?.keyhole?hook?.kind!=='keyhole-state'||hook.token!==extension.keyhole.token||hook.can!==extension.keyhole.can:o.onBeforeRender!==objectBase.onBeforeRender,maps:mapFields.some(k=>k!=='map'&&m[k]),morph:Object.values(g.morphAttributes).some(v=>v?.length),transform:!(o.matrixWorld.determinant()>0)||!o.matrixWorld.elements.every(Number.isFinite),attributes:g.isInstancedBufferGeometry||streams.slice(0,3).some(([name,size])=>{const a=g.attributes[name];return!a||a.itemSize!==size||a.normalized||a.isInstancedBufferAttribute||a.isInterleavedBufferAttribute||a.version>(name==='normal'?1:0)||!(a.array instanceof Float32Array);})};
   const reason=Object.keys(checks).find(k=>checks[k]);let result=reason;
   if(!result){const count=g.attributes.position.count,start=Math.max(0,g.drawRange.start,group?.start??0),end=Math.min(count,g.drawRange.start+g.drawRange.count,group?group.start+group.count:Infinity),length=Math.max(0,end-start);if(!Number.isInteger(start)||start%3||!Number.isInteger(length)||length%3||!length||length>this.maxVertices)result='range';else result=this.palettes.descriptor(m.map)?'eligible':'texture';}
   reasons[result]=(reasons[result]??0)+1;
   const map=m.map,texture=JSON.stringify({type:map?.type,format:map?.format,compressed:Boolean(map?.isCompressedTexture),data:Boolean(map?.isDataTexture),width:map?.image?.width,height:map?.image?.height,mips:map?.mipmaps?.length,version:map?.version,flipY:map?.flipY});textures[texture]=(textures[texture]??0)+1;
   if(samples.length<6)samples.push({reason:result,hook:hook?.kind,extension:extension?.keyhole?'keyhole':extension===undefined?'unknown':'plain',attributes:Object.fromEntries(Object.entries(g.attributes).map(([k,a])=>[k,{size:a.itemSize,count:a.count,version:a.version}]))});
  }return{tiles,reasons,textures,samples};
 }
 create(descriptor,vertices){
  const capacity=2**Math.ceil(Math.log2(vertices)),bytes=capacity*36;if(this.vertexBytes+bytes>this.maxVertexBytes)return null;
  const gl=this.gl,previous=gl.getParameter(gl.COPY_WRITE_BUFFER_BINDING),geometry=new BufferGeometry(),data={},attributes={},buffers=[];
  try{for(const[name,size]of streams){const buffer=gl.createBuffer();if(!buffer)throw Error('Main batch buffer allocation failed');buffers.push(buffer);gl.bindBuffer(gl.COPY_WRITE_BUFFER,buffer);gl.bufferData(gl.COPY_WRITE_BUFFER,capacity*size*4,gl.DYNAMIC_DRAW);attributes[name]=new GLBufferAttribute(buffer,gl.FLOAT,size,4,capacity);geometry.setAttribute(name,attributes[name]);data[name]=new Float32Array(capacity*size);}}
  catch(error){for(const b of buffers)if(gl.isBuffer(b))gl.deleteBuffer(b);geometry.dispose();throw error;}finally{gl.bindBuffer(gl.COPY_WRITE_BUFFER,previous);}
  geometry.setDrawRange(0,0);geometry.boundingSphere=new Sphere(undefined,Infinity);const material=descriptor.item.material.clone();material.map=descriptor.palette.array.texture;material.visible=false;
  const uniforms={nwnBatchViews:{value:new Float32Array(this.limit*16)},nwnBatchNormals:{value:new Float32Array(this.limit*9)},nwnBatchWorlds:{value:new Float32Array(this.limit*16)},nwnBatchColors:{value:new Float32Array(this.limit*4)},nwnBatchEmissionLayers:{value:new Float32Array(this.limit*4)},nwnBatchUvScales:{value:new Float32Array(this.limit*3)}};shader(material,uniforms,this.limit,descriptor.extension);const storage=Object.fromEntries(Object.entries(uniforms).map(([key,u])=>[key,u.value]));
  const proxy=new Mesh(geometry,material);proxy.frustumCulled=false;proxy.matrixAutoUpdate=false;proxy.matrixWorldAutoUpdate=false;proxy.receiveShadow=descriptor.item.object.receiveShadow;proxy.castShadow=false;this.root.add(proxy);
  this.vertexBytes+=bytes;return{proxy,material,geometry,uniforms,storage,data,attributes,buffers,key:descriptor.key,slots:[],capacity,bytes,born:this.renderer.info.render.frame};
 }
 fill(batch,members,camera,scene,active){
  const gl=this.gl,previous=gl.getParameter(gl.COPY_WRITE_BUFFER_BINDING),changed=new Set();let offset=0;
  try{for(let i=0;i<members.length;i++){
   const d=members[i],object=d.item.object,geometry=d.item.geometry,old=batch.slots[i],{position,normal,uv}=geometry.attributes;if(!old||old.geometry!==geometry||old.start!==d.start||old.count!==d.count||old.offset!==offset||old.position!==position||old.uv!==uv||old.normal!==normal||old.normalVersion!==normal.version){for(const[name,size]of streams){const target=batch.data[name];if(name==='nwnBatchIndex')target.fill(i,offset,offset+d.count);else target.set(geometry.attributes[name].array.subarray(d.start*size,(d.start+d.count)*size),offset*size);changed.add(name);}batch.slots[i]={geometry,start:d.start,count:d.count,offset,position,uv,normal,normalVersion:normal.version};}
   if(active&&d.renderHook){d.renderHook.call(object,this.renderer,scene,camera,geometry,d.item.material,d.item.group);this.stats.keyholeStates++;}
   object.modelViewMatrix.multiplyMatrices(camera.matrixWorldInverse,object.matrixWorld);object.normalMatrix.getNormalMatrix(object.modelViewMatrix);const u=batch.storage,m=d.item.material;
   u.nwnBatchViews.set(object.modelViewMatrix.elements,i*16);u.nwnBatchNormals.set(object.normalMatrix.elements,i*9);u.nwnBatchWorlds.set(object.matrixWorld.elements,i*16);u.nwnBatchColors.set([m.color.r,m.color.g,m.color.b,m.opacity],i*4);u.nwnBatchEmissionLayers.set([m.emissive.r*m.emissiveIntensity,m.emissive.g*m.emissiveIntensity,m.emissive.b*m.emissiveIntensity,d.palette.layer],i*4);u.nwnBatchUvScales[i*3]=d.palette.uvScale[0];u.nwnBatchUvScales[i*3+1]=d.palette.uvScale[1];u.nwnBatchUvScales[i*3+2]=d.extension?.keyhole?.can.value??0;offset+=d.count;
  }
  for(const name of changed){const size=streams.find(s=>s[0]===name)[1];gl.bindBuffer(gl.COPY_WRITE_BUFFER,batch.attributes[name].buffer);gl.bufferSubData(gl.COPY_WRITE_BUFFER,0,batch.data[name],0,offset*size);this.stats.uploads++;}
  }finally{gl.bindBuffer(gl.COPY_WRITE_BUFFER,previous);}
  if(batch.members!==members.length){for(const [key,array]of Object.entries(batch.storage)){const width=array.length/this.limit;batch.uniforms[key].value=array.subarray(0,members.length*width);}batch.members=members.length;}
  batch.slots.length=members.length;batch.geometry.setDrawRange(0,offset);this.stats.vertices+=offset;
 }
 patch(list,camera,scene=null){
  const original=list.opaque,result=[];this.stats={originalDraws:original.length,draws:0,batches:0,instances:0,vertices:0,uploads:0,pending:0,keyholeStates:0,keyEncodings:0};let members=[],key=null,vertices=0,used=0;
  const unknown=(hook,base)=>hook!==base&&!isLocalRendererHook(hook);
  if(list.transmissive.length||[...original,...(list.transparent??[])].some(({object:o,material:m})=>unknown(o.onBeforeRender,objectBase.onBeforeRender)||o.onAfterRender!==objectBase.onAfterRender||m.onBeforeRender!==materialBase.onBeforeRender||unknown(m.onBeforeCompile,materialBase.onBeforeCompile)||unknown(m.customProgramCacheKey,materialBase.customProgramCacheKey)||this.uploadHook(m))){this.stats.draws=original.length;this.stats.fallback='render-callback';return()=>{};}
  const flush=()=>{if(!members.length)return;if(members.length<2){result.push(...members.map(d=>d.item));}else{
   let batch=this.batches[used];if(batch&&(batch.key!==key||batch.capacity<vertices)){this.destroy(batch);this.batches[used]=null;batch=null;}if(!batch)this.batches[used]=batch=this.create(members[0],vertices);if(!batch){result.push(...members.map(d=>d.item));members=[];vertices=0;key=null;return;}used++;batch.proxy.layers.mask=camera.layers.mask;this.fill(batch,members,camera,scene,batch.born<this.renderer.info.render.frame);
   if(batch.born<this.renderer.info.render.frame){batch.material.visible=true;const first=members[0].item;result.push({...first,object:batch.proxy,geometry:batch.geometry,material:batch.material,group:null});this.stats.batches++;this.stats.instances+=members.length;}else{result.push(...members.map(d=>d.item));this.stats.pending++;}
  }members=[];vertices=0;key=null;};
  this.palettes.beginPass();try{for(const item of original){const d=this.descriptor(item);if(!d){flush();result.push(item);continue;}if(key!==null&&(key!==d.key||members.length===this.limit||vertices+d.count>this.maxVertices))flush();key=d.key;members.push(d);vertices+=d.count;}flush();}finally{this.palettes.endPass();}
  while(this.batches.length>used){const batch=this.batches.pop();if(batch)this.destroy(batch);}this.stats.draws=result.length;list.opaque=result;return()=>{list.opaque=original;};
 }
 render(scene,camera){
  const renderer=this.renderer;
  if(!this.enabled||this.disabled||this.limit<2||this.running||scene.overrideMaterial||scene.onBeforeRender!==objectBase.onBeforeRender||scene.onAfterRender!==objectBase.onAfterRender||camera.isArrayCamera||renderer.xr?.enabled||renderer.clippingPlanes?.length)return renderer.render(scene,camera);
  if(this.root.parent!==scene)scene.add(this.root);for(const b of this.batches){b.material.visible=false;b.proxy.layers.mask=camera.layers.mask;}
  const map=renderer.shadowMap,original=map.render;let restore;this.running=true;
  map.render=(lights,s,c)=>{const result=original.call(map,lights,s,c);if(s===scene&&c===camera&&!restore){try{restore=this.patch(renderer.renderLists.get(scene,0),camera,scene);}catch{this.reset();this.disabled=true;this.failure='resource-preparation';}}return result;};
  try{return renderer.render(scene,camera);}finally{restore?.();map.render=original;this.running=false;for(const b of this.batches)if(b)b.material.visible=false;}
 }
 destroy(batch){batch.proxy.removeFromParent();batch.geometry.dispose();batch.material.dispose();for(const b of batch.buffers)if(this.gl.isBuffer(b))this.gl.deleteBuffer(b);batch.slots=[];this.vertexBytes-=batch.bytes;}
 snapshot(){return{...this.stats,cachedBatches:this.batches.filter(Boolean).length,...this.palettes.snapshot(),shaderProfiles:this.extensionProfiles.size,vertexBytes:this.vertexBytes,limit:this.limit,staticOnly:this.staticOnly,minRepeatSize:this.palettes.minRepeatSize,enabled:this.enabled,disabled:this.disabled,failure:this.failure};}
 dispose(){this.renderer.domElement?.removeEventListener('webglcontextlost',this.lost);this.reset();}
}
