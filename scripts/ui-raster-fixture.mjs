import {portraitImage} from '../src/portrait_image.js';
import {NativeUiAssets} from '../src/native_ui_assets.js';
import {networkPortrait} from '../src/network_portrait.js';
import {ResourceResolver} from '../src/resource_archive.js';
import {networkResourceResult} from '../src/network_resource_bridge.js';
import {loadRasterTexture} from '../src/raster_texture.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {decodeS3tc} from '../src/s3tc_decode.js';
import * as T from 'three';
import {decompress} from 'three/addons/utils/WebGLTextureUtils.js';
import {NetworkQuickbarView} from '../src/network_quickbar_view.js';
import {GameUi} from '../src/game_ui.js';
const check=(v,m)=>{if(!v)throw Error(m);};
function tga(){const b=new Uint8Array(22);b[2]=2;b[12]=b[14]=1;b[16]=32;b[17]=0x20;b.set([0,255,0,255],18);return b.buffer;}
function dds(){const b=new Uint8Array(136),v=new DataView(b.buffer);for(const[o,n]of[[0,0x20534444],[4,124],[8,0x1007],[12,4],[16,4],[28,1],[76,32],[80,4],[84,0x31545844],[108,0x1000]])v.setUint32(o,n,true);v.setUint16(128,0xf800,true);return b.buffer;}
function ktx(){const b=new Uint8Array(76),v=new DataView(b.buffer);b.set([0xab,0x4b,0x54,0x58,0x20,0x31,0x31,0xbb,13,10,26,10]);for(const[o,n]of[[12,0x04030201],[20,1],[28,0x83f0],[32,0x1907],[36,4],[40,4],[48,0],[52,1],[56,1],[64,8]])v.setUint32(o,n,true);v.setUint16(68,0x001f,true);return b.buffer;}
const missing=name=>Object.assign(Error('Missing fixture '+name),{code:'RESOURCE_NOT_FOUND'});
function resolver(type,available='portrait_m'){
 const reads=[],r=new ResourceResolver({entries:new Map()},{resources:new Map([[available+':3',{}]])},[]);r.layers=[{hasResource:(n,t)=>n===available&&t===type}];r.getResource=async(name,t)=>{reads.push([name,t]);if(name!==available)throw missing(name);return t===3?tga():t===2033?dds():ktx();};return{r,reads};
}
async function pixel(url){const image=new Image();image.src=url;await image.decode();const c=document.createElement('canvas');c.width=image.naturalWidth;c.height=image.naturalHeight;c.getContext('2d').drawImage(image,0,0);return{width:c.width,height:c.height,rgba:[...c.getContext('2d').getImageData(0,0,1,1).data]};}
window.runUiRasterFixture=async()=>{
 const result={scope:'Actual Chromium NativeUiAssets, portraitImage and networkPortrait with synthetic color-coded competing resource formats, plus offline active cached UI art',cases:[]};
 for(const[type,channel]of[[2033,0],[2073,2],[3,1]]){
  const f=resolver(type),assets=new NativeUiAssets(f.r);
  try{const texture=await assets.texture('portrait_m');check(Boolean(texture.isCompressedTexture)===(type!==3),'Wrong UI texture format');const image=await portraitImage(f.r,'portrait_m');check(image.data[channel]>240&&image.data[(channel+1)%3]<10,'Wrong decoded selected color');const url=await networkPortrait(assets,null,{id:1,portrait:65535,portraitRef:'portrait_'},3);check(Boolean(url),'Compressed network portrait was hidden');const painted=await pixel(url);check(painted.rgba[channel]>240,'Network portrait painted lower source');result.cases.push({case:'UI/flat/network portrait format'+type,reads:f.reads,pixel:painted});}finally{assets.dispose();}
 }
 {
  const f=resolver(2033,'portrait_h'),assets=new NativeUiAssets(f.r);try{const url=await networkPortrait(assets,null,{id:2,portrait:65535,portraitRef:'portrait_'},1);check(Boolean(url),'Tiny portrait did not find huge-only image');const painted=await pixel(url);check(painted.rgba[0]>240,'Huge-only DDS portrait did not decode');result.cases.push({case:'tiny-to-huge native endpoint fallback',reads:f.reads,pixel:painted});}finally{assets.dispose();}
 }
 {
  const a=resolver(2033),b=resolver(3),aa=new NativeUiAssets(a.r),bb=new NativeUiAssets(b.r);try{const row={id:3,portrait:65535,portraitRef:'portrait_'},pa=await pixel(await networkPortrait(aa,null,row,3)),pb=await pixel(await networkPortrait(bb,null,row,3));check(pa.rgba[0]>240&&pb.rgba[1]>240,'Portrait cache leaked between owners');result.cases.push({case:'separate server owners',a:pa,b:pb});}finally{aa.dispose();bb.dispose();}
 }
 {
  const f=resolver(2033),assets=new NativeUiAssets(f.r),quickbar=new NetworkQuickbarView(document.body,{world:()=>null});quickbar.assets=assets;
  const host=document.createElement('div'),slot=document.createElement('button');slot.dataset.binding='current';slot.append(host);document.body.append(slot);
  try{const network=await pixel(await quickbar.icon('portrait_m'));await GameUi.prototype.quickbarIcon.call({assets,quickbarIcons:new Map()},'portrait_m',host,'current',slot);const single=await pixel(host.querySelector('img').src);check(network.rgba[0]===255&&single.rgba[0]===255,'Quickbar cannot decode selected DDS');check((await assets.image('portrait_m'))===(await assets.image('PORTRAIT_M')),'UI image cache did not normalize names');result.cases.push({case:'multiplayer and singleplayer quickbar DDS icons',network,single});}finally{quickbar.reset();quickbar.host.remove();slot.remove();}
 }
 {
  let release;const old={image:()=>new Promise(resolve=>release=resolve)},current={assets:old,quickbarIcons:new Map()},host=document.createElement('div'),slot=document.createElement('button');slot.dataset.binding='same';slot.append(host);document.body.append(slot);const work=GameUi.prototype.quickbarIcon.call(current,'portrait_m',host,'same',slot);current.assets={};release({width:1,height:1,data:new Uint8Array([255,0,0,255])});await work;check(!host.querySelector('img'),'Old singleplayer asset painted new owner');result.cases.push({case:'singleplayer icon owner changes during decode',stalePaint:false});slot.remove();
 }
 {
  let low=0;try{await loadRasterTexture({getTextureResource:async()=>{throw Error('Selected failure');},getResource:async()=>{low++;return tga();}},'portrait');throw Error('Selected failure was swallowed');}catch(e){check(e.message==='Selected failure'&&low===0,'Selected decoder failure used lower asset');}result.cases.push({case:'selected-source failure',lowerReads:low});
 }
 {
  const renderer=new T.WebGLRenderer({antialias:false,premultipliedAlpha:false}),formats=[T.RGB_S3TC_DXT1_Format,T.RGBA_S3TC_DXT1_Format,T.RGBA_S3TC_DXT3_Format,T.RGBA_S3TC_DXT5_Format];let seed=1741,maxPremultipliedDelta=0,maxAlphaDelta=0,comparisons=0,worstAlpha,worstColor,maxRgbEndpointDelta=0,maxAlphaEndpointDelta=0,rgbEndpoints=0,alphaEndpoints=0;
  try{for(const format of formats)for(let sample=0;sample<16;sample++){
   const data=new Uint8Array(format===T.RGB_S3TC_DXT1_Format||format===T.RGBA_S3TC_DXT1_Format?8:16);for(let i=0;i<data.length;i++){seed=(Math.imul(seed,1664525)+1013904223)>>>0;data[i]=seed>>>24;}
   const expected=decodeS3tc(data,4,4,format),texture=new T.CompressedTexture([{data,width:4,height:4}],4,4,format);texture.minFilter=texture.magFilter=T.NearestFilter;texture.needsUpdate=true;let readable;
   try{readable=decompress(texture,Infinity,renderer);const gl=renderer.getContext(),got=new Uint8Array(64);gl.readPixels(0,0,4,4,gl.RGBA,gl.UNSIGNED_BYTE,got);for(let p=0;p<16;p++){
    // Compare straight-alpha framebuffer values in the texture's row order,
    // before canvas compositing or premultiplication can change the pixels.
    const dest=p*4,alpha=expected[p*4+3],gpuAlpha=got[dest+3];if(format!==T.RGB_S3TC_DXT1_Format&&Math.abs(alpha-gpuAlpha)>maxAlphaDelta){maxAlphaDelta=Math.abs(alpha-gpuAlpha);worstAlpha={format,sample,p,data:[...data],expected:[...expected.slice(p*4,p*4+4)],got:[...got.slice(dest,dest+4)]};}
    const rgbCode=(new DataView(data.buffer).getUint32(data.length-4,true)>>>(p*2))&3;if(rgbCode<2){rgbEndpoints++;for(let c=0;c<3;c++)maxRgbEndpointDelta=Math.max(maxRgbEndpointDelta,Math.abs(expected[p*4+c]-got[dest+c]));}
    let interpolatedAlpha=false;if(format===T.RGBA_S3TC_DXT5_Format){let bits=0n;for(let i=0;i<6;i++)bits|=BigInt(data[i+2])<<BigInt(i*8);interpolatedAlpha=Number(bits>>BigInt(p*3)&7n)>1;}if(format!==T.RGB_S3TC_DXT1_Format&&!interpolatedAlpha){alphaEndpoints++;maxAlphaEndpointDelta=Math.max(maxAlphaEndpointDelta,Math.abs(alpha-gpuAlpha));}
    // RGB DXT1 may be exposed by a driver as RGBA DXT1. Its black palette
    // entry has the same RGB but an implementation-dependent alpha bit.
    for(let c=0;c<3;c++){const delta=Math.abs(expected[p*4+c]*alpha/255-got[dest+c]*gpuAlpha/255);if(delta>maxPremultipliedDelta){maxPremultipliedDelta=delta;worstColor={format,sample,p,data:[...data],expected:[...expected.slice(p*4,p*4+4)],got:[...got.slice(dest,dest+4)]};}}comparisons++;
   }}finally{readable?.dispose();texture.dispose();}
  }check(renderer.getContext().getError()===0,'GPU reference upload failed');check(rgbEndpoints>400&&alphaEndpoints>500&&maxRgbEndpointDelta<=1&&maxAlphaEndpointDelta<=1,'S3TC endpoint decoding differs: '+JSON.stringify({rgbEndpoints,alphaEndpoints,maxRgbEndpointDelta,maxAlphaEndpointDelta}));const gl=renderer.getContext(),debug=gl.getExtension('WEBGL_debug_renderer_info');result.s3tcGpuReference={blocks:64,pixels:comparisons,rgbEndpoints,alphaEndpoints,maxRgbEndpointDelta,maxAlphaEndpointDelta,maxPremultipliedDelta,maxAlphaDelta,worstAlpha,worstColor,gpu:debug?gl.getParameter(debug.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER),limits:'Endpoint/selector validation agrees with GPU. The specification-equation interpolation is unit-tested; this driver differs by up to the separately reported values on interpolated entries. Exact driver interpolation is not claimed and is not tuned into production.'};}finally{renderer.dispose();renderer.forceContextLoss();}
 }
 const native={getResource:async(name,type)=>networkResourceResult(await creationFixture.resource(name,type),name,type),getTextureResource:async name=>networkResourceResult(await creationFixture.texture(name),name,'texture')},assets=new NativeUiAssets(native);
 try{
  result.cached=[];for(const name of await creationFixture.models()){
   const selected=await native.getTextureResource(name),texture=await assets.texture(name),image=await portraitImage(native,name);check(image.width>0&&image.height>0&&image.data.length===image.width*image.height*4,'Cached UI raster dimensions mismatch');let coloredPixels=0,visibleColoredPixels=0;for(let i=0;i<image.data.length;i+=4){const colored=image.data[i]>0||image.data[i+1]>0||image.data[i+2]>0;coloredPixels+=Number(colored);visibleColoredPixels+=Number(colored&&image.data[i+3]>0);}check(visibleColoredPixels>0,'Cached UI raster is blank: '+name+' '+image.width+'x'+image.height);result.cached.push({name,type:selected.type,width:image.width,height:image.height,coloredPixels,visibleColoredPixels,textureCompressed:Boolean(texture.isCompressedTexture)});
  }
 }finally{assets.dispose();}
 result.diagnostics=runtimeDiagnostics.records;result.success=true;return result;
};
