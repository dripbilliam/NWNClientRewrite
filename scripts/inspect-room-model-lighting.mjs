// Offline read-only inspection of original installed tile MDLs referenced by
// captured area lighting metadata. This is not active override resolution or
// a renderer. It retains lighting summaries/hashes, never original payloads.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {parseKey} from '../src/resource_archive.js';
import {parseBinaryMdl} from '../src/binary_mdl.js';
import {parseAsciiMdl} from '../src/model_parser.js';
import {parseNWSyncManifest} from '../src/nwsync_manifest.js';
import {decodeNWSyncBlob} from '../electron/nwsync_content.mjs';
import {NWSyncReader} from '../electron/nwsync_reader.mjs';

const [root, capture, output] = process.argv.slice(2);
const [cacheDirectory,nativeDirectory]=process.argv.slice(5);
if (!root || !capture || !output) throw Error('Supply install root, lighting capture, and new output path');
const keys = [];
for (const file of ['nwn_retail.key','nwn_base.key']) {
  try { keys.push(parseKey(await fs.readFile(path.join(root,'data',file)))); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
}
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const cachedCatalogs=[];
if(cacheDirectory)for(const name of await fs.readdir(path.join(cacheDirectory,'manifests'))){
  if(!/^[0-9a-f]{40}$/.test(name))continue;
  const bytes=await fs.readFile(path.join(cacheDirectory,'manifests',name));
  if(createHash('sha1').update(bytes).digest('hex')!==name)throw Error('Cached manifest digest differs');
  cachedCatalogs.push(parseNWSyncManifest(bytes));
}
let reader;
async function readAt(handle, offset, count) {
  if (count < 0 || count > 32*1024*1024) throw Error('Bounded resource read exceeded');
  const bytes = Buffer.alloc(count);
  if ((await handle.read(bytes,0,count,offset)).bytesRead !== count) throw Error('Truncated archive read');
  return bytes;
}
async function resource(name,type) {
  const candidates=cachedCatalogs.map(catalog=>catalog.catalog.get(name+':'+type)).filter(Boolean);
  if(candidates.length){
    const hashes=[...new Set(candidates.map(row=>row.hash))];
    if(hashes.length!==1)throw Error('Cached server manifests disagree for '+name+':'+type);
    const entry=candidates[0];let encoded;
    try{encoded=await fs.readFile(path.join(cacheDirectory,'objects',entry.hash));}
    catch(error){if(error.code!=='ENOENT')throw error;reader??=new NWSyncReader(nativeDirectory);encoded=await reader.blob(entry.hash);}
    if(!encoded)throw Error('Server resource not locally available: '+name);
    const bytes=await decodeNWSyncBlob(encoded,{decompressZstd:(data,size)=>{reader??=new NWSyncReader(nativeDirectory);return reader.decompress(data,size);}});
    if(createHash('sha1').update(bytes).digest('hex')!==entry.hash)throw Error('Server resource digest differs');
    return {bytes,sha256:sha(bytes),archive:'cached-nwsync:'+entry.hash};
  }
  for (const key of keys) {
    const entry = [...key.resources.values()].find(row=>row.resref===name && row.resourceType===type);
    if (!entry) continue;
    const relative = key.bifNames[entry.bifIndex].replaceAll('\\','/');
    const handle = await fs.open(path.join(root,relative),'r');
    try {
      const header = await readAt(handle,0,24);
      if (header.toString('ascii',0,4)!=='BIFF') throw Error('Unexpected archive');
      const stride = header.toString('ascii',4,8)==='V1.1'?20:16;
      const row = await readAt(handle,header.readUInt32LE(16)+entry.resourceIndex*stride,stride);
      const at = stride===20?8:4, offset = row.readUInt32LE(at), size = row.readUInt32LE(at+4);
      const bytes = await readAt(handle,offset,size);
      return {bytes,sha256:sha(bytes),archive:relative};
    } finally { await handle.close(); }
  }
  throw Error('Installed resource not found: '+name+':'+type);
}
try{
const world = JSON.parse(await fs.readFile(capture,'utf8')).worldLighting;
const set = await resource(world.area.tileset,2013);
const modelById = new Map();let tile=-1;
for (const rawLine of set.bytes.toString('latin1').split(/\r?\n/)) {
  const line=rawLine.trim();
  const section = line.match(/^\[TILE(\d+)\]/i);
  if (section) tile = Number(section[1]);
  else if (line.startsWith('[')) tile=-1;
  const model = line.match(/^Model\s*=\s*(\S+)/i);
  if (model && tile>=0) modelById.set(tile,model[1].toLowerCase());
}
const names = [...new Set(world.tiles.map(row=>modelById.get(Number(row.fields['14']))))];
if (names.includes(undefined) || names.length>256) throw Error('Captured tile IDs exceed installed SET: '+JSON.stringify({
  installedTiles:modelById.size,missingIds:[...new Set(world.tiles.map(row=>Number(row.fields['14'])))].filter(id=>!modelById.has(id)).slice(0,20)}));
const models=[];
for (const name of names) {
  const source = await resource(name,2002);
  const value = source.bytes.readUInt32LE(0)===0
    ? parseBinaryMdl(source.bytes.buffer.slice(source.bytes.byteOffset,source.bytes.byteOffset+source.bytes.length))
    : parseAsciiMdl(source.bytes.toString('latin1'));
  const meshes = value.nodes.filter(row=>row.ambient || row.diffuse);
  models.push({name,sha256:source.sha256,archive:source.archive,
    materialPairs:[...new Set(meshes.map(row=>JSON.stringify({ambient:row.ambient,diffuse:row.diffuse})))].map(JSON.parse),
    visibleMaterialPairs:[...new Set(meshes.filter(row=>row.render && row.verts?.length && row.faces?.length).map(row=>JSON.stringify({ambient:row.ambient,diffuse:row.diffuse})))].map(JSON.parse),
    differingVisibleParts:meshes.filter(row=>row.render && row.verts?.length && row.faces?.length && JSON.stringify(row.ambient)!==JSON.stringify(row.diffuse)).map(row=>({name:row.name,ambient:row.ambient,diffuse:row.diffuse})),
    lights:value.nodes.filter(row=>row.type==='light' || row.light || row.properties?.ambientonly !== undefined).map(row=>({name:row.name,properties:row.properties}))});
}
const result={success:true,tileset:world.area.tileset,areaId:world.area.id,
  set:{sha256:set.sha256,archive:set.archive},models,
  scope:'Locally cached server manifests (only unanimous resource hashes) plus installed original SET/MDL summaries. No network access. Loose/Workshop override precedence and active server-manifest selection are not established by this offline inspector.'};
await fs.writeFile(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,output,models:models.length,
  materialPairs:[...new Set(models.flatMap(row=>row.materialPairs.map(JSON.stringify)))].map(JSON.parse),
  visibleMaterialPairs:[...new Set(models.flatMap(row=>row.visibleMaterialPairs.map(JSON.stringify)))].map(JSON.parse),
  differingVisibleParts:models.flatMap(row=>row.differingVisibleParts).slice(0,8),
  lightExamples:models.flatMap(row=>row.lights).slice(0,4)}));
}finally{reader?.close();}
