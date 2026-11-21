import * as T from 'three';
import {GLTFExporter} from 'three/addons/exporters/GLTFExporter.js';
import {decodeS3tc,isS3tcFormat} from '../../src/s3tc_decode.js';
import {highlightEligible,highlightColor,highlightName,highlightNameValue,highlightDamageLevel} from '../../src/world_highlight.js';

export function sourceObjectId(object){
 for(let p=object;p;p=p.parent){const id=p.userData.networkObjectId??p.userData.worldObjectId;if(Number.isInteger(id))return id;}
 return null;
}

export async function describeGodotEntities({world,resolve=async value=>value?.text??'',inventory=[]}={}){
 if(!world)return[];const ids=new Set(inventory.map(row=>row.id));
 return Promise.all([...world.registry.objects.values()].filter(o=>ids.has(o.id)).map(async object=>({id:object.id,type:object.objectType,name:await highlightName(highlightNameValue(object),value=>resolve(value,object.id)),eligible:highlightEligible(object,{areaId:world.areaId}),color:highlightColor(object,world.localObjectId),damageLevel:highlightDamageLevel(object),controlled:object.id===world.localObjectId,resources:inventory.find(row=>row.id===object.id)?.resources??[]})));
}

// One-way scene/rig transfer. This never runs in the native frame loop.
export function prepareGodotRoom({scene,camera,inventory,buffer,entities=[],focus=null,rigTransfer=null,particleTransfer=null,objectIds=null,namePrefix='',includeCamera=true}){
 const output=new T.Scene(),materials=new Map(),textures=new Map(),geometries=new Map(),owned=[],lights=[],meshBindings=[],ambient=[0,0,0];
 const counts={meshes:0,particles:0,triangles:0,lights:0,ambient:0};
 const gaps=new Set([rigTransfer?'Animation events, non-transform controllers, exact animated skin picking and particles remain unmigrated':'Frozen animation and particle poses','Stock engine material/lighting approximation','Fog and native keyhole not exported','Authored texture mip chain not preserved by glTF','Full gameplay, networking and UI parity not accepted']);
 function texture(map){
  if(!map)return null;if(textures.has(map))return textures.get(map);
  let data,width,height;
  if(map.isCompressedTexture&&isS3tcFormat(map.format)){const mip=map.mipmaps[0];data=decodeS3tc(mip.data,mip.width,mip.height,map.format);width=mip.width;height=mip.height;}
  else if(map.isDataTexture&&map.format===T.RGBAFormat&&map.type===T.UnsignedByteType){({width,height}=map.image);data=map.image.data;}
  else throw Error('Unmapped texture storage: '+map.name);
  const copy=new T.DataTexture(new Uint8Array(data),width,height,T.RGBAFormat,T.UnsignedByteType);
  copy.colorSpace=map.colorSpace;copy.flipY=map.flipY;copy.wrapS=map.wrapS;copy.wrapT=map.wrapT;copy.channel=map.channel;copy.matrixAutoUpdate=false;if(map.matrixAutoUpdate)copy.matrix.setUvTransform(map.offset.x,map.offset.y,map.repeat.x,map.repeat.y,map.rotation,map.center.x,map.center.y);else copy.matrix.copy(map.matrix);copy.needsUpdate=true;textures.set(map,copy);owned.push(copy);return copy;
 }
 function material(m,particle){
  if(materials.has(m))return materials.get(m);
  if(!particle&&!m.isMeshBasicMaterial&&!m.isMeshLambertMaterial)throw Error('Unmapped material: '+m.type);
  if(m.alphaMap||m.normalMap||m.lightMap||m.emissiveMap||m.clippingPlanes?.length)throw Error('Unmapped additional material texture/stage');
  const options={map:texture(particle?m.uniforms.particleMap.value:m.map),color:m.color??0xffffff,opacity:m.opacity,alphaTest:m.alphaTest,transparent:m.transparent,side:m.side,depthWrite:m.depthWrite,depthTest:m.depthTest,vertexColors:particle||m.vertexColors};
  const copy=particle||m.isMeshBasicMaterial?new T.MeshBasicMaterial(options):new T.MeshStandardMaterial({...options,emissive:m.emissive,roughness:1,metalness:0});
  materials.set(m,copy);owned.push(copy);return copy;
 }
 scene.updateMatrixWorld();camera.updateWorldMatrix(true,false);
 scene.traverseVisible(object=>{
  if(!object.layers.test(camera.layers)||object.userData.rendererLightSlot)return;
  if(objectIds&&!objectIds.has(sourceObjectId(object)))return;
  if(object.isAmbientLight){counts.ambient++;object.color.toArray().forEach((value,i)=>ambient[i]+=value*object.intensity);return;}
  if(object.isLight){
   if(!object.isPointLight&&!object.isDirectionalLight&&!object.isSpotLight)throw Error('Unmapped light: '+object.type);
   const copy=object.clone(false);copy.userData={};copy.name=namePrefix+'nwn_light_'+counts.lights++;copy.matrixAutoUpdate=false;copy.matrix.copy(object.matrixWorld);
   let direction;
   if(object.target){
    // Three lights face their target; glTF lights face local -Z. Rotation on
    // the original Three node is unrelated to its actual illumination axis.
    object.target.updateWorldMatrix(true,false);const position=new T.Vector3().setFromMatrixPosition(object.matrixWorld),target=new T.Vector3().setFromMatrixPosition(object.target.matrixWorld);
    if(position.distanceToSquared(target)>1e-12){const matrix=new T.Matrix4().lookAt(position,target,new T.Vector3(0,1,0));matrix.setPosition(position);copy.matrix.copy(matrix);direction=target.sub(position).normalize().toArray();}
    copy.target=new T.Object3D();copy.target.position.set(0,0,-1);copy.add(copy.target);
   }
   output.add(copy);
   lights.push({name:copy.name,objectId:sourceObjectId(object),areaPrimary:object.userData.nativeAreaLight===true,shadow:object.castShadow,color:object.color.toArray(),intensity:object.intensity,distance:object.distance,decay:object.decay,...(direction?{direction}:{})});return;
  }
  if(!object.isMesh)return;
  if(object.isSkinnedMesh||object.isInstancedMesh||object.isBatchedMesh)throw Error('Unmapped mesh instance kind: '+object.type);
  const source=object.geometry,particle=Boolean(object.userData.mdlEmitter&&object.material.uniforms?.particleMap);
  if(particle&&particleTransfer)return;
  if(!source.attributes.position||source.drawRange.count===0)return;
  const list=Array.isArray(object.material)?object.material:[object.material],hitOnly=Boolean(object.userData.nativeObjectHitMesh);
  // Original render=0 placeable trimeshes are retained by the JS picker but
  // have material.visible=false. Preserve only those real hit faces belonging
  // to an explicitly usable replicated placeable, still fully transparent.
  if(hitOnly&&!entities.some(e=>e.id===sourceObjectId(object)&&e.type===9&&e.eligible))return;
  if(!hitOnly&&!list.some(m=>m.visible))return;
  if(!hitOnly&&list.some(m=>!m.visible))throw Error('Mixed material visibility needs an explicit surface filter');
  let geometry=geometries.get(source);
  if(!geometry){geometry=source.clone();geometry.deleteAttribute('skinIndex');geometry.deleteAttribute('skinWeight');if(particle){const color=source.getAttribute('particleColor');if(!color)throw Error('Particle tint stream absent');geometry.setAttribute('color',color.clone());geometry.deleteAttribute('particleColor');}geometries.set(source,geometry);owned.push(geometry);}
  const converted=list.map(m=>material(m,particle)),mesh=new T.Mesh(geometry,Array.isArray(object.material)?converted:converted[0]);mesh.name=namePrefix+'nwn_mesh_'+counts.meshes++;mesh.userData={nwnFrozenParticle:particle};
  meshBindings.push({name:mesh.name,objectId:sourceObjectId(object),particle,...(hitOnly?{pickOnly:true}:{}),blend:particle&&object.material.blendDst===T.OneFactor?'additive':'mix',depthTest:list[0].depthTest,depthWrite:list[0].depthWrite,...(rigTransfer?.binding(object)??{})});
  mesh.matrixAutoUpdate=false;if(!particle)mesh.matrix.copy(object.matrixWorld);output.add(mesh);
  const available=source.index?.count??source.attributes.position.count;counts.triangles+=Math.max(0,Math.min(source.drawRange.count,available-source.drawRange.start))/3;if(particle)counts.particles++;
 });
 if(particleTransfer)for(const row of particleTransfer.data.emitters){
  // An initially empty/hidden emitter still needs its original bitmap. A tiny
  // transparent template exports that texture without freezing a particle pose.
  const object=particleTransfer.meshes?.get(row.id);if(!object)throw Error('Emitter texture template source is missing');
  const geometry=new T.BufferGeometry();geometry.setAttribute('position',new T.Float32BufferAttribute(new Float32Array(18),3));geometry.setAttribute('uv',new T.Float32BufferAttribute([0,0,1,0,1,1,0,0,1,1,0,1],2));geometry.setAttribute('color',new T.Uint8BufferAttribute(new Uint8Array(24),4,true));owned.push(geometry);
  const mesh=new T.Mesh(geometry,material(object.material,true));mesh.name=namePrefix+'nwn_mesh_'+counts.meshes++;output.add(mesh);row.textureMesh=mesh.name;
  meshBindings.push({name:mesh.name,objectId:row.objectId,particle:true,liveParticle:true,blend:row.properties.blend==='Normal'?'mix':'additive',depthTest:true,depthWrite:false});counts.particles++;
 }
 if(includeCamera){const captured=camera.clone(false);captured.name='CapturedCamera';captured.userData={};captured.matrixAutoUpdate=false;captured.matrix.copy(camera.matrixWorld);output.add(captured);}
 return{scene:output,manifest:{version:1,systemsVersion:1,scope:'Complete source-visible mesh import with explicit fidelity gaps; not a gameplay/native parity acceptance',inventory,entities,meshes:meshBindings,focus,ambient,...(includeCamera&&scene.background?.isColor?{background:scene.background.toArray()}:{}),buffer,counts,lights,gaps:[...gaps],...(rigTransfer?{rigs:rigTransfer.data}:{}),...(particleTransfer?{particles:particleTransfer.data}:{}),accepted:false},dispose(){for(const resource of owned)resource.dispose();}};
}

export async function exportGodotRoom(context){
 const entities=await describeGodotEntities(context),prepared=prepareGodotRoom({...context,entities});
 try{
  const binary=await new GLTFExporter().parseAsync(prepared.scene,{binary:true,onlyVisible:true});
  if(!(binary instanceof ArrayBuffer))throw Error('Exporter did not produce GLB');
  const bytes=new Uint8Array(binary),pieces=[];for(let start=0;start<bytes.length;start+=24576)pieces.push(btoa(String.fromCharCode(...bytes.subarray(start,start+24576))));
  // Chunk sizes are multiples of three, so concatenated base64 has no interior padding.
  return{manifest:prepared.manifest,glbBase64:pieces.join('')};
 }finally{prepared.dispose();}
}
