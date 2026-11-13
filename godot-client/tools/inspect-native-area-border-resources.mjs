// Read-only installed KEY/BIF tables and SET metadata. No model/art copies.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {parseKey} from '../../src/resource_archive.js';
import {parse2da} from '../../src/area.js';
const root=path.resolve('.'),install=path.resolve('../FullDecomp/NwnRootInstall'),resources=new Map(),keys=[];
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
for(const name of ['data/nwn_retail.key','data/nwn_base.key']){
 const bytes=await fs.readFile(path.join(install,name)),key=parseKey(bytes);keys.push({name,sha256:hash(bytes)});
 for(const [id,row]of key.resources)if(!resources.has(id))resources.set(id,{...row,bif:key.bifNames[row.bifIndex]});
}
async function read(name,type){
 const row=resources.get(name+':'+type);if(!row)throw Error('Missing installed original '+name+':'+type);
 const file=await fs.open(path.join(install,row.bif),'r');
 try{const header=Buffer.alloc(20);await file.read(header,0,20,0);const v11=header.toString('ascii',4,8)==='V1.1',stride=v11?20:16,p=v11?8:4,entry=Buffer.alloc(stride);await file.read(entry,0,stride,header.readUInt32LE(16)+row.resourceIndex*stride);if(entry.readUInt32LE(p+8)!==type)throw Error('Native BIF type mismatch');const bytes=Buffer.alloc(entry.readUInt32LE(p+4));if((await file.read(bytes,0,bytes.length,entry.readUInt32LE(p))).bytesRead!==bytes.length)throw Error('Truncated native BIF');return bytes;}finally{await file.close();}
}
function ini(text){let current='';const sections={};for(const raw of text.replaceAll('\r','').split('\n')){const line=raw.trim();if(line.startsWith('[')&&line.endsWith(']')){current=line.slice(1,-1).toUpperCase();sections[current]??={};}else{const at=line.indexOf('=');if(at>0&&current)sections[current][line.slice(0,at).trim()]=line.slice(at+1).trim();}}return sections;}
const names=[...resources.keys()].filter(id=>id.endsWith('_edge:2017')).map(id=>id.split(':')[0]).sort(),samples=[];
const chosen=[...new Set(['ttr01_edge','ttf01_edge','tcn01_edge',...names].filter(name=>names.includes(name)))].slice(0,4);
for(const name of chosen){
 const setName=name.slice(0,-5);if(!resources.has(setName+':2013'))continue;
 const raw=await read(name,2017),set=await read(setName,2013),table=parse2da(raw.toString('latin1')),sections=ini(set.toString('latin1'));
 const tiles=Array.from({length:Number(sections.TILES.Count)},(_,id)=>({id,...sections['TILE'+id]}));
 samples.push({name,setName,tableSha256:hash(raw),setSha256:hash(set),defaultValue:table.defaultValue,columns:table.columns,rows:table.orderedRows,rawTableText:raw.toString('latin1'),general:sections.GENERAL,tiles});
}
for(const key of keys)if(hash(await fs.readFile(path.join(install,key.name)))!==key.sha256)throw Error('Source KEY changed');
const output=path.join(root,'godot-client/reports/native-area-border-installed-v1.json');
await fs.writeFile(output,JSON.stringify({schema:'native-area-border-installed-v1',scope:'Installed raw SET/Edge2DA values only; no game engine/network/model/art copy',keys,availableEdgeTables:names,samples},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({output,available:names.length,samples:samples.map(s=>({name:s.name,rows:s.rows.length,tiles:s.tiles.length,columns:s.columns,general:s.general,firstTile:s.tiles[0],firstRows:s.rows.slice(0,3)}))}));
