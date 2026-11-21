// Private startup experiment utilities. Importing this module never launches an engine.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';

export const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
export const project=path.join(workspace,'godot-client');
export const stageRoot=path.join(project,'.cache/startup-export-probe');
export const rootResource='native_session_world.gd';
export const enginePins={
 editor:{file:'.tools/Godot_v4.7.2-stable_win64.exe',bytes:180858888,sha256:'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'},
 release:{file:'.tools/windows_release_x86_64.exe',bytes:109268480,sha256:'d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562'}
};
export const nativeFiles=[
 '.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json',
 '.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json',
 '.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json'
];
export const sha=value=>crypto.createHash('sha256').update(value).digest('hex');
export const slash=value=>value.replaceAll('\\','/');
export function inside(directory,file){
 const actual=path.resolve(file),parent=path.resolve(directory);
 assert.ok(actual.startsWith(parent+path.sep),'Path escaped its explicitly owned directory');return actual;
}
export function safeName(name){assert.match(name??'',/^[a-z0-9][a-z0-9-]{2,70}$/);return name;}
export function json(file,value){fs.writeFileSync(file,JSON.stringify(value,null,2)+'\n',{flag:'wx'});}
export function record(file){const bytes=fs.readFileSync(file);return{path:slash(path.relative(workspace,file)),bytes:bytes.length,sha256:sha(bytes)};}
export function unchanged(records){return records.filter(row=>{try{return record(path.join(workspace,row.path)).sha256!==row.sha256;}catch{return true;}}).map(row=>row.path);}
export function inspectEngine(kind){const pin=enginePins[kind],file=path.join(project,pin.file),row=record(file);assert.equal(row.bytes,pin.bytes);assert.equal(row.sha256,pin.sha256);return{...row,file};}

// Conservative literal load/preload/extends closure, not a claim about actual loader work.
export function sourceClosure(){
 const files=new Map(),missingLiteralLoads=[],excludedOptionalResources=[];
 function include(relative,required=true){
  relative=slash(relative);const file=inside(project,path.join(project,relative));
  if(!required&&relative==='.cache/native-window/build-manifest.json'){
   excludedOptionalResources.push({relative,reason:'NativeWindowSettings.query_modes method body only; never called by a root-resource load. Exact shared manifest is independently guarded.'});return;
  }
  assert.ok(!relative.split('/').some(part=>['.cache','.tools','backups','node_modules'].includes(part)),'Excluded literal source path '+relative);
  if(files.has(relative))return;
  if(!fs.existsSync(file)){if(required)throw Error('Missing literal dependency: '+relative);missingLiteralLoads.push(relative);return;}
  assert.ok(!fs.lstatSync(file).isSymbolicLink(),'No source junction/symlink traversal');
  const bytes=fs.readFileSync(file),row={...record(file),relative};files.set(relative,row);
  if(/\.(?:gd|tscn|tres|gdshader|gdshaderinc)$/.test(relative)){
   const text=bytes.toString('utf8');
   for(const m of text.matchAll(/(?:preload|load)\s*\(\s*["']res:\/\/([^"']+)["']\s*\)/g))include(m[1]);
   for(const m of text.matchAll(/extends\s+["']res:\/\/([^"']+)["']/g))include(m[1]);
   for(const m of text.matchAll(/["']res:\/\/([^"']+\.(?:gdshader|gdshaderinc|tscn|tres|svg|json))["']/g))include(m[1],false);
  }
  const uid=file+'.uid';if(fs.existsSync(uid))include(relative+'.uid');
 }
 include(rootResource);include('systems/client_api/client_api.gd');
 for(const file of ['project.godot','native/particle_kernel.gdextension','native/resource_index.gdextension'])include(file);
 return{files:[...files.values()].sort((a,b)=>a.relative.localeCompare(b.relative)),missingLiteralLoads:[...new Set(missingLiteralLoads)].sort(),excludedOptionalResources,semantics:'Conservative literal resource closure; dynamic resources and query_modes method are not executed by this load-only probe.'};
}

