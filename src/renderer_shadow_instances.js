import {InstancedMesh,GLBufferAttribute,MeshDepthMaterial,MeshDistanceMaterial,RGBADepthPacking,Object3D,Matrix4,Sphere,RGBAFormat,UnsignedByteType,FrontSide,BackSide,DoubleSide} from 'three';
const same=(a,b)=>a.length===b.length&&a.every((value,i)=>value===b[i]);
const bytes=array=>new Uint8Array(array.buffer,array.byteOffset,array.byteLength);
const copy=array=>bytes(array).slice();
const hash=arrays=>{let h=2166136261;for(const a of arrays)for(const n of a)h=Math.imul(h^n,16777619);return(h>>>0).toString(16);};
const geometryAttributes=['position','uv','uv1','uv2','uv3'];
export function createShadowInstanceMaterial(point){const material=point?new MeshDistanceMaterial():new MeshDepthMaterial({depthPacking:RGBADepthPacking});material.onBeforeCompile=shader=>{if(!shader.vertexShader.includes('#include <project_vertex>'))throw Error('Shadow instance projection stage is unavailable');shader.vertexShader='attribute mat4 nwnShadowModelView;\n#undef USE_INSTANCING\n#define modelViewMatrix nwnShadowModelView\n'+shader.vertexShader;if(point)shader.vertexShader=shader.vertexShader.replace('#include <worldpos_vertex>','vec4 worldPosition = instanceMatrix * vec4( transformed, 1.0 );');};material.customProgramCacheKey=()=>`nwn-shadow-instance-projection-v2-${point}`;return material;}

