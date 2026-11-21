import fs from 'node:fs/promises';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';
import {parseErf} from '../../src/resource_archive.js';import {parseGff} from '../../src/gff.js';import {typedGff,writeGff,gffField as field} from '../../src/gff_writer.js';
const home=path.resolve('runtime-logs/local-multiplayer-server'),reportName=process.argv.find(a=>a.startsWith('--report='))?.slice(9);
if(!/^[a-z0-9-]+\.json$/.test(reportName??''))throw Error('Use an unused report name');
const baseline=await fs.readFile(path.join(home,'modules/GodotGameplay.mod')),reference=JSON.parse(await fs.readFile('godot-client/reports/gameplay-server-fixture-v3.json'));
assert.equal(crypto.createHash('sha256').update(baseline).digest('hex'),reference.sha256);
const entries=new Map(parseErf(baseline).entries),ifo=typedGff(parseGff(entries.get('module:2014')).root);ifo.fields.Mod_Name=field(12,'Godot Combat');ifo.fields.Mod_Tag=field(10,'GodotCombat');entries.set('module:2014',writeGff('IFO ',ifo));
const git=typedGff(parseGff(entries.get('dense_a:2023')).root),npc=git.fields['Creature List'].value[0];
for(const name of ['HitPoints','CurrentHitPoints','MaxHitPoints']){assert.ok(npc.fields[name]);npc.fields[name].value=2000;}
npc.fields.Plot.value=0;npc.fields.IsImmortal.value=1;entries.set('dense_a:2023',writeGff('GIT ',git));
const count=entries.size,keys=160,resources=keys+count*24,start=resources+count*8,bytes=Buffer.alloc(start+[...entries.values()].reduce((n,b)=>n+b.length,0));bytes.write('MOD V1.0');bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);let cursor=start;
for(const[i,[key,value]]of [...entries].entries()){const p=key.lastIndexOf(':');bytes.write(key.slice(0,p),keys+i*24,16,'ascii');bytes.writeUInt32LE(i,keys+i*24+16);bytes.writeUInt16LE(Number(key.slice(p+1)),keys+i*24+20);bytes.writeUInt32LE(cursor,resources+i*8);bytes.writeUInt32LE(value.length,resources+i*8+4);bytes.set(value,cursor);cursor+=value.length;}
assert.equal(parseGff(parseErf(bytes).entries.get('dense_a:2023')).root['Creature List'][0].MaxHitPoints,2000);
const result={scope:'Entirely authored local gameplay fixture with a passive immortal 2000-HP combat target; original game assets are only referenced',module:'GodotCombat',sha256:crypto.createHash('sha256').update(bytes).digest('hex'),baseline:reference.sha256,port:5121};
await fs.writeFile(path.join('godot-client/reports',reportName),JSON.stringify(result,null,2)+'\n',{flag:'wx'});for(const dir of ['modules','nwm'])await fs.writeFile(path.join(home,dir,dir==='modules'?'GodotCombat.mod':'GodotCombat.nwm'),bytes);
console.log(JSON.stringify(result));