export function privateProject(source){
 assert.equal((source.match(/^run\/main_scene=/gm)??[]).length,1);
 assert.equal((source.match(/^config\/name=/gm)??[]).length,1);
 assert.ok(!/^config\/use_custom_user_dir=/m.test(source));
 return source.replace(/^run\/main_scene=.*$/m,'run/main_scene="res://__startup_probe.tscn"')
  .replace(/^config\/name=.*$/m,'config/name="Owned Load Only Startup Probe"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="owned-load-only-startup-probe"');
}
export function presets(){
 return [0,2].map((mode,index)=>`[preset.${index}]
name="${mode===0?'RawText':'BinaryTokens'}"
platform="Windows Desktop"
runnable=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="*.json,*.gdshaderinc"
exclude_filter=""
export_path=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=${mode}

[preset.${index}.options]
custom_template/debug=""
custom_template/release="${slash(path.join(project,enginePins.release.file))}"
binary_format/architecture="x86_64"
binary_format/embed_pck=false
codesign/enable=false
application/modify_resources=false
`).join('\n');
}
export function cleanEngine(text){return !/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(text);}
export function runtimeBundle(directory,arm){
 assert.ok(['A','B','C'].includes(arm));
 const folder=inside(directory,path.join(directory,'runtime-'+arm));
 return{directory:folder,executable:path.join(folder,'OwnedStartupProbe.exe'),pack:path.join(folder,'OwnedStartupProbe.pck')};
}
export function runtimeArguments(report,log){return['--headless','--log-file',log,'--','--startup-report='+report];}
export function childEnvironment(directory){
 const env={...process.env};
 // ClientAPI can enable a REST listener through environment; never inherit that route.
 for(const key of Object.keys(env))if(/^(?:NWN_|GODOT_)/i.test(key))delete env[key];
 for(const name of ['APPDATA','LOCALAPPDATA','TEMP','TMP']){
  const value=inside(directory,path.join(directory,'os-private',name.toLowerCase()));fs.mkdirSync(value,{recursive:true});env[name]=value;
 }
 return env;
}

// Godot 4.7 PCK v4, unencrypted directory and file data only. Reject other forms.
export function inspectPack(file){
 const fd=fs.openSync(file,'r'),size=fs.fstatSync(fd).size;
 function read(offset,length){assert.ok(Number.isSafeInteger(offset)&&length>=0&&length<=32*1024*1024&&offset+length<=size);const bytes=Buffer.alloc(length);assert.equal(fs.readSync(fd,bytes,0,length,offset),length);return bytes;}
 const entries=new Map();
 try{
  const head=read(0,40);assert.equal(head.toString('ascii',0,4),'GDPC');assert.equal(head.readUInt32LE(4),4);assert.equal(head.readUInt32LE(20),2);
  assert.deepEqual([head.readUInt32LE(8),head.readUInt32LE(12),head.readUInt32LE(16)],[4,7,2]);
  const base=Number(head.readBigUInt64LE(24)),directory=Number(head.readBigUInt64LE(32));let cursor=directory;
  const count=read(cursor,4).readUInt32LE();cursor+=4;assert.ok(count>0&&count<=10000);
  for(let n=0;n<count;n++){
   const len=read(cursor,4).readUInt32LE();cursor+=4;assert.ok(len>0&&len<=4096);
   const name=read(cursor,len).toString('utf8').replace(/\0+$/,'' ).replace(/^res:\/\//,'');cursor+=len;
   assert.ok(name&&!name.split('/').includes('..')&&!entries.has(name));
   const row=read(cursor,36);cursor+=36;assert.equal(row.readUInt32LE(32),0);
   const offset=base+Number(row.readBigUInt64LE()),bytes=Number(row.readBigUInt64LE(8));assert.ok(offset+bytes<=directory);
   const data=read(offset,bytes);entries.set(name,{name,bytes,sha256:sha(data),data});
  }
  assert.ok(cursor<=size);return{file,bytes:size,sha256:record(file).sha256,entries};
 }finally{fs.closeSync(fd);}
}
export function comparePacks(raw,token,sourceRows){
 const mappings=[];
 for(const row of sourceRows.filter(row=>row.relative.endsWith('.gd'))){
  const source=raw.entries.get(row.relative),binaryName=row.relative.replace(/\.gd$/,'.gdc');
  assert.ok(source,'Raw script omitted '+row.relative);assert.equal(source.sha256,row.sha256);
  assert.ok(!token.entries.has(row.relative),'Token pack retained text '+row.relative);
  const binary=token.entries.get(binaryName),remap=token.entries.get(row.relative+'.remap');assert.ok(binary&&remap,'Missing official token/remap '+row.relative);
  assert.equal(binary.data.toString('ascii',0,4),'GDSC');assert.ok(binary.bytes>=12);
  const target=/path="([^"]+)"/.exec(remap.data.toString('utf8'))?.[1];assert.equal(target,'res://'+binaryName);
  mappings.push({source:row.relative,sourceSha256:row.sha256,token:binaryName,tokenSha256:binary.sha256,tokenizerVersion:binary.data.readUInt32LE(4),decodedTokenBytes:binary.data.readUInt32LE(8)});
 }
 const expectedDifference=new Set(mappings.flatMap(row=>[row.source,row.token,row.source+'.remap']));
 const names=new Set([...raw.entries.keys(),...token.entries.keys()]);
 for(const name of names)if(!expectedDifference.has(name))assert.equal(raw.entries.get(name)?.sha256,token.entries.get(name)?.sha256,'Non-script pack divergence '+name);
 return{success:true,scripts:mappings.length,mappings,nonScriptPayloadsEqual:true};
}