// Shadow-only proxies. Originals remain in the live hierarchy and retain their
// matrices, materials, picking, highlighting, animation and render callbacks.
export class RendererShadowInstances{
 constructor(renderer){this.renderer=renderer;this.gl=renderer.getContext();this.orphanUploads=false;this.reset();}
 reset(){for(const group of this.groups?.values()??[])this.destroy(group);this.groups=new Map();this.proxyGroups=new WeakMap();this.members=new Map();this.frameKeys=new Map();this.frameTextureKeys=new WeakMap();this.inBegin=false;this.geometries=new WeakMap();this.textures=new WeakMap();this.geometryBuckets=new Map();this.alphaBuckets=new Map();this.ids=new WeakMap();this.serial=0;this.frame=0;this.disabled=false;this.failure=null;this.stats={groups:0,instances:0,originalDraws:0,proxyDraws:0,uploads:0};}
 id(value){if(!value)return 0;let id=this.ids.get(value);if(!id){id=++this.serial;this.ids.set(value,id);}return id;}
 canonical(buckets,key,data){let rows=buckets.get(key);if(!rows)buckets.set(key,rows=[]);let row=rows.find(row=>row.data.length===data.length&&row.data.every((a,i)=>same(a,data[i])));if(!row){row={id:++this.serial,data};rows.push(row);}return row.id;}
 geometry(geometry){
  for(const name in geometry.morphAttributes)if(geometry.morphAttributes[name]?.length)return null;
  const index=geometry.index;let record=this.geometries.get(geometry);
  if(record&&record.index===index&&record.indexArray===index?.array&&record.indexCount===index?.count&&(index?.version??0)===0&&record.start===geometry.drawRange.start&&record.count===geometry.drawRange.count){
   let matches=true;for(let i=0;i<geometryAttributes.length;i++){const a=geometry.attributes[geometryAttributes[i]];if(a!==record.attributes[i]||a&&(a.array!==record.arrays[i]||a.count!==record.counts[i]||a.version!==0||a.normalized||a.itemSize!==(i===0?3:2)||a.isInterleavedBufferAttribute)){matches=false;break;}}if(matches)return record.id;
  }
  const attributes=geometryAttributes.map(name=>geometry.attributes[name]),p=attributes[0];
  if(!p||attributes.some((a,i)=>a&&(a.itemSize!==(i===0?3:2)||a.normalized||a.version!==0||a.isInterleavedBufferAttribute||!(a.array instanceof Float32Array)))||index&&(index.isInterleavedBufferAttribute||index.version!==0))return null;
  const data=[...attributes.filter(Boolean).map(a=>copy(a.array)),...(index?[copy(index.array)]:[])],key=[...attributes.map(a=>a?.count??-1),index?.array.constructor.name??'',index?.count??-1,geometry.drawRange.start,geometry.drawRange.count,hash(data)].join(':');
  const id=this.canonical(this.geometryBuckets,key,data);this.geometries.set(geometry,{id,attributes,arrays:attributes.map(a=>a?.array),counts:attributes.map(a=>a?.count),index,indexArray:index?.array,indexCount:index?.count,start:geometry.drawRange.start,count:geometry.drawRange.count});return id;
 }
 texture(texture){
  if(!texture)return'0';
  if(this.inBegin){const key=this.frameTextureKeys.get(texture);if(key!==undefined)return key;}
  let identity=this.id(texture);const image=texture.image;
  // Color does not enter the default depth/distance alpha test. Compare every
  // alpha byte before sharing across palette images; compressed/manual mip or
  // custom formats retain their exact texture identity.
  if(texture.isDataTexture&&!texture.isRenderTargetTexture&&texture.version<=1&&texture.source?.version<=1&&texture.format===RGBAFormat&&texture.type===UnsignedByteType&&!texture.mipmaps.length&&image?.data instanceof Uint8Array&&image.data.length===image.width*image.height*4){
   const stamp=[texture.version,texture.source?.version,image,image.data,image.width,image.height];let record=this.textures.get(texture);
   if(!record||!same(stamp,record.stamp)){const alpha=new Uint8Array(image.width*image.height);for(let i=0;i<alpha.length;i++)alpha[i]=image.data[i*4+3];identity=this.canonical(this.alphaBuckets,`${image.width}:${image.height}:${hash([alpha])}`,[alpha]);record={stamp,id:identity};this.textures.set(texture,record);}else identity=record.id;
  }
  const key=[identity,texture.format,texture.type,texture.internalFormat,texture.mapping,texture.channel,texture.colorSpace,texture.wrapS,texture.wrapT,texture.minFilter,texture.magFilter,texture.anisotropy,texture.flipY,texture.premultiplyAlpha,texture.unpackAlignment,texture.generateMipmaps,texture.matrixAutoUpdate,texture.offset.x,texture.offset.y,texture.repeat.x,texture.repeat.y,texture.center.x,texture.center.y,texture.rotation,...texture.matrix.elements].join(',');if(this.inBegin)this.frameTextureKeys.set(texture,key);return key;
 }
 key(object){
  const material=object.material;
  if(!object.isMesh||object.isSkinnedMesh||object.isInstancedMesh||object.isBatchedMesh||object.userData.animationOwnedGeometry||'boundingSphere' in object||object.children.length||object.customDepthMaterial||object.customDistanceMaterial||object.onBeforeShadow!==Object3D.prototype.onBeforeShadow||object.onAfterShadow!==Object3D.prototype.onAfterShadow||!material||Array.isArray(material)||material.isShaderMaterial||!material.visible||material.wireframe||material.clippingPlanes?.length||material.displacementMap)return null;
  const determinant=object.matrixWorld.determinant();if(!Number.isFinite(determinant)||determinant<0)return null;
  const geometry=this.geometry(object.geometry);if(geometry===null)return null;
  const alpha=material.alphaToCoverage?0.5:material.alphaTest;
  const side=material.shadowSide!==null?material.shadowSide:material.side===FrontSide?BackSide:material.side===BackSide?FrontSide:material.side;
  if(![FrontSide,BackSide,DoubleSide].includes(side)||!Number.isFinite(alpha))return null;
  return[geometry,object.layers.mask,side,alpha,alpha>0?this.texture(material.map):'0',alpha>0?this.id(material.alphaMap):0,material.alphaToCoverage].join('|');
 }
 collect(entries){
  this.frameTextureKeys=new WeakMap();this.inBegin=true;try{for(const entry of entries){if(this.frameKeys.has(entry))continue;const key=this.key(entry.object);this.frameKeys.set(entry,key);if(key!==null){let members=this.members.get(key);if(!members)this.members.set(key,members=[]);members.push(entry);}}}finally{this.inBegin=false;}
 }
 prune(){for(const [key,group]of this.groups)if((this.members.get(key)?.length??0)<2){this.destroy(group);this.groups.delete(key);}}
 begin(entries,{lazy=false}={}){
  this.frame++;this.stats={groups:0,instances:0,originalDraws:0,proxyDraws:0,uploads:0};this.members=new Map();this.frameKeys=new Map();
  this.lazy=lazy;
  if(this.disabled)return;
  if(lazy)return;
  this.collect(entries);
  // No grouping for singletons. Unused owned buffers/materials are released
  // at this frame boundary, never by mutating the original model geometry.
  this.prune();
 }
 end(){if(this.lazy)this.prune();}
 create(key,members){
  const first=members[0].object,capacity=2**Math.ceil(Math.log2(members.length)),geometry=first.geometry.clone(),proxy=new InstancedMesh(geometry,first.material,capacity),gl=this.gl,previous=gl.getParameter(gl.COPY_WRITE_BUFFER_BINDING);
  const allocate=()=>{const buffer=gl.createBuffer();if(!buffer)throw Error('Shadow instance buffer allocation failed');gl.bindBuffer(gl.COPY_WRITE_BUFFER,buffer);gl.bufferData(gl.COPY_WRITE_BUFFER,capacity*64,gl.DYNAMIC_DRAW);const attribute=new GLBufferAttribute(buffer,gl.FLOAT,16,4,capacity);attribute.isInstancedBufferAttribute=true;attribute.meshPerAttribute=1;return attribute;};
  let world,modelView;try{world=allocate();modelView=allocate();}catch(error){for(const attribute of [world,modelView])if(attribute&&gl.isBuffer(attribute.buffer))gl.deleteBuffer(attribute.buffer);proxy.dispose();geometry.dispose();throw error;}finally{gl.bindBuffer(gl.COPY_WRITE_BUFFER,previous);}
  // Three uploads ordinary attributes only once per frame. These supported
  // external VBO attributes are instead updated for every shadow face, through
  // COPY_WRITE_BUFFER so active VAO/ARRAY_BUFFER bindings remain untouched.
  proxy.instanceMatrix=world;geometry.setAttribute('nwnShadowModelView',modelView);
  proxy.customDepthMaterial=createShadowInstanceMaterial(false);proxy.customDistanceMaterial=createShadowInstanceMaterial(true);proxy.castShadow=true;proxy.layers.mask=first.layers.mask;proxy.matrixAutoUpdate=false;proxy.matrixWorldAutoUpdate=false;proxy.matrixWorld.identity();
  const group={key,proxy,geometry,world,modelView,worldData:new Float32Array(capacity*16),viewData:new Float32Array(capacity*16),capacity,entries:[],light:null,view:new Matrix4(),preparedView:new Matrix4(),lastCamera:null,frame:-1,sphere:new Sphere(undefined,Infinity)};
  // Three queries the proxy sphere before drawing. This shadow-only
  // visibility gate uploads the exact current face transforms, then
  // admits the proxy; individual members use the original light frustum.
  Object.defineProperty(proxy,'boundingSphere',{get:()=>{this.prepare(group);return group.sphere;},configurable:true});
  this.groups.set(key,group);this.proxyGroups.set(proxy,group);return group;
 }
 prepare(group){
  const {proxy,light}=group;if(!light)return;
  const camera=light.shadow.camera;
  if(group.frame===this.frame&&group.lastCamera===camera&&group.preparedView.equals(camera.matrixWorldInverse))return;
  group.frame=this.frame;group.lastCamera=camera;group.preparedView.copy(camera.matrixWorldInverse);let count=0;
  for(const entry of group.entries){if(entry.sphere&&!light.shadow.getFrustum().intersectsSphere(entry.sphere))continue;const object=entry.object,at=count++*16;group.worldData.set(object.matrixWorld.elements,at);object.modelViewMatrix.multiplyMatrices(camera.matrixWorldInverse,object.matrixWorld);group.viewData.set(object.modelViewMatrix.elements,at);}
  proxy.count=count;if(count===0)return;const gl=this.gl,previous=gl.getParameter(gl.COPY_WRITE_BUFFER_BINDING);try{gl.bindBuffer(gl.COPY_WRITE_BUFFER,group.world.buffer);if(this.orphanUploads)gl.bufferData(gl.COPY_WRITE_BUFFER,group.capacity*64,gl.DYNAMIC_DRAW);gl.bufferSubData(gl.COPY_WRITE_BUFFER,0,group.worldData,0,count*16);gl.bindBuffer(gl.COPY_WRITE_BUFFER,group.modelView.buffer);if(this.orphanUploads)gl.bufferData(gl.COPY_WRITE_BUFFER,group.capacity*64,gl.DYNAMIC_DRAW);gl.bufferSubData(gl.COPY_WRITE_BUFFER,0,group.viewData,0,count*16);}finally{gl.bindBuffer(gl.COPY_WRITE_BUFFER,previous);}this.stats.uploads++;
 }
 list(entries,light){
  if(this.disabled)return entries.map(entry=>entry.object);
  if(this.lazy)this.collect(entries);
  const keys=new Map(),eligible=new Map();for(const entry of entries){const key=this.frameKeys.get(entry);if(key!==null&&key!==undefined&&this.members.get(key)?.length>=2){let rows=keys.get(key);if(!rows)keys.set(key,rows=[]);rows.push(entry);eligible.set(entry,key);}}
  const emitted=new Set(),result=[];
  for(const entry of entries){const key=eligible.get(entry),members=keys.get(key);if(key===undefined||members.length<2){result.push(entry.object);continue;}if(emitted.has(key))continue;emitted.add(key);let group=this.groups.get(key);if(!group||group.capacity<members.length){if(group){this.destroy(group);this.groups.delete(key);}try{group=this.create(key,members);}catch{this.reset();this.disabled=true;this.failure='resource-allocation';return entries.map(entry=>entry.object);}}group.entries=members;group.light=light;group.frame=-1;group.proxy.material=members[0].object.material;group.proxy.layers.mask=members[0].object.layers.mask;result.push(group.proxy);this.stats.groups++;this.stats.instances+=members.length;}
  this.stats.originalDraws+=entries.length;this.stats.proxyDraws+=result.length;return result;
 }
 destroy(group){group.proxy.dispose();group.geometry.dispose();group.proxy.customDepthMaterial.dispose();group.proxy.customDistanceMaterial.dispose();for(const attribute of [group.world,group.modelView])if(this.gl.isBuffer(attribute.buffer))this.gl.deleteBuffer(attribute.buffer);group.entries=[];group.light=null;}
 dispose(){this.reset();}
 sourcesFor(proxy){return this.proxyGroups.get(proxy)?.entries.map(entry=>entry.object);}
 snapshot(){return{...this.stats,cachedGroups:this.groups.size,geometryKeys:this.geometryBuckets.size,alphaKeys:this.alphaBuckets.size,currentMembers:this.frameKeys.size,disabled:this.disabled,failure:this.failure};}
}
