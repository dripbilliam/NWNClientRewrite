import {Mesh,MeshBasicMaterial,BufferGeometry,Float32BufferAttribute,Uint32BufferAttribute,GLBufferAttribute,DataTexture,RGBAFormat,FloatType,NearestFilter,MeshDistanceMaterial,MeshDepthMaterial,RGBADepthPacking,Matrix4,Sphere,FrontSide,BackSide} from 'three';
import {RendererShadowInstances} from './renderer_shadow_instances.js';

export function createShadowAtlasMaterial(point,texture){
 const material=point?new MeshDistanceMaterial():new MeshDepthMaterial({depthPacking:RGBADepthPacking});
 material.onBeforeCompile=shader=>{
  if(!shader.vertexShader.includes('#include <project_vertex>'))throw Error('Shadow atlas projection hook changed');
  shader.uniforms.nwnShadowMatrices={value:texture};
  shader.vertexShader=`attribute float nwnShadowObject;\nuniform highp sampler2D nwnShadowMatrices;\nmat4 nwnShadowMatrix(int start){int row=int(nwnShadowObject);return mat4(texelFetch(nwnShadowMatrices,ivec2(start,row),0),texelFetch(nwnShadowMatrices,ivec2(start+1,row),0),texelFetch(nwnShadowMatrices,ivec2(start+2,row),0),texelFetch(nwnShadowMatrices,ivec2(start+3,row),0));}\n#define modelMatrix nwnAtlasWorld\n#define modelViewMatrix nwnAtlasView\n`+shader.vertexShader
   .replace('void main() {','void main() {\nmat4 nwnAtlasWorld=nwnShadowMatrix(0);mat4 nwnAtlasView=nwnShadowMatrix(4);');
 };
 material.customProgramCacheKey=()=>`nwn-shadow-geometry-atlas-v1-${point}`;return material;
}

