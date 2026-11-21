// Authored module records only. Installed models/WOK/PWK are referenced, not copied.
import fs from 'node:fs/promises';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';
import {parseErf} from '../../src/resource_archive.js';import {parseGff} from '../../src/gff.js';import {typedGff,gffField as f,writeGff} from '../../src/gff_writer.js';
const root=path.resolve('.'),home=path.join(root,'runtime-logs/local-multiplayer-server'),report=path.join(root,'godot-client/reports/movement-server-fixture-v1.json');
try{await fs.access(report);throw Error('Fixture report already exists');}catch(e){if(e.code!=='ENOENT')throw e;}
const baseline=await fs.readFile(path.join(home,'modules/GodotLifecycle.mod')),reference=JSON.parse(await fs.readFile(path.join(root,'godot-client/reports/lifecycle-server-fixture-v3.json')));
assert.equal(crypto.createHash('sha256').update(baseline).digest('hex'),reference.sha256);
const entries=new Map(parseErf(baseline).entries),ifo=typedGff(parseGff(entries.get('module:2014')).root);
ifo.fields.Mod_Name=f(12,'Godot Movement');ifo.fields.Mod_Tag=f(10,'GodotMovement');ifo.fields.Mod_Entry_Dir_X=f(8,1);ifo.fields.Mod_Entry_Dir_Y=f(8,0);entries.set('module:2014',writeGff('IFO ',ifo));
const git=typedGff(parseGff(entries.get('dense_a:2023')).root);
for(const [i,prop] of git.fields['Placeable List'].value.entries()){prop.fields.Appearance=f(4,7);prop.fields.X=f(8,i?55:53);prop.fields.Y=f(8,i?44:40);prop.fields.LocName=f(12,'Native collision chest');}
entries.set('dense_a:2023',writeGff('GIT ',git));
const count=entries.size,keys=160,resources=keys+count*24,data=resources+count*8,bytes=Buffer.alloc(data+[...entries.values()].reduce((n,b)=>n+b.length,0));bytes.write('MOD V1.0');bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);let cursor=data;
for(const [i,[key,value]]of [...entries].entries()){const p=key.lastIndexOf(':');bytes.write(key.slice(0,p),keys+i*24,16,'ascii');bytes.writeUInt32LE(i,keys+i*24+16);bytes.writeUInt16LE(Number(key.slice(p+1)),keys+i*24+20);bytes.writeUInt32LE(cursor,resources+i*8);bytes.writeUInt32LE(value.length,resources+i*8+4);bytes.set(value,cursor);cursor+=value.length;}
assert.equal(parseErf(bytes).entries.size,count);
for(const directory of ['modules','nwm'])await fs.writeFile(path.join(home,directory,directory==='modules'?'GodotMovement.mod':'GodotMovement.nwm'),bytes);
const result={scope:'Authored native server movement fixture with original chest PWK, no client collision injection',module:'GodotMovement',port:5121,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),spawn:[50,40,0],facing:[1,0,0],chests:[[53,40,0],[55,44,0]],appearance:7};await fs.writeFile(report,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
