import {RGB_S3TC_DXT1_Format,RGBA_S3TC_DXT1_Format,RGBA_S3TC_DXT3_Format,RGBA_S3TC_DXT5_Format,RepeatWrapping} from 'three';
export const s3tcBlockBytes=format=>format===RGB_S3TC_DXT1_Format||format===RGBA_S3TC_DXT1_Format?8:format===RGBA_S3TC_DXT3_Format||format===RGBA_S3TC_DXT5_Format?16:0;
const read=(b,base,bit,count)=>((b[base+(bit>>3)]|((b[base+(bit>>3)+1]??0)<<8))>>>(bit&7))&((1<<count)-1);
function write(b,base,bit,count,value){const at=base+(bit>>3),shift=bit&7,mask=((1<<count)-1)<<shift;b[at]=(b[at]&~mask)|(value<<shift);if(shift+count>8)b[at+1]=(b[at+1]&~(mask>>>8))|(value>>>(8-shift));}
// Repeat encoded blocks without changing their endpoint tables. Partial final
// mips repeat only valid texels by permuting color/alpha selectors; padded
// selectors outside a 1x1/2x2 mip must never become visible array texels.
export function repeatS3tcMip(data,width,height,targetWidth,targetHeight,format){
 const size=s3tcBlockBytes(format);if(!size||!(data instanceof Uint8Array)||![width,height,targetWidth,targetHeight].every(n=>Number.isInteger(n)&&n>0)||targetWidth<width||targetHeight<height||targetWidth%width||targetHeight%height||data.length!==Math.ceil(width/4)*Math.ceil(height/4)*size)throw Error('Unsupported lossless compressed mip repeat');
 if((targetWidth!==width||targetHeight!==height)&&((width&(width-1))||(height&(height-1))))throw Error('Compressed mip repeat requires power-of-two sources');
 const bw=Math.ceil(width/4),out=new Uint8Array(Math.ceil(targetWidth/4)*Math.ceil(targetHeight/4)*size),tw=Math.ceil(targetWidth/4),th=Math.ceil(targetHeight/4);
 for(let y=0;y<th;y++)for(let x=0;x<tw;x++){
  const source=(Math.floor((y*4%height)/4)*bw+Math.floor((x*4%width)/4))*size,target=(y*tw+x)*size;out.set(data.subarray(source,source+size),target);
  if(width>=4&&height>=4)continue;
  for(let py=0;py<4;py++)for(let px=0;px<4;px++){const p=py*4+px,q=(py%height)*4+px%width,color=size===8?0:8;write(out,target+color+4,p*2,2,read(data,source+color+4,q*2,2));if(format===RGBA_S3TC_DXT3_Format)write(out,target,p*4,4,read(data,source,q*4,4));else if(format===RGBA_S3TC_DXT5_Format)write(out,target+2,p*3,3,read(data,source+2,q*3,3));}
 }return out;
}
export function compressedArrayShape(map,minRepeatSize){
 const size=s3tcBlockBytes(map?.format),image=map?.image;
 if(!map?.isCompressedTexture||map.isCompressedArrayTexture||map.isCubeTexture||!size||!image||map.mipmaps.length<1||!Number.isInteger(image.width)||!Number.isInteger(image.height)||image.width<1||image.height<1)return null;
 const maxLevels=1+Math.floor(Math.log2(Math.max(image.width,image.height)));if(map.mipmaps.length>maxLevels)return null;
 for(let i=0;i<map.mipmaps.length;i++){const m=map.mipmaps[i],w=Math.max(1,Math.floor(image.width/2**i)),h=Math.max(1,Math.floor(image.height/2**i));if(m.width!==w||m.height!==h||!(m.data instanceof Uint8Array)||m.data.length!==Math.ceil(w/4)*Math.ceil(h/4)*size)return null;}
 const full=map.mipmaps.length===maxLevels,pot=n=>(n&(n-1))===0,repeat=map.wrapS===RepeatWrapping&&map.wrapT===RepeatWrapping&&full&&pot(image.width)&&pot(image.height),side=repeat?2**Math.ceil(Math.log2(Math.max(minRepeatSize,image.width,image.height))):0,width=side||image.width,height=side||image.height,levels=repeat?1+Math.floor(Math.log2(side)):map.mipmaps.length;
 return{width,height,levels,layerBytes:Array.from({length:levels},(_,i)=>Math.ceil(Math.max(1,Math.floor(width/2**i))/4)*Math.ceil(Math.max(1,Math.floor(height/2**i))/4)*size).reduce((a,b)=>a+b,0)};
}
