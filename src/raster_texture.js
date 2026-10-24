import {DataTexture,RGBAFormat,SRGBColorSpace,LinearFilter,LinearMipmapLinearFilter} from 'three';
import {parseNativeTga} from './native_tga.js';
import {DDSLoader} from 'three/addons/loaders/DDSLoader.js';
import {KTXLoader} from 'three/addons/loaders/KTXLoader.js';
import {parseBioWareDds} from './bioware_dds.js';
import {resolveTextureResource} from './texture_resource.js';
import {s3tcTexture} from './s3tc_decode.js';

// Flat UI images and model bitmaps use the same catalog/format selection.
// In particular an installed TGA must not hide a selected server DDS/KTX.
export async function loadRasterTexture(resolver,name){
 const resource=await resolveTextureResource(resolver,name),value=resource.bytes;
 const buffer=value instanceof ArrayBuffer?value:value.buffer.slice(value.byteOffset,value.byteOffset+value.byteLength);
 let texture;
 if(resource.type===3){
  const image=parseNativeTga(buffer);texture=new DataTexture(image.data,image.width,image.height,RGBAFormat);texture.flipY=image.flipY;texture.generateMipmaps=image.generateMipmaps;
 }else if(resource.type===2033){
  if(buffer.byteLength>=4&&new DataView(buffer).getUint32(0,false)===0x44445320){
   const image=new DDSLoader().parse(buffer,true);texture=compressed(image);
  }else texture=parseBioWareDds(buffer);
 }else if(resource.type===2073){
  // KTXLoader reports malformed headers through console.error and can return
  // incomplete metadata. Reject before allocating a misleading empty image.
  const magic=[0xab,0x4b,0x54,0x58,0x20,0x31,0x31,0xbb,0x0d,0x0a,0x1a,0x0a];
  if(buffer.byteLength<64||magic.some((b,i)=>new Uint8Array(buffer)[i]!==b))throw Error('KTX image header is invalid');
  const image=new KTXLoader().parse(buffer,true);if(image.isCubemap)throw Error('Cubemap cannot be used as a flat UI image');texture=compressed(image);
 }else throw Error(`Raster type ${resource.type} requires an unsupported UI decoder`);
 texture.colorSpace=SRGBColorSpace;texture.magFilter=LinearFilter;texture.needsUpdate=true;return texture;
}
function compressed(image){
 if(!image?.width||!image.height||!image.format||!image.mipmaps?.length)throw Error('Compressed image has no valid mip data');
 const texture=s3tcTexture(image.mipmaps,image.width,image.height,image.format);texture.minFilter=image.mipmapCount>1?LinearMipmapLinearFilter:LinearFilter;return texture;
}
