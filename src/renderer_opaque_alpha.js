// Experimental equivalent no-discard variant: never lower the cutoff for a
// texture/material state that can actually fail it. Native stock programs have
// separate NO_DISCARD variants (SetProgram1400b7a40, call1400b5ac0).
// This does not infer alpha mode from a filename or from a missing channel.
import {Material,Object3D,RGBAFormat,UnsignedByteType} from 'three';
import {rendererBatchHook,isLocalRendererHook} from './renderer_local_hooks.js';
import {compressedAlphaMinimum} from './renderer_texture_alpha.js';

function ordinaryAlphaShader(material){
 if(material.onBeforeCompile===Material.prototype.onBeforeCompile)return true;
 const hook=rendererBatchHook(material.onBeforeCompile);
 return hook?.kind==='keyhole'&&hook.before===Material.prototype.onBeforeCompile;
}
export class RendererOpaqueAlpha{
 constructor(){this.enabled=false;this.textures=new WeakMap();this.materials=new Map();this.stats={};}
 minimum(texture){
  if(!texture||texture.isCubeTexture||texture.isRenderTargetTexture||texture.isVideoTexture||texture.type!==UnsignedByteType||
   (!texture.isCompressedTexture&&texture.format!==RGBAFormat))return null;
  const image=texture.image,version=texture.version,sourceVersion=texture.source?.version;
  const cached=this.textures.get(texture);
  if(cached&&cached.image===image&&cached.array===image?.data&&cached.version===version&&cached.sourceVersion===sourceVersion)return cached.minimum;
  let minimum=texture.isCompressedTexture?compressedAlphaMinimum(texture):255;
  const levels=texture.mipmaps?.length?texture.mipmaps:[image];
  for(const level of texture.isCompressedTexture?[]:levels){
   const data=level?.data,count=level?.width*level?.height;
   if(!data||!(data instanceof Uint8Array||data instanceof Uint8ClampedArray)||!Number.isSafeInteger(count)||count<=0||data.length!==count*4){minimum=null;break;}
   for(let i=3;i<data.length;i+=4)minimum=Math.min(minimum,data[i]);
  }
  this.textures.set(texture,{image,array:image?.data,version,sourceVersion,minimum});this.stats.scannedTextures++;
  return minimum;
 }
 restore(material,record){if(material.alphaTest===record.applied)material.alphaTest=record.cutoff;}
 prepare(scene){
  this.stats={enabled:this.enabled,materials:0,removed:0,retained:0,scannedTextures:0};
  if(!this.enabled){this.reset();return;}
  const seen=new Map();
  scene.traverseVisible(object=>{
   if(!object.isMesh)return;
   for(const material of Array.isArray(object.material)?object.material:[object.material]){
    if(!material)continue;
    const safeOwner=(object.onBeforeRender===Object3D.prototype.onBeforeRender||isLocalRendererHook(object.onBeforeRender))&&material.onBeforeRender===Material.prototype.onBeforeRender&&!material.map?.onUpdate;
    seen.set(material,(seen.get(material)??true)&&safeOwner);
   }
  });
  for(const [material,safeOwner]of seen){
    this.stats.materials++;
    let record=this.materials.get(material);
    if(!record){record={cutoff:material.alphaTest,applied:material.alphaTest};this.materials.set(material,record);}
    else if(material.alphaTest!==record.applied)record.cutoff=material.alphaTest;
    const minimum=this.minimum(material.map);
    // Unknown shader producers, vertex alpha and alpha maps can change the
    // alpha tested by the shader independently of this texture/opacity pair.
    const safe=safeOwner&&(material.isMeshLambertMaterial||material.isMeshBasicMaterial)&&ordinaryAlphaShader(material)&&
     !material.alphaMap&&!material.vertexColors&&!material.alphaHash&&!material.alphaToCoverage&&
     minimum!==null&&Number.isFinite(material.opacity)&&record.cutoff>0&&record.cutoff<1&&
     Math.fround(material.opacity*minimum/255)>Math.fround(record.cutoff)+1e-6;
    record.applied=safe?0:record.cutoff;material.alphaTest=record.applied;
    if(safe)this.stats.removed++;else this.stats.retained++;
  }
  for(const [material,record]of this.materials)if(!seen.has(material)){this.restore(material,record);this.materials.delete(material);}
 }
 snapshot(){return{...this.stats,tracked:this.materials.size};}
 reset(){for(const [material,record]of this.materials)this.restore(material,record);this.materials.clear();}
 dispose(){this.enabled=false;this.reset();this.textures=new WeakMap();}
}
