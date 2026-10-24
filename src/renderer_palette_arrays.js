import {DataArrayTexture,CompressedArrayTexture,Texture,RGBAFormat,UnsignedByteType,RepeatWrapping} from 'three';
import {compressedArrayShape,repeatS3tcMip} from './compressed_texture_array.js';
const fields=['format','type','internalFormat','mapping','channel','colorSpace','wrapS','wrapT','minFilter','magFilter','anisotropy','flipY','premultiplyAlpha','unpackAlignment','generateMipmaps','matrixAutoUpdate','rotation'];
const samplerFields=fields.slice(0,-2);
export class RendererPaletteArrays{
 constructor({maxLayers=32,maxBytes=64*1024*1024,minRepeatSize=128,compressed=false,perTextureUV=false}={}){this.maxLayers=maxLayers;this.maxBytes=maxBytes;this.minRepeatSize=minRepeatSize;this.compressed=compressed;this.perTextureUV=perTextureUV;this.reset();}
 reset(){for(const pool of this.pools?.values()??[])for(const array of pool)array.texture.dispose();this.pools=new Map();this.maps=new WeakMap();this.pass=null;this.bytes=0;this.layers=0;this.serial=0;}
 // A batch pass validates callbacks before entering. Within that synchronous
 // pass, supported hooks change draw uniforms, never shared texture state.
 beginPass(){this.pass=new WeakMap();}
 endPass(){this.pass=null;}
 grow(array,layerBytes){
  const capacity=Math.min(this.maxLayers,array.capacity*2,array.capacity+Math.floor((this.maxBytes-this.bytes)/layerBytes));
  if(capacity<=array.capacity)return false;
  if(array.compressed){const levels=array.texture.mipmaps.map(m=>{const data=new Uint8Array(m.data.length/array.capacity*capacity);data.set(m.data);return{...m,data};});array.texture.dispose();array.texture.mipmaps=levels;array.texture.image.depth=capacity;array.texture.clearLayerUpdates();array.texture.needsUpdate=true;this.bytes+=(capacity-array.capacity)*layerBytes;array.capacity=capacity;return true;}
  const data=new Uint8Array(layerBytes*capacity);data.set(array.texture.image.data);
  // Keep the texture object/layer identities used by existing batches. Retire
  // its old immutable GL storage before re-uploading at the larger depth.
  array.texture.dispose();array.texture.image.data=data;array.texture.image.depth=capacity;
  for(let i=0;i<array.used;i++)array.texture.addLayerUpdate(i);
  array.texture.needsUpdate=true;this.bytes+=(capacity-array.capacity)*layerBytes;array.capacity=capacity;return true;
 }
 descriptor(map){
  if(!map)return null;const image=map.image;
  if(this.compressed&&map.isCompressedTexture){
   if(map.isRenderTargetTexture||map.onUpdate||map.updateMatrix!==Texture.prototype.updateMatrix||map.version>2||map.source?.version>2||map.flipY||map.premultiplyAlpha||map.type!==UnsignedByteType||map.generateMipmaps||map.channel!==0)return null;
   const shape=compressedArrayShape(map,this.minRepeatSize);if(!shape)return null;if(map.matrixAutoUpdate)map.updateMatrix();return['compressed',shape.width,shape.height,shape.levels,...(this.perTextureUV?samplerFields:fields).map(k=>map[k]),...(this.perTextureUV?[]:[map.offset.x,map.offset.y,map.repeat.x,map.repeat.y,map.center.x,map.center.y,...map.matrix.elements])].join('|');
  }
  if(!map.isDataTexture||map.isRenderTargetTexture||map.onUpdate||map.updateMatrix!==Texture.prototype.updateMatrix||map.version>1||map.source?.version>1||map.flipY||map.premultiplyAlpha||map.format!==RGBAFormat||map.type!==UnsignedByteType||map.mipmaps.length||map.channel!==0||!(image?.data instanceof Uint8Array)||!Number.isInteger(image.width)||!Number.isInteger(image.height)||image.width<1||image.height<1||image.data.length!==image.width*image.height*4)return null;
  if(map.matrixAutoUpdate)map.updateMatrix();
  const repeat=map.wrapS===RepeatWrapping&&map.wrapT===RepeatWrapping&&(image.width&(image.width-1))===0&&(image.height&(image.height-1))===0,size=repeat?Math.max(this.minRepeatSize,image.width,image.height):0,width=repeat?size:image.width,height=repeat?size:image.height;
  return[width,height,...(this.perTextureUV?samplerFields:fields).map(k=>map[k]),...(this.perTextureUV?[]:[map.offset.x,map.offset.y,map.repeat.x,map.repeat.y,map.center.x,map.center.y,...map.matrix.elements])].join('|');
 }
 get(map){
  if(!map)return null;if(this.pass?.has(map))return this.pass.get(map);
  const record=this.allocate(map);this.pass?.set(map,record);return record;
 }
 allocate(map){
  const key=this.descriptor(map);if(key===null)return null;
  const previous=this.maps.get(map);if(previous?.key===key&&(!map.isCompressedTexture||previous.version===map.version&&previous.sourceVersion===map.source?.version))return previous;
  if(key.startsWith('compressed|'))return this.allocateCompressed(map,key);
  const [width,height]=key.split('|',2).map(Number),source=map.image,layerBytes=width*height*4;let pools=this.pools.get(key),array=pools?.at(-1);
  if(array&&array.used===array.capacity&&!this.grow(array,layerBytes))array=null;
  if(!array){const capacity=Math.min(32,this.maxLayers,4,Math.max(1,Math.floor(1024*1024/layerBytes)),Math.floor((this.maxBytes-this.bytes)/layerBytes));if(capacity<1)return null;const bytes=layerBytes*capacity,texture=new DataArrayTexture(new Uint8Array(bytes),width,height,capacity);for(const field of fields)texture[field]=map[field];texture.offset.copy(map.offset);texture.repeat.copy(map.repeat);texture.center.copy(map.center);texture.matrix.copy(map.matrix);array={texture,used:0,capacity,id:++this.serial};if(!pools)this.pools.set(key,pools=[]);pools.push(array);this.bytes+=bytes;}
  const layer=array.used++,target=array.texture.image.data,base=layer*width*height*4;
  for(let y=0;y<height;y++){const row=source.data.subarray(y%source.height*source.width*4,(y%source.height+1)*source.width*4);for(let x=0;x<width;x+=source.width)target.set(row,base+(y*width+x)*4);}
  array.texture.addLayerUpdate(layer);array.texture.needsUpdate=true;const record={key,array,layer,uvScale:[source.width/width,source.height/height]};this.maps.set(map,record);this.layers++;return record;
 }
 allocateCompressed(map,key){
  const{width,height,levels,layerBytes}=compressedArrayShape(map,this.minRepeatSize);let pools=this.pools.get(key),array=pools?.at(-1);
  if(array&&array.used===array.capacity&&!this.grow(array,layerBytes))array=null;
  if(!array){const capacity=Math.min(32,this.maxLayers,4,Math.max(1,Math.floor(1024*1024/layerBytes)),Math.floor((this.maxBytes-this.bytes)/layerBytes));if(capacity<1)return null;
   const mipmaps=Array.from({length:levels},(_,i)=>{const w=Math.max(1,width/2**i|0),h=Math.max(1,height/2**i|0),source=map.mipmaps[Math.min(i,map.mipmaps.length-1)],bytes=Math.ceil(w/4)*Math.ceil(h/4)*(source.data.length/(Math.ceil(source.width/4)*Math.ceil(source.height/4)));return{width:w,height:h,data:new Uint8Array(bytes*capacity)};}),texture=new CompressedArrayTexture(mipmaps,width,height,capacity,map.format,map.type);
   for(const field of fields)texture[field]=map[field];texture.offset.copy(map.offset);texture.repeat.copy(map.repeat);texture.center.copy(map.center);texture.matrix.copy(map.matrix);array={texture,used:0,capacity,id:++this.serial,compressed:true};if(!pools)this.pools.set(key,pools=[]);pools.push(array);this.bytes+=layerBytes*capacity;
  }
  const layer=array.used++;
  for(let i=0;i<levels;i++){const source=map.mipmaps[Math.min(i,map.mipmaps.length-1)],target=array.texture.mipmaps[i],bytes=repeatS3tcMip(source.data,source.width,source.height,target.width,target.height,map.format);target.data.set(bytes,layer*bytes.length);}
  // Upload every mip on a new/grown slab. Three's per-layer update marker is
  // cleared after the first compressed mip, so a partial marker would leave
  // new lower-level storage dependent on the renderer's fallback behavior.
  array.texture.clearLayerUpdates();array.texture.needsUpdate=true;const record={key,array,layer,version:map.version,sourceVersion:map.source?.version,uvScale:[map.image.width/width,map.image.height/height]};this.maps.set(map,record);this.layers++;return record;
 }
 snapshot(){return{arrays:this.serial,layers:this.layers,bytes:this.bytes};}
 dispose(){this.reset();}
}
