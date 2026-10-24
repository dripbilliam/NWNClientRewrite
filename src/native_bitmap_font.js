import {parseNativeTga} from './native_tga.js';
import {RESOURCE_TYPE,decodeResourceText} from './resource_archive.js';
import {scriptStringBytes} from './script_string.js';
// Installed TXI glyph metrics are expressed in the same100px GUI units used
// by native UI model hooks. UVs retain their source bottom-to-top convention.
export function parseBitmapFont(text){
 const lines=text.split(/\r?\n/).map(l=>l.trim()).filter(Boolean),values={},coords={};
 for(let i=0;i<lines.length;i++){
  const [key,...parts]=lines[i].split(/\s+/),name=key.toLowerCase();
  if(name==='upperleftcoords'||name==='lowerrightcoords'){
   const count=Number(parts[0]);if(!Number.isInteger(count)||count<1||count>65536)throw new Error('Invalid native font coordinate count');
   coords[name]=Array.from({length:count},()=>{const row=lines[++i]?.split(/\s+/).map(Number);if(!row||row.length!==3||row.some(v=>!Number.isFinite(v)))throw new Error('Invalid native font coordinate');return row;});
  }else values[name]=Number(parts[0]);
 }
 const count=values.numchars;if(!Number.isInteger(count)||count<1||count>65536||coords.upperleftcoords?.length!==count||coords.lowerrightcoords?.length!==count)throw new Error('Native font glyph metrics are incomplete');
 if(![values.fontheight,values.texturewidth].every(v=>Number.isFinite(v)&&v>0)||!Number.isFinite(values.baselineheight))throw new Error('Native font dimensions are unavailable');
 return{count,height:values.fontheight*100,baseline:values.baselineheight*100,width:values.texturewidth*100,spacingR:(values.spacingr??0)*100,spacingB:(values.spacingb??0)*100,upper:coords.upperleftcoords,lower:coords.lowerrightcoords};
}
export function bitmapGlyph(metrics,index,imageWidth,imageHeight){
 const missing=index>=metrics.count;if(missing)index=0;const upper=metrics.upper[index],lower=metrics.lower[index],scale=metrics.width/imageWidth;
 const sx=Math.round(upper[0]*imageWidth),sy=Math.round((1-upper[1])*imageHeight),sw=Math.round((lower[0]-upper[0])*imageWidth),sh=Math.round((upper[1]-lower[1])*imageHeight);
 if(sw<0||sh<0||sx<0||sy<0||sx+sw>imageWidth||sy+sh>imageHeight)throw new Error('Native font glyph is outside its atlas');
 return{sx,sy,sw,sh,width:sw*scale,height:sh*scale,advance:sw*scale+metrics.spacingR,missing};
}
export class NativeBitmapFont{
 static async load(getResource,name){const [meta,data]=await Promise.all([getResource(name,RESOURCE_TYPE.TXI),getResource(name,RESOURCE_TYPE.TGA)]),metrics=parseBitmapFont(decodeResourceText(meta)),image=parseNativeTga(data);return new NativeBitmapFont(metrics,image);}
 constructor(metrics,image){this.metrics=metrics;this.image=image;this.tints=new Map();}
 tint(color){
  color=color.toLowerCase();if(!/^#[0-9a-f]{6}$/.test(color))throw new Error('Native font tint is invalid');if(this.tints.has(color))return this.tints.get(color);
  const canvas=document.createElement('canvas');canvas.width=this.image.width;canvas.height=this.image.height;const context=canvas.getContext('2d'),pixels=new Uint8ClampedArray(this.image.data),rgb=[1,3,5].map(i=>parseInt(color.slice(i,i+2),16));
  for(let at=0;at<pixels.length;at+=4)for(let channel=0;channel<3;channel++)pixels[at+channel]=Math.round(pixels[at+channel]*rgb[channel]/255);
  context.putImageData(new ImageData(pixels,canvas.width,canvas.height),0,0);if(this.tints.size>=64)this.tints.delete(this.tints.keys().next().value);this.tints.set(color,canvas);return canvas;
 }
 render(spans,defaultColor='#ffffff'){
  const glyphs=[];let x=0,y=0,width=0,missing=0;
  for(const span of spans)for(const byte of scriptStringBytes(span.text)){
   if(byte===10){width=Math.max(width,x);x=0;y+=this.metrics.height+this.metrics.spacingB;continue;}
   const glyph=bitmapGlyph(this.metrics,byte,this.image.width,this.image.height);if(glyph.missing)missing++;glyphs.push({...glyph,x,y,color:span.color??defaultColor});x+=glyph.advance;
  }
  width=Math.max(width,x);const canvas=document.createElement('canvas');canvas.width=Math.max(1,Math.ceil(width));canvas.height=Math.max(1,Math.ceil(y+this.metrics.height));const context=canvas.getContext('2d');context.imageSmoothingEnabled=false;
  for(const glyph of glyphs)if(glyph.sw&&glyph.sh)context.drawImage(this.tint(glyph.color),glyph.sx,glyph.sy,glyph.sw,glyph.sh,glyph.x,glyph.y,glyph.width,glyph.height);
  canvas.dataset.nativeBitmapFont='true';return{canvas,baseline:this.metrics.baseline,missing};
 }
}
