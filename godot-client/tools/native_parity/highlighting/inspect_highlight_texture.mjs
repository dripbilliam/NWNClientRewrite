// Bounded read-only original/profile fxpa_dot02 extraction, never a substitute
// for resolving the currently active server catalog at runtime.
import fs from 'node:fs/promises';import path from 'node:path';import {createHash} from 'node:crypto';
import {parseKey} from '../../../../src/resource_archive.js';
import {parseNativeTga} from '../../../../src/native_tga.js';
import {parseBioWareDds} from '../../../../src/bioware_dds.js';
import {decodeS3tc} from '../../../../src/s3tc_decode.js';
const [label]=process.argv.slice(2);if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Fresh label required');
const project=path.resolve('godot-client'),install=path.resolve('../FullDecomp/NwnRootInstall'),profile='C:/Users/Niflheim/Documents/Neverwinter Nights.0/override';
const folder=path.join(project,'.cache/native-presentation-parity/particles-agent',label);await fs.mkdir(folder,{recursive:false});
const hash=b=>createHash('sha256').update(b).digest('hex'),rows=new Map(),keys=[];
for(const name of ['data/nwn_retail.key','data/nwn_base.key']){
 const bytes=await fs.readFile(path.join(install,name)),key=parseKey(bytes);keys.push({name,sha256:hash(bytes)});
 for(const [id,row]of key.resources)if(!rows.has(id))rows.set(id,{...row,bif:key.bifNames[row.bifIndex]});
}
async function archived(type){
 const row=rows.get('fxpa_dot02:'+type);if(!row)return null;const source=path.join(install,row.bif),file=await fs.open(source,'r');
 try{const h=Buffer.alloc(20);await file.read(h,0,20,0);const v11=h.toString('ascii',4,8)==='V1.1',stride=v11?20:16,p=v11?8:4,e=Buffer.alloc(stride);await file.read(e,0,stride,h.readUInt32LE(16)+row.resourceIndex*stride);
  const n=e.readUInt32LE(p+4);if(n>4*1024*1024||e.readUInt32LE(p+8)!==type)throw Error('Bounded BIF type/size mismatch');const bytes=Buffer.alloc(n);if((await file.read(bytes,0,n,e.readUInt32LE(p))).bytesRead!==n)throw Error('Short BIF payload');return{bytes,source,bif:row.bif,index:row.resourceIndex};
 }finally{await file.close();}
}
function raster(bytes,type){
 if(type===3){const value=parseNativeTga(bytes);return{width:value.width,height:value.height,rgba:value.data,mips:1,format:'TGA'+bytes[16]};}
 if(type===2033){const value=parseBioWareDds(bytes),m=value.mipmaps[0];return{width:value.image.width,height:value.image.height,rgba:decodeS3tc(m.data,m.width,m.height,value.format),mips:value.mipmaps.length,format:value.format};}
 return null;
}
function stats(image){
 const histogram=new Array(256).fill(0),samples=[];for(let i=3;i<image.rgba.length;i+=4)histogram[image.rgba[i]]++;
 for(const [u,v]of[[0,0],[0.5,0],[0.5,0.5],[1,0.5],[1,1]]){const x=Math.min(image.width-1,Math.floor(u*image.width)),y=Math.min(image.height-1,Math.floor(v*image.height)),at=(y*image.width+x)*4;samples.push({u,v,rgba:Array.from(image.rgba.slice(at,at+4))});}
 return{width:image.width,height:image.height,mips:image.mips,format:image.format,alphaHistogram:histogram,samples,rgbaSha256:hash(image.rgba)};
}
const resources=[];
for(const [extension,type]of[['tga',3],['dds',2033],['txi',2022],['ktx',2073]]){
 const base=await archived(type);if(base){const relative='base-fxpa_dot02.'+extension;await fs.writeFile(path.join(folder,relative),base.bytes,{flag:'wx'});const image=raster(base.bytes,type);resources.push({scope:'installed',type,extension,file:path.join(folder,relative),source:base.source,bif:base.bif,index:base.index,bytes:base.bytes.length,sha256:hash(base.bytes),txi:type===2022?base.bytes.toString('latin1'):undefined,raster:image?stats(image):undefined});}
 for(const directory of [profile,path.join(install,'ovr'),path.join(install,'override')]){
  const source=path.join(directory,'fxpa_dot02.'+extension);let bytes;try{bytes=await fs.readFile(source);}catch(error){if(error.code==='ENOENT')continue;throw error;}
  if(bytes.length>4*1024*1024)throw Error('Loose texture size bound');const image=raster(bytes,type);resources.push({scope:directory===profile?'active-profile-override':'install-loose-override',source,type,extension,bytes:bytes.length,sha256:hash(bytes),txi:type===2022?bytes.toString('latin1'):undefined,raster:image?stats(image):undefined});
 }
}
for(const key of keys)if(hash(await fs.readFile(path.join(install,key.name)))!==key.sha256)throw Error('Installed KEY changed');
const report={version:1,resref:'fxpa_dot02',keys,resources,scope:'Installed+active-profile loose resources only; server NWSync provider remains runtime authoritative',serverConnections:0,nativeBuilds:0};
const file=path.join(folder,'report.json');await fs.writeFile(file,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file,sha256:hash(await fs.readFile(file)),resources:resources.map(x=>({...x,raster:x.raster?{width:x.raster.width,height:x.raster.height,mips:x.raster.mips,format:x.raster.format,samples:x.raster.samples}:undefined}))}));
