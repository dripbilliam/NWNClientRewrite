import {RGB_S3TC_DXT1_Format,RGBA_S3TC_DXT1_Format,RGBA_S3TC_DXT3_Format,RGBA_S3TC_DXT5_Format} from 'three';

// Conservative lower bound on sampled alpha, including every authored mip and
// padded block texel. Color decoding and sRGB transfer do not affect alpha.
// Floors of interpolated BC3 alpha are lower bounds, not reconstructed pixels.
export function compressedAlphaMinimum(texture){
 const format=texture.format,size=format===RGB_S3TC_DXT1_Format||format===RGBA_S3TC_DXT1_Format?8:format===RGBA_S3TC_DXT3_Format||format===RGBA_S3TC_DXT5_Format?16:0;
 const image=texture.image,levels=texture.mipmaps;
 if(!size||!Number.isSafeInteger(image?.width)||!Number.isSafeInteger(image?.height)||image.width<1||image.height<1||!levels?.length||levels.length>1+Math.floor(Math.log2(Math.max(image.width,image.height))))return null;
 let minimum=255;
 for(let level=0;level<levels.length;level++){
  const mip=levels[level],width=Math.max(1,Math.floor(image.width/2**level)),height=Math.max(1,Math.floor(image.height/2**level)),data=mip?.data;
  if(mip.width!==width||mip.height!==height||!(data instanceof Uint8Array)||data.length!==Math.ceil(width/4)*Math.ceil(height/4)*size)return null;
  for(let offset=0;offset<data.length;offset+=size){
   if(format===RGB_S3TC_DXT1_Format)continue;
   if(format===RGBA_S3TC_DXT1_Format){
    const c0=data[offset]+256*data[offset+1],c1=data[offset+2]+256*data[offset+3];
    if(c0<=c1)for(let i=4;i<8;i++)for(let bit=0;bit<8;bit+=2)if(((data[offset+i]>>bit)&3)===3)minimum=0;
   }else if(format===RGBA_S3TC_DXT3_Format){
    for(let i=0;i<8;i++)minimum=Math.min(minimum,17*(data[offset+i]&15),17*(data[offset+i]>>4));
   }else{
    const a0=data[offset],a1=data[offset+1];let indices=0;
    for(let i=7;i>=2;i--)indices=indices*256+data[offset+i];
    for(let pixel=0;pixel<16;pixel++){
     const code=indices%8;indices=Math.floor(indices/8);
     const alpha=code===0?a0:code===1?a1:a0>a1?Math.floor(((8-code)*a0+(code-1)*a1)/7):code===6?0:code===7?255:Math.floor(((6-code)*a0+(code-1)*a1)/5);
     minimum=Math.min(minimum,alpha);
    }
   }
  }
 }
 return minimum;
}
