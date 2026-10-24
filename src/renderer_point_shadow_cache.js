import {Object3D} from 'three';
const equal=(a,b)=>a?.length===b.length&&a.every((v,i)=>v===b[i]);
// Cache renderer output, never gameplay state. Unknown/custom shadow producers
// stay live. Basic mesh maps are reused only with identical light/caster input.
export class RendererPointShadowCache{
 constructor(canvas,{shortCircuitVolatile=false}={}){this.canvas=canvas;this.shortCircuitVolatile=shortCircuitVolatile;this.frame=0;this.serial=0;this.objects=new WeakMap();this.lights=new WeakMap();this.targets=new WeakMap();this.restore=()=>{this.objects=new WeakMap();this.lights=new WeakMap();};canvas?.addEventListener('webglcontextrestored',this.restore);}
 begin(){this.frame++;}
 texture(out,texture){
  out.push(texture);if(!texture)return true;if(texture.isVideoTexture)return false;
  out.push(texture.version,texture.source?.version,texture.channel,texture.colorSpace,texture.wrapS,texture.wrapT,texture.minFilter,texture.magFilter,texture.flipY,texture.matrixAutoUpdate,texture.offset.x,texture.offset.y,texture.repeat.x,texture.repeat.y,texture.center.x,texture.center.y,texture.rotation,...texture.matrix.elements);return true;
 }
 stamp(object){
  let previous=this.objects.get(object);if(previous?.frame===this.frame)return previous.stamp;
  if(!object.isMesh||object.isSkinnedMesh||object.isInstancedMesh||object.isBatchedMesh||object.children.length||object.customDepthMaterial||object.customDistanceMaterial||object.onBeforeShadow!==Object3D.prototype.onBeforeShadow||object.onAfterShadow!==Object3D.prototype.onAfterShadow)return null;
  const geometry=object.geometry;for(const key in geometry.morphAttributes)if(geometry.morphAttributes[key]?.length)return null;
  const values=[geometry,object.visible,object.layers.mask,object.frustumCulled,object.castShadow,...object.matrixWorld.elements,geometry.drawRange.start,geometry.drawRange.count];
  for(const key of ['position','normal','uv','uv1','uv2','uv3','color']){const a=geometry.attributes[key];values.push(a,a?.version,a?.count,a?.itemSize);if(a?.isInterleavedBufferAttribute)values.push(a.data,a.data.version);}
  values.push(geometry.index,geometry.index?.version,geometry.index?.count,geometry.groups.length);for(const group of geometry.groups)values.push(group.start,group.count,group.materialIndex);
  const sphere=object.boundingSphere??geometry.boundingSphere;values.push(sphere?.center.x,sphere?.center.y,sphere?.center.z,sphere?.radius);
  const materials=Array.isArray(object.material)?object.material:[object.material];
  values.push(materials.length);
  for(const material of materials){
   if(!material||material.isShaderMaterial||material.clippingPlanes?.length)return null;
   values.push(material,material.version,material.visible,material.shadowSide??material.side,material.wireframe,material.wireframeLinewidth,material.linewidth,material.opacity,material.alphaTest,material.alphaToCoverage,material.displacementScale,material.displacementBias,material.clipShadows,material.clipIntersection);
   for(const key of ['map','alphaMap','displacementMap'])if(!this.texture(values,material[key]))return null;
  }
  const stamp=equal(previous?.values,values)?previous.stamp:++this.serial;this.objects.set(object,{frame:this.frame,stamp,values});return stamp;
 }
 lightKey(light,type){
  const s=light.shadow,c=s.camera,map=s.map;let generation=0;
  if(map){let state=this.targets.get(map);if(!state){state={generation:0};this.targets.set(map,state);map.addEventListener?.('dispose',()=>state.generation++);}generation=state.generation;}
  return[type,map,generation,light.distance,...light.matrixWorld.elements,s.mapSize.x,s.mapSize.y,s.bias,s.normalBias,c.near,c.far,c.fov,c.aspect,c.zoom,...c.projectionMatrix.elements];
 }
 plan(light,casters,type,{force=false}={}){
  const inputs=[];let volatile=false;for(const object of casters){const stamp=this.stamp(object);inputs.push(object,stamp);if(stamp===null){volatile=true;
   // One unsupported/animated producer already requires a complete map draw.
   // The opt-in candidate avoids inspecting the remaining caster textures and
   // matrices. A null baseline prevents reuse after that producer disappears;
   // one complete, rendered input set must be committed before reuse resumes.
   if(this.shortCircuitVolatile)return{reuse:false,inputs:null,volatile:true};
  }}
  const key=this.lightKey(light,type),previous=this.lights.get(light);
  return{reuse:!force&&!volatile&&Boolean(light.shadow.map)&&equal(previous?.key,key)&&equal(previous?.inputs,inputs),inputs,volatile};
 }
 commit(light,plan,type){this.lights.set(light,{key:this.lightKey(light,type),inputs:plan.inputs});}
 dispose(){this.canvas?.removeEventListener('webglcontextrestored',this.restore);this.restore();}
}
