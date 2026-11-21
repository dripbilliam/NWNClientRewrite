import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {parseErf} from '../../src/resource_archive.js';import {parseGff} from '../../src/gff.js';import {typedGff,gffField as F,writeGff} from '../../src/gff_writer.js';
const home=path.resolve('runtime-logs/local-multiplayer-server'),module='GodotAtmos1',report=path.resolve('godot-client/reports/atmosphere-server-v1.json');
const outputs=[report,...['modules','nwm'].map(dir=>path.join(home,dir,module+(dir==='nwm'?'.nwm':'.mod')))];
for(const file of outputs){try{await fs.access(file);throw Error('Authored atmosphere fixture exists');}catch(e){if(e.code!=='ENOENT')throw e;}}
const source=await fs.readFile(path.join(home,'modules/GodotPortal1.mod'));assert.equal(createHash('sha256').update(source).digest('hex'),'398a09c4dc192f4e4d128e792ffeae1382cde3b925bd49d4ad204fd9e042a45c');
const entries=new Map(parseErf(source).entries),ifo=typedGff(parseGff(entries.get('module:2014')).root);ifo.fields.Mod_Name=F(12,'Godot Native Atmosphere');ifo.fields.Mod_Tag=F(10,module);entries.set('module:2014',writeGff('IFO ',ifo));
const areas=[];
for(const key of ['a','b']){
 const area=typedGff(parseGff(entries.get('dense_'+key+':2012')).root);
 const values={DayNightCycle:0,IsNight:key==='b'?1:0,SunAmbientColor:0x99aabb,SunDiffuseColor:0xddeeff,SunFogColor:0x668899,SunFogAmount:5,SunShadows:1,MoonAmbientColor:0x665544,MoonDiffuseColor:0x887766,MoonFogColor:0x443322,MoonFogAmount:15,MoonShadows:0,ShadowOpacity:40};
 for(const [name,value]of Object.entries(values)){assert.ok(area.fields[name],name);area.fields[name]=F(area.fields[name].type,value);}
 area.fields.FogClipDist=F(8,45);entries.set('dense_'+key+':2012',writeGff('ARE ',area));areas.push({area:'dense_'+key,...values,FogClipDist:45});
}
const count=entries.size,keys=160,resources=keys+count*24,start=resources+count*8,bytes=Buffer.alloc(start+[...entries.values()].reduce((n,v)=>n+v.length,0));bytes.write('MOD V1.0');bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);let cursor=start;
for(const[index,[key,value]]of[...entries].entries()){const split=key.lastIndexOf(':');bytes.write(key.slice(0,split),keys+index*24,16,'ascii');bytes.writeUInt32LE(index,keys+index*24+16);bytes.writeUInt16LE(Number(key.slice(split+1)),keys+index*24+20);bytes.writeUInt32LE(cursor,resources+index*8);bytes.writeUInt32LE(value.length,resources+index*8+4);bytes.set(value,cursor);cursor+=value.length;}
assert.equal(parseErf(bytes).entries.size,count);for(const file of outputs.slice(1))await fs.writeFile(file,bytes,{flag:'wx'});
const result={module,sha256:createHash('sha256').update(bytes).digest('hex'),areas,port:5121,scope:'Authored day/night fog through real native server area packets and click-driven A-B-A; no copied original models or textures'};
await fs.writeFile(report,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
