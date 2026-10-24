import {CompressedTexture,DataTexture,RGBAFormat,RGB_S3TC_DXT1_Format,RGBA_S3TC_DXT1_Format,RGBA_S3TC_DXT3_Format,RGBA_S3TC_DXT5_Format} from 'three';
const formats=new Set([RGB_S3TC_DXT1_Format,RGBA_S3TC_DXT1_Format,RGBA_S3TC_DXT3_Format,RGBA_S3TC_DXT5_Format]);
export const isS3tcFormat=format=>formats.has(format);

// WEBGL_compressed_texture_s3tc imposes4-texel upload alignment, unlike the
// original desktop renderer's arbitrary-size DDS path. Preserve dimensions
// and authored mip levels by decoding only these incompatible base images.
export function s3tcTexture(mipmaps,width,height,format){
 if(!formats.has(format)||width%4===0&&height%4===0)return new CompressedTexture(mipmaps,width,height,format);
 const levels=mipmaps.map(m=>({...m,data:decodeS3tc(m.data,m.width,m.height,format)})),texture=new DataTexture(levels[0].data,width,height,RGBAFormat);
 texture.mipmaps=levels;texture.generateMipmaps=false;return texture;
}

// EXT_texture_compression_s3tc block equations. This returns encoded RGB bytes;
// the existing texture color-space settings still own the sRGB conversion.
export function decodeS3tc(input,width,height,format){
 if(!formats.has(format))throw Error('Unsupported S3TC format');
 if(!Number.isInteger(width)||!Number.isInteger(height)||width<1||height<1||width>=0x8000||height>=0x8000)throw Error('Invalid S3TC image dimensions');
 const bytes=input instanceof Uint8Array?input:new Uint8Array(input),dxt1=format===RGB_S3TC_DXT1_Format||format===RGBA_S3TC_DXT1_Format,blockBytes=dxt1?8:16,bw=Math.ceil(width/4),bh=Math.ceil(height/4);
 if(bytes.byteLength!==bw*bh*blockBytes)throw Error('S3TC block data length does not match dimensions');
 const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength),out=new Uint8Array(width*height*4);
 for(let by=0;by<bh;by++)for(let bx=0;bx<bw;bx++){
  const block=(by*bw+bx)*blockBytes,color=block+(dxt1?0:8),c0=view.getUint16(color,true),c1=view.getUint16(color+2,true),selectors=view.getUint32(color+4,true);
  const rgb=n=>[((n>>11)&31)*255/31,((n>>5)&63)*255/63,(n&31)*255/31],colors=[rgb(c0),rgb(c1)],four=!dxt1||c0>c1;
  colors.push(four?colors[0].map((c,i)=>(2*c+colors[1][i])/3):colors[0].map((c,i)=>(c+colors[1][i])/2));
  colors.push(four?colors[0].map((c,i)=>(c+2*colors[1][i])/3):[0,0,0]);
  // Interpolate normalized565 endpoints before rounding to output bytes.
  for(const color of colors)for(let i=0;i<3;i++)color[i]=Math.round(color[i]);
  const alpha=[bytes[block],bytes[block+1]];
  if(!dxt1&&format===RGBA_S3TC_DXT5_Format){
   const steps=alpha[0]>alpha[1]?7:5;for(let i=1;i<steps;i++)alpha.push(Math.round(((steps-i)*alpha[0]+i*alpha[1])/steps));if(steps===5)alpha.push(0,255);
  }
  for(let p=0;p<16;p++){
   const x=bx*4+p%4,y=by*4+(p>>2);if(x>=width||y>=height)continue;
   const index=(selectors>>>(2*p))&3,rgb=colors[index],offset=(y*width+x)*4;out.set(rgb,offset);let a=255;
   if(format===RGBA_S3TC_DXT1_Format&&!four&&index===3)a=0;
   else if(format===RGBA_S3TC_DXT3_Format)a=((bytes[block+(p>>1)]>>((p%2)*4))&15)*17;
   else if(format===RGBA_S3TC_DXT5_Format){const bit=p*3,byte=block+2+(bit>>3),code=((bytes[byte]|(bytes[byte+1]??0)<<8)>>>(bit%8))&7;a=alpha[code];}
   out[offset+3]=a;
  }
 }
 return out;
}