// EXPERIMENT: shadow-only geometry atlas. Unlike instancing, different rigid
// meshes share a draw. Every vertex retains its original local coordinates;
// exact Float32 world/model-view matrices are supplied for each shadow face.
// Sources, hierarchy, picking, animation and main materials stay untouched.
export class RendererShadowAtlas {
 constructor(renderer,{maxObjects=1024,maxBytes=128*1024*1024,multiDraw=true}={}){
  this.renderer=renderer;this.gl=renderer.getContext();this.maxObjects=Math.min(maxObjects,renderer.capabilities?.maxTextureSize??0);this.maxBytes=maxBytes;
  this.multiDraw=multiDraw?this.gl.getExtension('WEBGL_multi_draw'):null;this.keys=new RendererShadowInstances(renderer);this.groups=new Map();this.frame=0;this.running=false;this.disabled=this.maxObjects<2;this.failure=null;this.bytes=0;this.stats={};
 }
 begin(entries){
  if(this.running)throw Error('Nested shadow atlas frame');this.frame++;this.stats={groups:0,instances:0,originalDraws:0,proxyDraws:0,uploads:0,multiDraws:0,indexUploads:0};this.keys.begin(entries,{lazy:true});
  this.before=this.renderer.renderBufferDirect;const owner=this;
  this.hook=function(camera,scene,geometry,material,object,group){
   const atlas=object.userData.nwnShadowAtlas;
   if(atlas?.owner===owner&&atlas.geometry.drawRange.count===0)return;
   if(!atlas||atlas.owner!==owner||!owner.multiDraw)return owner.before.call(this,camera,scene,geometry,material,object,group);
   const gl=owner.gl,previous=gl.drawElements;
   gl.drawElements=function(mode,_count,type,_offset){owner.multiDraw.multiDrawElementsWEBGL(mode,atlas.counts,0,type,atlas.starts,0,atlas.multiCount);owner.stats.multiDraws++;};
   try{return owner.before.call(this,camera,scene,geometry,material,object,group);}finally{gl.drawElements=previous;}
  };
  this.renderer.renderBufferDirect=this.hook;this.running=true;
 }
 end(){
  if(this.running&&this.renderer.renderBufferDirect===this.hook)this.renderer.renderBufferDirect=this.before;this.running=false;
  for(const[key,group]of this.groups)if(group.used!==this.frame){this.destroy(group);this.groups.delete(key);}this.keys.end();
 }
 shape(entry){
  const key=this.keys.frameKeys.get(entry);if(key===null||key===undefined)return null;
  // Front-facing point-shadow surfaces differ by one Float32 depth ULP in an
  // authored case on the current GPU. Preserve their original shader/draw;
  // the ordinary front-sided material's back-facing shadow path stays eligible.
  const material=entry.object.material,side=material.shadowSide??(material.side===FrontSide?BackSide:material.side===BackSide?FrontSide:material.side);if(side!==BackSide)return null;
  const geometry=entry.object.geometry,p=geometry.attributes.position,index=geometry.index,range=geometry.drawRange;
  if(!Number.isInteger(range.start)||range.start<0||range.count!==Infinity&&(!Number.isInteger(range.count)||range.count<0)||index&&!([Uint8Array,Uint16Array,Uint32Array].some(Type=>index.array instanceof Type)))return null;
  for(const name of ['uv','uv1','uv2','uv3'])if(geometry.attributes[name]&&geometry.attributes[name].count!==p.count)return null;
  const start=range.start,count=Math.max(0,Math.min(index?.count??p.count,start+range.count)-start);
  if(!count||p.count>1000000)return null;const split=key.indexOf('|');
  return{entry,key:key.slice(split+1),geometryId:key.slice(0,split),start,count:Math.floor(count/3)*3};
 }
 list(entries,light){
  if(this.disabled)return entries.map(e=>e.object);this.keys.collect(entries);
  // Keep the complete source draw order, including barriers from unsupported
  // meshes and other alpha/side states. Equal-depth surfaces can depend on it.
  const buckets=new Map();let lastKey=null,rows=null,run=0;
  for(const entry of entries){const shape=this.shape(entry);if(!shape){lastKey=null;rows=null;continue;}if(shape.key!==lastKey){lastKey=shape.key;rows=[];buckets.set((run++)+':'+shape.key,rows);}rows.push(shape);}
  const proxies=new Map(),emitted=new Set(),result=[];
  try{
   for(const[key,rows]of buckets)for(let at=0;at<rows.length;at+=this.maxObjects){
    const members=rows.slice(at,at+this.maxObjects);if(members.length<2)continue;
    const id=this.keys.id(light)+':'+key+':'+at;let atlas=this.groups.get(id);
    if(atlas&&(atlas.members.length!==members.length||atlas.members.some((s,i)=>s.entry.object!==members[i].entry.object||s.geometryId!==members[i].geometryId))){this.destroy(atlas);this.groups.delete(id);atlas=null;}
    if(!atlas){atlas=this.create(members);this.groups.set(id,atlas);}atlas.members=members;atlas.light=light;atlas.used=this.frame;atlas.preparedFrame=-1;
    for(const shape of members)proxies.set(shape.entry,atlas);this.stats.groups++;this.stats.instances+=members.length;
   }
  }catch(error){this.failure=error.message;this.disabled=true;return entries.map(e=>e.object);}
  for(const entry of entries){const atlas=proxies.get(entry);if(!atlas)result.push(entry.object);else if(!emitted.has(atlas)){emitted.add(atlas);result.push(atlas.proxy);}}
  this.stats.originalDraws+=entries.length;this.stats.proxyDraws+=result.length;return result;
 }
 create(members){
  const vertexCount=members.reduce((n,s)=>n+s.entry.object.geometry.attributes.position.count,0),indexCount=members.reduce((n,s)=>n+s.count,0),capacity=2**Math.ceil(Math.log2(members.length));
  const bytes=vertexCount*48+indexCount*4+capacity*128;
  if(this.bytes+bytes>this.maxBytes)throw Error('Shadow atlas memory limit reached');
  const geometry=new BufferGeometry(),positions=new Float32Array(vertexCount*3),objectIds=new Float32Array(vertexCount),uvs=Array.from({length:4},()=>new Float32Array(vertexCount*2)),indices=new Uint32Array(indexCount),ranges=[];
  let vertex=0,index=0;
  for(const [id,shape]of members.entries()){
   const source=shape.entry.object.geometry,p=source.attributes.position;positions.set(p.array,vertex*3);objectIds.fill(id,vertex,vertex+p.count);
   for(const [i,name]of ['uv','uv1','uv2','uv3'].entries())if(source.attributes[name])uvs[i].set(source.attributes[name].array,vertex*2);
   ranges.push({start:index,count:shape.count});for(let i=0;i<shape.count;i++){const value=source.index?source.index.array[shape.start+i]:shape.start+i;if(value>=p.count)throw Error('Shadow atlas source index is invalid');indices[index++]=vertex+value;}vertex+=p.count;
  }
  geometry.setAttribute('position',new Float32BufferAttribute(positions,3));geometry.setAttribute('nwnShadowObject',new Float32BufferAttribute(objectIds,1));
  for(const [i,name]of ['uv','uv1','uv2','uv3'].entries())geometry.setAttribute(name,new Float32BufferAttribute(uvs[i],2));
  let external=null;
  if(this.multiDraw)geometry.setIndex(new Uint32BufferAttribute(indices,1));
  else{
   // WebGL classifies a buffer by its first binding. An index buffer must be
   // created as ELEMENT_ARRAY_BUFFER before later COPY_WRITE updates are legal.
   const gl=this.gl,previous=gl.getParameter(gl.ELEMENT_ARRAY_BUFFER_BINDING);try{external=gl.createBuffer();if(!external)throw Error('Shadow atlas index buffer allocation failed');gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,external);gl.bufferData(gl.ELEMENT_ARRAY_BUFFER,indices.byteLength,gl.DYNAMIC_DRAW);geometry.setIndex(new GLBufferAttribute(external,gl.UNSIGNED_INT,1,4,indexCount));}finally{gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,previous);}
  }
  const matrixData=new Float32Array(capacity*32),texture=new DataTexture(matrixData,8,capacity,RGBAFormat,FloatType);texture.minFilter=texture.magFilter=NearestFilter;texture.generateMipmaps=false;texture.needsUpdate=true;
  const first=members[0].entry.object,source=first.material,material=new MeshBasicMaterial({side:source.side,alphaTest:source.alphaTest,alphaToCoverage:source.alphaToCoverage,map:source.alphaTest>0||source.alphaToCoverage?source.map:null,alphaMap:source.alphaTest>0||source.alphaToCoverage?source.alphaMap:null});material.shadowSide=source.shadowSide;
  const proxy=new Mesh(geometry,material);proxy.castShadow=true;proxy.layers.mask=first.layers.mask;proxy.matrixAutoUpdate=false;proxy.matrixWorldAutoUpdate=false;proxy.matrixWorld.identity();proxy.customDepthMaterial=createShadowAtlasMaterial(false,texture);proxy.customDistanceMaterial=createShadowAtlasMaterial(true,texture);
  const atlas={owner:this,proxy,geometry,material,texture,matrixData,members,ranges,indices,external,selected:this.multiDraw?null:new Uint32Array(indexCount),starts:new Int32Array(capacity),counts:new Int32Array(capacity),multiCount:0,preparedFrame:-1,preparedView:new Matrix4(),sphere:new Sphere(undefined,Infinity),bytes,used:this.frame};
  proxy.userData.nwnShadowAtlas=atlas;Object.defineProperty(proxy,'boundingSphere',{get:()=>{this.prepare(atlas);return atlas.sphere;},configurable:true});this.bytes+=bytes;return atlas;
 }
 prepare(atlas){
  const camera=atlas.light.shadow.camera;if(atlas.preparedFrame===this.frame&&atlas.preparedView.equals(camera.matrixWorldInverse))return;
  atlas.preparedFrame=this.frame;atlas.preparedView.copy(camera.matrixWorldInverse);atlas.multiCount=0;let count=0;
  for(const [id,shape]of atlas.members.entries()){
   const {object,sphere}=shape.entry;if(sphere&&!atlas.light.shadow.getFrustum().intersectsSphere(sphere))continue;
   const range=atlas.ranges[id],draw=atlas.multiCount++;atlas.counts[draw]=range.count;atlas.starts[draw]=range.start*4;
   if(atlas.selected)atlas.selected.set(atlas.indices.subarray(range.start,range.start+range.count),count);count+=range.count;
   atlas.matrixData.set(object.matrixWorld.elements,id*32);object.modelViewMatrix.multiplyMatrices(camera.matrixWorldInverse,object.matrixWorld);atlas.matrixData.set(object.modelViewMatrix.elements,id*32+16);
  }
  atlas.geometry.setDrawRange(0,count);if(!count)return;atlas.texture.needsUpdate=true;this.stats.uploads++;
  if(atlas.external){const gl=this.gl,previous=gl.getParameter(gl.COPY_WRITE_BUFFER_BINDING);try{gl.bindBuffer(gl.COPY_WRITE_BUFFER,atlas.external);gl.bufferSubData(gl.COPY_WRITE_BUFFER,0,atlas.selected,0,count);}finally{gl.bindBuffer(gl.COPY_WRITE_BUFFER,previous);}this.stats.indexUploads++;}
 }
 destroy(atlas){atlas.geometry.dispose();atlas.material.dispose();atlas.texture.dispose();atlas.proxy.customDepthMaterial.dispose();atlas.proxy.customDistanceMaterial.dispose();if(atlas.external&&this.gl.isBuffer(atlas.external))this.gl.deleteBuffer(atlas.external);this.bytes-=atlas.bytes;atlas.members=[];atlas.light=null;delete atlas.proxy.userData.nwnShadowAtlas;}
 reset(){this.end();for(const group of this.groups.values())this.destroy(group);this.groups.clear();this.keys.reset();this.disabled=this.maxObjects<2;this.failure=null;this.stats={};}
 dispose(){this.reset();this.keys.dispose();}
 snapshot(){return{...this.stats,atlas:true,multiDraw:Boolean(this.multiDraw),cachedGroups:this.groups.size,bytes:this.bytes,geometryKeys:this.keys.geometryBuckets.size,disabled:this.disabled,failure:this.failure};}
}
