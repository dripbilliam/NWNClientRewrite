import {BufferGeometry,Float32BufferAttribute,GLBufferAttribute,DataTexture,RGBAFormat,RedIntegerFormat,FloatType,UnsignedIntType,NearestFilter,Mesh,MeshBasicMaterial,Group,Material,Object3D,ShaderChunk,Sphere,Matrix3,Matrix4} from 'three';
import {RendererPaletteArrays} from './renderer_palette_arrays.js';
import {isLocalRendererHook,rendererBatchHook} from './renderer_local_hooks.js';

// Experimental, not installed by the application. Reuse immutable geometry and
// original 2D textures; Three owns GL resources and multi-draw/fallback dispatch.
// Original objects remain the owners of shadows, picking and animation.
const ob=Object3D.prototype,mb=Material.prototype;
const fields=['blending','side','vertexColors','alphaHash','blendSrc','blendDst','blendEquation','blendSrcAlpha','blendDstAlpha','blendEquationAlpha','blendAlpha','depthFunc','depthTest','depthWrite','stencilWriteMask','stencilFunc','stencilRef','stencilFuncMask','stencilFail','stencilZFail','stencilZPass','stencilWrite','clipIntersection','clipShadows','colorWrite','precision','polygonOffset','polygonOffsetFactor','polygonOffsetUnits','dithering','alphaToCoverage','premultipliedAlpha','forceSinglePass','allowOverride','toneMapped','alphaTest','flatShading','fog'];
const maps=['lightMap','aoMap','emissiveMap','bumpMap','normalMap','displacementMap','specularMap','alphaMap','envMap'];
const streams=[['position',3],['normal',3],['uv',2]],streamNames=['position','normal','uv'],identityUv=[1,0,0,0,1,0,0,0,1];
const rowSize=64;
function put(data,offset,index,value){value=Math.fround(value);if(Object.is(data[offset+index],value))return false;data[offset+index]=value;return true;}
function storage(data,width,height,format,type){const t=new DataTexture(data,width,height,format,type);t.minFilter=t.magFilter=NearestFilter;t.generateMipmaps=false;t.needsUpdate=true;return t;}
function installShader(material,uniforms,slots,extension,merged,sampleAll,arrayPalette){
 material.onBeforeCompile=(p,r)=>{
  extension?.compile(p,r);
  if(extension?.keyhole)for(const stage of ['vertexShader','fragmentShader']){const pattern=/uniform\s+lowp\s+int\s+nwnKeyhole_keyholeCanDissolve\s*;/;if(!pattern.test(p[stage]))throw Error('Unknown keyhole declaration');p[stage]=p[stage].replace(pattern,'flat varying lowp int nwnCmdKeyhole;').replaceAll('nwnKeyhole_keyholeCanDissolve','nwnCmdKeyhole');}
  Object.assign(p.uniforms,uniforms);
  const pars=(merged?'attribute float nwnCmdRowId;\nuniform highp sampler2D batchingTexture;\n':ShaderChunk.batching_pars_vertex)+`
uniform int nwnCmdOffset;
vec4 nwnCmdFetch(int row,int col){return texelFetch(batchingTexture,ivec2(col,row),0);}
flat varying vec4 nwnCmdColor;
flat varying vec3 nwnCmdEmission;
flat varying int nwnCmdMap;
${arrayPalette?'flat varying float nwnCmdLayer;':''}
#undef USE_BATCHING
`;
  p.vertexShader=p.vertexShader.replace('#include <batching_pars_vertex>',pars)
   .replace('#include <batching_vertex>','')
   .replace('void main() {',`void main() {
 int nwnCmdRow=${merged?'int(nwnCmdRowId)':'int(getIndirectIndex(nwnCmdOffset+gl_DrawID))'};
 mat4 nwnCmdView=mat4(nwnCmdFetch(nwnCmdRow,0),nwnCmdFetch(nwnCmdRow,1),nwnCmdFetch(nwnCmdRow,2),nwnCmdFetch(nwnCmdRow,3));
 mat3 nwnCmdNormal=mat3(nwnCmdFetch(nwnCmdRow,4).xyz,nwnCmdFetch(nwnCmdRow,5).xyz,nwnCmdFetch(nwnCmdRow,6).xyz);
 mat4 nwnCmdWorld=mat4(nwnCmdFetch(nwnCmdRow,7),nwnCmdFetch(nwnCmdRow,8),nwnCmdFetch(nwnCmdRow,9),nwnCmdFetch(nwnCmdRow,10));
 mat3 nwnCmdUv=mat3(nwnCmdFetch(nwnCmdRow,13).xyz,nwnCmdFetch(nwnCmdRow,14).xyz,nwnCmdFetch(nwnCmdRow,15).xyz);
 nwnCmdColor=nwnCmdFetch(nwnCmdRow,11);vec4 nwnCmdExtra=nwnCmdFetch(nwnCmdRow,12);nwnCmdEmission=nwnCmdExtra.rgb;${arrayPalette?`nwnCmdMap=int(nwnCmdExtra.w)%${slots};nwnCmdLayer=float(int(nwnCmdExtra.w)/${slots});`:'nwnCmdMap=int(nwnCmdExtra.w);'}
 ${extension?.keyhole?'nwnCmdKeyhole=int(nwnCmdFetch(nwnCmdRow,13).w);':''}`)
   .replace('#include <uv_vertex>',ShaderChunk.uv_vertex.replace('mapTransform * vec3( MAP_UV, 1 )','nwnCmdUv * vec3( MAP_UV, 1 )')+(arrayPalette?'\n#ifdef USE_MAP\nvMapUv*=vec2(nwnCmdFetch(nwnCmdRow,14).w,nwnCmdFetch(nwnCmdRow,15).w);\n#endif\n':''))
   .replace('#include <defaultnormal_vertex>',ShaderChunk.defaultnormal_vertex.replace('normalMatrix * transformedNormal','nwnCmdNormal * transformedNormal'))
   .replace('#include <project_vertex>','vec4 mvPosition=nwnCmdView*vec4(transformed,1.0);gl_Position=projectionMatrix*mvPosition;')
   .replace('#include <worldpos_vertex>',ShaderChunk.worldpos_vertex.replace('modelMatrix * worldPosition','nwnCmdWorld * worldPosition'))
   .replace('vec4 nwnTarget_world = modelMatrix * vec4(transformed, 1.0);','vec4 nwnTarget_world = nwnCmdWorld * vec4(transformed, 1.0);');
  const samples=sampleAll?Array.from({length:slots},(_,i)=>`vec4 nwnCmdSample${i}=${arrayPalette?'texture':'texture2D'}(nwnCmdMaps[${i}],${arrayPalette?'vec3(vMapUv,nwnCmdLayer)':'vMapUv'});`).join('\n'):'vec2 nwnCmdDx=dFdx(vMapUv),nwnCmdDy=dFdy(vMapUv);';
  const sample=Array.from({length:slots},(_,i)=>`${i?'else ':''}if(nwnCmdMap==${i}) sampledDiffuseColor=${sampleAll?`nwnCmdSample${i}`:`textureGrad(nwnCmdMaps[${i}],${arrayPalette?'vec3(vMapUv,nwnCmdLayer)':'vMapUv'},nwnCmdDx,nwnCmdDy)`};`).join('\n');
  p.fragmentShader=(arrayPalette?'flat varying float nwnCmdLayer;\n':'')+'flat varying vec4 nwnCmdColor;\nflat varying vec3 nwnCmdEmission;\nflat varying int nwnCmdMap;\n'+p.fragmentShader
   .replace('#include <map_pars_fragment>',ShaderChunk.map_pars_fragment.replace('uniform sampler2D map;',`uniform ${arrayPalette?'highp sampler2DArray':'sampler2D'} nwnCmdMaps[${slots}];`))
   .replace('#include <map_fragment>',`#ifdef USE_MAP
 ${samples}
 vec4 sampledDiffuseColor=vec4(1.0);
 ${sample}
 diffuseColor*=sampledDiffuseColor;
#endif`)
   .replace('vec4 diffuseColor = vec4( diffuse, opacity );','vec4 diffuseColor=nwnCmdColor;')
   .replace('vec3 totalEmissiveRadiance = emissive;','vec3 totalEmissiveRadiance=nwnCmdEmission;');
 };
 material.customProgramCacheKey=()=>`nwn-command-batch-v1-${merged?'merged':'multi'}-${sampleAll?'implicit-all':'grad'}-${arrayPalette?'array':'2d'}-${slots}-${extension?.cacheKey??'plain'}`;
}
export class RendererCommandBatches{
 constructor(renderer,{enabled=false,merged=false,sampleAll=false,arrayPalette=false,samplerReserve=null,maxRows=4096,maxVertices=524288,maxMaps=4,maxMembers=256}={}){
  if(!Number.isInteger(maxRows)||maxRows<2||maxRows>16384||!Number.isInteger(maxVertices)||maxVertices<3||!Number.isInteger(maxMaps)||maxMaps<1||maxMaps>8||!Number.isInteger(maxMembers)||maxMembers<2||maxMembers>1024)throw Error('Invalid command batch capacity');
  Object.assign(this,{renderer,enabled,merged,sampleAll,arrayPalette,samplerReserve,maxRows,maxVertices,maxMaps,maxMembers});this.palettes=new RendererPaletteArrays({maxLayers:128,maxBytes:512*1024*1024,perTextureUV:true,compressed:true});const hardwareLayers=renderer.getContext().getParameter(renderer.getContext().MAX_ARRAY_TEXTURE_LAYERS);if(Number.isInteger(hardwareLayers)&&hardwareLayers>0)this.palettes.maxLayers=Math.min(128,hardwareLayers);this.stats={};this.lost=()=>this.reset();renderer.domElement?.addEventListener('webglcontextlost',this.lost);this.reset();
 }
 reset(){
  this.palettes?.reset();for(const batch of this.batches??[])batch.material.dispose();this.sentinel?.material.dispose();this.root?.removeFromParent();this.root=null;this.sentinel=null;this.geometry?.dispose();if(this.indexBuffer&&this.renderer.getContext().isBuffer(this.indexBuffer))this.renderer.getContext().deleteBuffer(this.indexBuffer);this.indexBuffer=null;this.transforms?.dispose();this.indirect?.dispose();this.data=null;this.indexData=null;
  this.batches=[];this.geometry=null;this.transforms=null;this.indirect=null;this.vertices=0;this.nextRow=0;this.rows=[];this.ranges=new WeakMap();this.instanceRanges=new WeakMap();this.descriptors=new WeakMap();this.textureFields=new WeakMap();this.extensions=new WeakMap();this.tokens=new WeakMap();this.serial=0;this.materialKeys=new WeakMap();this.disabled=false;this.failure=null;
 }
 initialize(){
  if(this.geometry)return;const limit=this.renderer.capabilities.maxTextureSize;if(limit<Math.max(16,this.maxRows))throw Error('Command texture capacity unsupported');
  this.geometry=new BufferGeometry();for(const [name,size]of [['position',3],['normal',3],['uv',2]])this.geometry.setAttribute(name,new Float32BufferAttribute(new Float32Array(this.maxVertices*size),size));this.geometry.boundingSphere=new Sphere(undefined,Infinity);
  this.data=new Float32Array(this.maxRows*rowSize);this.transforms=storage(this.data,16,this.maxRows,RGBAFormat,FloatType);this.indirect=storage(Uint32Array.from({length:this.maxRows},(_,i)=>i),this.maxRows,1,RedIntegerFormat,UnsignedIntType);
  if(this.merged){
   this.geometry.setAttribute('nwnCmdRowId',new Float32BufferAttribute(new Float32Array(this.maxVertices),1));this.indexData=new Uint32Array(this.maxVertices);const gl=this.renderer.getContext(),previous=gl.getParameter(gl.ELEMENT_ARRAY_BUFFER_BINDING);this.indexBuffer=gl.createBuffer();if(!this.indexBuffer)throw Error('Command index allocation failed');try{gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,this.indexBuffer);gl.bufferData(gl.ELEMENT_ARRAY_BUFFER,this.indexData.byteLength,gl.DYNAMIC_DRAW);}finally{gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,previous);}this.geometry.setIndex(new GLBufferAttribute(this.indexBuffer,gl.UNSIGNED_INT,1,4,this.maxVertices));
  }
  // Project an invisible owner so Three uploads appended geometry next frame.
  // New ranges retain their ordinary draw until that upload has happened.
  this.root=new Group();this.root.name='Experimental command geometry owner';this.root.matrixAutoUpdate=false;this.root.matrixWorldAutoUpdate=false;
  this.sentinel=new Mesh(this.geometry,new MeshBasicMaterial());this.sentinel.material.visible=false;this.sentinel.frustumCulled=false;this.sentinel.matrixAutoUpdate=false;this.sentinel.matrixWorldAutoUpdate=false;this.root.add(this.sentinel);
 }
 extension(m){
  const old=this.extensions.get(m);if(old&&old.before===m.onBeforeCompile&&old.key===m.customProgramCacheKey&&old.version===m.version)return old.value;
  let hook=m.onBeforeCompile,keyhole=null;const tokens=[];
  while(hook!==mb.onBeforeCompile){const d=rendererBatchHook(hook);if(!d||!['target-preview','keyhole'].includes(d.kind)||tokens.includes(d.token))return undefined;tokens.push(d.token);if(d.kind==='keyhole'){if(keyhole)return undefined;keyhole=d;}hook=d.before;}
  if(tokens.length&&!isLocalRendererHook(m.customProgramCacheKey)||!tokens.length&&m.customProgramCacheKey!==mb.customProgramCacheKey)return undefined;
  const key=m.customProgramCacheKey(),ids=tokens.map(t=>{if(!this.tokens.has(t))this.tokens.set(t,++this.serial);return this.tokens.get(t);}).join(','),before=m.onBeforeCompile,value=tokens.length?{id:ids+'|'+key,cacheKey:key,keyhole,compile:(p,r)=>before.call(m,p,r)}:null;
  this.extensions.set(m,{before,key:m.customProgramCacheKey,version:m.version,value});return value;
 }
 descriptor(item){
  const {object:o,geometry:g,material:m,group}=item,e=this.extension(m),hook=rendererBatchHook(o.onBeforeRender);
  if(e===undefined||!o.isMesh||o.isSkinnedMesh||o.isInstancedMesh||o.isBatchedMesh||o.children.length||o.userData.animationOwnedGeometry||o.onAfterRender!==ob.onAfterRender||!m.isMeshLambertMaterial||!m.visible||m.transparent||m.wireframe||m.vertexColors||m.alphaHash||m.stencilWrite||m.clippingPlanes?.length||m.defines||m.uniforms||m.onBeforeRender!==mb.onBeforeRender||!Number.isFinite(m.alphaTest)||g.index||g.isInstancedBufferGeometry||maps.some(k=>m[k]))return null;
  if(e?.keyhole?hook?.kind!=='keyhole-state'||hook.token!==e.keyhole.token||hook.can!==e.keyhole.can:o.onBeforeRender!==ob.onBeforeRender)return null;
  if(!(o.matrixWorld.determinant()>0)||!o.matrixWorld.elements.every(Number.isFinite))return null;
  for(const name in g.morphAttributes)if(g.morphAttributes[name]?.length)return null;
  for(const [name,size]of streams){const a=g.attributes[name];if(!a||a.itemSize!==size||a.normalized||a.isInterleavedBufferAttribute||a.isInstancedBufferAttribute||a.version>(name==='normal'?1:0)||!(a.array instanceof Float32Array))return null;}
  const count=g.attributes.position.count;if(g.attributes.normal.count!==count||g.attributes.uv.count!==count)return null;
  const start=Math.max(0,g.drawRange.start,group?.start??0),end=Math.min(count,g.drawRange.start+g.drawRange.count,group?group.start+group.count:Infinity),length=Math.max(0,end-start);if(start%3||length%3||!Number.isInteger(start)||!Number.isInteger(length)||length===0)return null;
  const map=m.map;if(map&&(!map.isTexture||map.isVideoTexture||map.isCubeTexture||map.isDataArrayTexture||map.isData3DTexture||map.isRenderTargetTexture||map.channel!==0||!map.image||map.onUpdate))return null;
  let key=this.materialKeys.get(m),same=key&&key.map===Boolean(map)&&key.receiveShadow===o.receiveShadow&&key.extension===(e?.id??'');
  if(same)for(let i=0;i<fields.length;i++)if(!Object.is(key.values[i],m[fields[i]])){same=false;break;}
  if(same)same=key.values[fields.length]===m.blendColor.r&&key.values[fields.length+1]===m.blendColor.g&&key.values[fields.length+2]===m.blendColor.b;
  if(!same){const values=fields.map(f=>m[f]);values.push(m.blendColor.r,m.blendColor.g,m.blendColor.b);key={values,map:Boolean(map),receiveShadow:o.receiveShadow,extension:e?.id??'',value:[Boolean(map),o.receiveShadow,e?.id??'',...values].join('|')};this.materialKeys.set(m,key);}
  let descriptor=this.descriptors.get(item);if(!descriptor){descriptor={};this.descriptors.set(item,descriptor);}descriptor.item=item;descriptor.key=key.value;descriptor.start=start;descriptor.count=length;descriptor.extension=e;descriptor.map=map;return descriptor;
 }
 range(d){
  if(this.merged)return this.instanceRange(d);
  const g=d.item.geometry,attributes=g.attributes,old=this.ranges.get(g),keys=['position','normal','uv'];if(old&&keys.every(k=>old.attributes[k]===attributes[k]&&old.versions[k]===attributes[k].version))return old.born<this.renderer.info.render.frame?old.start+d.start:null;
  const count=attributes.position.count;if(this.vertices+count>this.maxVertices)return null;const start=this.vertices;
  for(const k of keys){const a=this.geometry.attributes[k],source=attributes[k];a.array.set(source.array,start*a.itemSize);a.addUpdateRange(start*a.itemSize,count*a.itemSize);a.needsUpdate=true;}
  this.vertices+=count;this.ranges.set(g,{start,born:this.renderer.info.render.frame,attributes:Object.fromEntries(keys.map(k=>[k,attributes[k]])),versions:Object.fromEntries(keys.map(k=>[k,attributes[k].version]))});this.stats.geometryUploads++;return null;
 }
 instanceRange(d){
  const o=d.item.object,g=d.item.geometry,a=g.attributes;let ranges=this.instanceRanges.get(o);if(!ranges)this.instanceRanges.set(o,ranges=[]);
  let old,slot=-1;for(let i=0;i<ranges.length;i++){const r=ranges[i];if(r.geometry===g&&r.material===d.item.material&&r.sourceStart===d.start&&r.count===d.count){old=r;slot=i;break;}}
  let valid=Boolean(old);if(valid)for(const k of streamNames)if(old.attributes[k]!==a[k]||old.versions[k]!==a[k].version){valid=false;break;}
  if(valid){d.row=old.row;d.range=old;return old.born<this.renderer.info.render.frame?old.start:null;}
  if(this.vertices+d.count>this.maxVertices||this.nextRow>=this.maxRows)return null;
  const start=this.vertices,row=this.nextRow++;
  for(const k of streamNames){const target=this.geometry.attributes[k],source=a[k],size=target.itemSize;target.array.set(source.array.subarray(d.start*size,(d.start+d.count)*size),start*size);target.addUpdateRange(start*size,d.count*size);target.needsUpdate=true;}
  const rowAttribute=this.geometry.attributes.nwnCmdRowId;rowAttribute.array.fill(row,start,start+d.count);rowAttribute.addUpdateRange(start,d.count);rowAttribute.needsUpdate=true;
  const record={geometry:g,material:d.item.material,sourceStart:d.start,count:d.count,start,row,born:this.renderer.info.render.frame,attributes:Object.fromEntries(streamNames.map(k=>[k,a[k]])),versions:Object.fromEntries(streamNames.map(k=>[k,a[k].version]))};if(slot<0)ranges.push(record);else ranges[slot]=record;d.row=row;d.range=record;this.vertices+=d.count;this.stats.geometryUploads++;return null;
 }
 create(d,slots){
  const material=d.item.material.clone(),uniforms={nwnCmdOffset:{value:0},nwnCmdMaps:{value:Array(slots).fill(d.map)},batchingTexture:{value:this.transforms}};installShader(material,uniforms,slots,d.extension,this.merged,this.sampleAll,this.arrayPalette);
  const proxy=new Mesh(this.geometry,material);proxy.frustumCulled=false;proxy.matrixAutoUpdate=false;proxy.matrixWorldAutoUpdate=false;proxy.receiveShadow=d.item.object.receiveShadow;proxy.castShadow=false;proxy.isBatchedMesh=true;proxy.colorTexture=null;proxy._colorsTexture=null;proxy._matricesTexture=this.transforms;proxy._indirectTexture=this.indirect;proxy._multiDrawStarts=new Int32Array(this.maxMembers);proxy._multiDrawCounts=new Int32Array(this.maxMembers);proxy._multiDrawInstances=null;proxy._multiDrawCount=0;
  if(this.merged)proxy.isBatchedMesh=false;
  return{material,proxy,uniforms,key:d.key,slots,indices:[]};
 }
 fillRow(index,d,camera,scene,mapIndex){
  const o=d.item.object,m=d.item.material,offset=index*rowSize;let row=this.rows[index];
  if(!row||row.object!==o){row={object:o,world:new Float64Array(16),camera:new Float64Array(16),valid:false,view:new Matrix4(),normal:new Matrix3()};this.rows[index]=row;}
  if(d.extension?.keyhole)o.onBeforeRender(this.renderer,scene,camera,d.item.geometry,m,d.item.group);
  let changed=false,matrixChanged=!row.valid;const data=this.data;for(let i=0;i<16&&!matrixChanged;i++)matrixChanged=o.matrixWorld.elements[i]!==row.world[i]||camera.matrixWorldInverse.elements[i]!==row.camera[i];
  if(matrixChanged){
   row.view.multiplyMatrices(camera.matrixWorldInverse,o.matrixWorld);row.normal.getNormalMatrix(row.view);row.world.set(o.matrixWorld.elements);row.camera.set(camera.matrixWorldInverse.elements);row.valid=true;
   for(let i=0;i<16;i++){changed=put(data,offset,i,row.view.elements[i])||changed;changed=put(data,offset,28+i,o.matrixWorld.elements[i])||changed;}for(let i=0;i<9;i++)changed=put(data,offset,16+Math.floor(i/3)*4+i%3,row.normal.elements[i])||changed;this.stats.matrixUpdates++;
  }
  changed=put(data,offset,44,m.color.r)||changed;changed=put(data,offset,45,m.color.g)||changed;changed=put(data,offset,46,m.color.b)||changed;changed=put(data,offset,47,m.opacity)||changed;
  changed=put(data,offset,48,m.emissive.r*m.emissiveIntensity)||changed;changed=put(data,offset,49,m.emissive.g*m.emissiveIntensity)||changed;changed=put(data,offset,50,m.emissive.b*m.emissiveIntensity)||changed;changed=put(data,offset,51,mapIndex)||changed;
  if(d.map?.matrixAutoUpdate)d.map.updateMatrix();const uv=d.map?.matrix.elements??identityUv;for(let i=0;i<9;i++)changed=put(data,offset,52+Math.floor(i/3)*4+i%3,uv[i])||changed;changed=put(data,offset,55,d.extension?.keyhole?.can.value??0)||changed;if(this.arrayPalette){changed=put(data,offset,59,d.palette?.uvScale[0]??1)||changed;changed=put(data,offset,63,d.palette?.uvScale[1]??1)||changed;}
  return changed;
 }
 uploadHook(material){
  let schema=this.textureFields.get(material);if(!schema||schema.version!==material.version){schema={version:material.version,keys:Object.keys(material).filter(k=>material[k]==null||material[k]?.isTexture)};this.textureFields.set(material,schema);}
  for(const k of schema.keys)if(material[k]?.isTexture&&material[k].onUpdate)return true;
  for(const key in material.uniforms){const value=material.uniforms[key]?.value;if(value?.isTexture&&value.onUpdate||Array.isArray(value)&&value.some(v=>v?.isTexture&&v.onUpdate))return true;}return false;
 }
 patch(list,camera,scene,slots){
  const original=list.opaque,result=[];this.stats={originalDraws:original.length,draws:original.length,batches:0,instances:0,geometryUploads:0,matrixUpdates:0,textureUploads:0,indexUploads:0};
  const unknown=(hook,base)=>hook!==base&&!isLocalRendererHook(hook);
  if(list.transmissive.length||[...original,...list.transparent].some(({object:o,material:m})=>unknown(o.onBeforeRender,ob.onBeforeRender)||o.onAfterRender!==ob.onAfterRender||m.onBeforeRender!==mb.onBeforeRender||unknown(m.onBeforeCompile,mb.onBeforeCompile)||unknown(m.customProgramCacheKey,mb.customProgramCacheKey)||this.uploadHook(m))){this.stats.fallback='render-callback';return()=>{};}
  if(this.arrayPalette)this.palettes.beginPass();this.initialize();if(this.root.parent!==scene)scene.add(this.root);this.sentinel.layers.mask=camera.layers.mask;let members=[],textures=[],key=null,used=0,rowIndex=0,indexOffset=0,indexStart=Infinity,indexEnd=0,dirty=false;
  const flush=()=>{if(!members.length)return;if(members.length<2||!this.merged&&rowIndex+members.length>this.maxRows){result.push(...members.map(d=>d.item));}else{
   let b=this.batches[used];if(b&&(b.key!==key||b.slots!==slots)){b.material.dispose();b=null;}if(!b)this.batches[used]=b=this.create(members[0],slots);used++;
   b.uniforms.nwnCmdOffset.value=rowIndex;for(let i=0;i<slots;i++)b.uniforms.nwnCmdMaps.value[i]=textures[i]??textures[0]??null;
   let group=null;if(this.merged){let count=0;for(const d of members)count+=d.count;if(indexOffset+count>this.maxVertices){result.push(...members.map(d=>d.item));members.length=0;textures.length=0;key=null;return;}const changed=b.indexOffset!==indexOffset||b.indices.length!==members.length||members.some((d,i)=>b.indices[i]!==d.range);if(changed){let at=indexOffset;for(const d of members)for(let i=0;i<d.count;i++)this.indexData[at++]=d.atlasStart+i;indexStart=Math.min(indexStart,indexOffset);indexEnd=Math.max(indexEnd,indexOffset+count);b.indices=members.map(d=>d.range);b.indexOffset=indexOffset;}group=b.group??={};group.start=indexOffset;group.count=count;indexOffset+=count;}
   for(let i=0;i<members.length;i++){const d=members[i];b.proxy._multiDrawStarts[i]=d.atlasStart;b.proxy._multiDrawCounts[i]=d.count;dirty=this.fillRow(this.merged?d.row:rowIndex+i,d,camera,scene,this.arrayPalette?Math.max(-1,textures.indexOf(d.tableMap))+(d.palette?.layer??0)*slots:textures.indexOf(d.map))||dirty;}
   b.proxy._multiDrawCount=members.length;b.proxy.layers.mask=camera.layers.mask;rowIndex+=members.length;b.renderItem??={};Object.assign(b.renderItem,members[0].item,{object:b.proxy,material:b.material,geometry:this.geometry,group});result.push(b.renderItem);this.stats.batches++;this.stats.instances+=members.length;
  }members.length=0;textures.length=0;key=null;};
  for(const item of original){const d=this.descriptor(item);if(!d){flush();result.push(item);continue;}if(this.arrayPalette){d.palette=d.map&&d.map.version>0?this.palettes.get(d.map):null;if(d.map&&!d.palette){flush();result.push(item);continue;}d.tableMap=d.palette?.array.texture??null;}else d.tableMap=d.map;const atlasStart=this.range(d);if(atlasStart===null){flush();result.push(item);continue;}d.atlasStart=atlasStart;
   if(key!==null&&(key!==d.key||members.length===this.maxMembers||d.tableMap&&!textures.includes(d.tableMap)&&textures.length===slots))flush();key=d.key;if(d.tableMap&&!textures.includes(d.tableMap))textures.push(d.tableMap);members.push(d);
  }flush();if(dirty){this.transforms.needsUpdate=true;this.stats.textureUploads++;}if(indexEnd>indexStart){const gl=this.renderer.getContext(),previous=gl.getParameter(gl.COPY_WRITE_BUFFER_BINDING);try{gl.bindBuffer(gl.COPY_WRITE_BUFFER,this.indexBuffer);gl.bufferSubData(gl.COPY_WRITE_BUFFER,indexStart*4,this.indexData,indexStart,indexEnd-indexStart);this.stats.indexUploads++;}finally{gl.bindBuffer(gl.COPY_WRITE_BUFFER,previous);}}
  if(!this.merged)this.rows.length=rowIndex;while(this.batches.length>used)this.batches.pop().material.dispose();this.palettes.endPass();this.stats.draws=result.length;list.opaque=result;return()=>{list.opaque=original;};
 }
 render(scene,camera,draw=()=>this.renderer.render(scene,camera)){
  if(!this.enabled||this.disabled||this.running||scene.overrideMaterial||scene.onBeforeRender!==ob.onBeforeRender||scene.onAfterRender!==ob.onAfterRender||camera.isArrayCamera||this.renderer.xr?.enabled||this.renderer.clippingPlanes?.length)return draw();
  const renderer=this.renderer,map=renderer.shadowMap,original=map.render;let restore;this.running=true;
  map.render=(lights,s,c)=>{const answer=original.call(map,lights,s,c);if(s===scene&&c===camera&&!restore){let extraMaps=this.samplerReserve?.();if(!Number.isInteger(extraMaps)||extraMaps<0){extraMaps=0;scene.traverseVisible(o=>{if(o.isLight&&o.layers.test(camera.layers))extraMaps+=Number(Boolean(o.isSpotLight&&o.map))+(o.isRectAreaLight?2:0);});}const slots=Math.min(this.maxMaps,renderer.capabilities.maxTextures-2-lights.length-extraMaps);if(slots>=1){try{restore=this.patch(renderer.renderLists.get(scene,0),camera,scene,slots);}catch(e){this.reset();this.disabled=true;this.failure=String(e);}}else this.stats={fallback:'sampler-budget'};}return answer;};
  try{return draw();}finally{restore?.();map.render=original;this.running=false;}
 }
 snapshot(){return{...this.stats,enabled:this.enabled,merged:this.merged,sampleAll:this.sampleAll,arrayPalette:this.arrayPalette,palettes:this.palettes.snapshot(),disabled:this.disabled,failure:this.failure,cachedBatches:this.batches.length,vertices:this.vertices,rows:this.rows.length,bytes:this.geometry?this.maxVertices*(this.merged?40:32)+this.maxRows*(rowSize*4+4):0,multiDraw:Boolean(this.renderer.extensions.has('WEBGL_multi_draw'))};}
 dispose(){this.renderer.domElement?.removeEventListener('webglcontextlost',this.lost);this.reset();this.enabled=false;}
}
