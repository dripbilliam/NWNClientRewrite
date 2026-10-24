import {decompress} from 'three/addons/utils/WebGLTextureUtils.js';
import {loadRasterTexture} from './raster_texture.js';
import {decodeS3tc,isS3tcFormat} from './s3tc_decode.js';
import {WebGLRenderer} from 'three';

export async function portraitImage(resolver,name){
 const texture=await loadRasterTexture(resolver,name);let readable,renderer;
 try{
  const image=texture.isCompressedTexture&&isS3tcFormat(texture.format)?{...texture.image,data:decodeS3tc(texture.mipmaps[0].data,texture.image.width,texture.image.height,texture.format)}:texture.image;
  if(image?.data){
   if(texture.flipY)return{...image,flipY:true};
   // Compressed DDS rows use the texture's lower-left origin. A CPU-decoded
   // DataTexture retains it for3D; ImageData requires top-left rows instead.
   const {width,height,data}=image,flipped=new Uint8Array(data.length),stride=width*4;
   for(let y=0;y<height;y++)flipped.set(data.subarray(y*stride,(y+1)*stride),(height-y-1)*stride);
   return{width,height,data:flipped,flipY:true};
  }
  // The blit shader emits straight-alpha pixels. Explicit context attributes
  // prevent canvas readback from unpremultiplying those colors a second time.
  renderer=new WebGLRenderer({antialias:false,premultipliedAlpha:false});readable=decompress(texture,Infinity,renderer);return readable.image.getContext('2d').getImageData(0,0,readable.image.width,readable.image.height);
 }finally{readable?.dispose();renderer?.dispose();renderer?.forceContextLoss();texture.dispose();}
}
