import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';
import {parseGff} from '../../src/gff.js';import {gffField as f,typedGff,writeGff} from '../../src/gff_writer.js';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';import {parseScriptApi,parseNcs} from '../../src/ncs.js';
const home=path.resolve('runtime-logs/local-multiplayer-server'),reportName=process.argv.find(arg=>arg.startsWith('--report='))?.slice(9);
if(!/^[a-z0-9-]+\.json$/.test(reportName??''))throw Error('Provide an unused --report name');
const output=path.join(home,'modules/GodotContainers.mod'),report=path.resolve('godot-client/reports',reportName);
for(const file of [output,report,path.join(home,'nwm/GodotContainers.nwm')]){try{await fs.access(file);throw Error('Authored fixture output exists');}catch(error){if(error.code!=='ENOENT')throw error;}}
const baseline=await fs.readFile(path.join(home,'modules/GodotVisuals.mod')),reference=JSON.parse(await fs.readFile('godot-client/reports/visual-server-fixture-v1.json'));
assert.equal(createHash('sha256').update(baseline).digest('hex'),reference.sha256);
const entries=new Map(parseErf(baseline).entries),resolver=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')});
assert.ok((await resolver.getResource('nw_cloth001',2025)).byteLength);
const api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',2009))),code=[],patches=[],labels=new Map();
const int=value=>{const bytes=Buffer.alloc(4);bytes.writeInt32BE(value);code.push(4,3,...bytes);},string=value=>{const bytes=Buffer.from(value,'ascii');code.push(4,5,bytes.length>>>8,bytes.length&255,...bytes);},action=(name,count)=>{const row=api.find(row=>row.name===name);assert.equal(row.args.length,count,name);code.push(5,0,row.id>>>8,row.id&255,count);},jump=(opcode,label)=>{patches.push({at:code.length,label});code.push(opcode,0,0,0,0,0);};
string('-native-chest');action('GetPCChatMessage',0);code.push(0x0b,0x23);jump(0x1f,'prior');
for(let index=0;index<8;index++){
 string('native_container_'+index);int(1);int(0);string('native_chest');action('GetObjectByTag',2);string('nw_cloth001');action('CreateItemOnObject',4);
 code.push(0x1b,0,255,255,255,252);
}
string('GODOT_CONTAINER_READY');action('GetPCChatSpeaker',0);action('SendMessageToPC',2);code.push(0x20,0);labels.set('prior',code.length);
code.push(...entries.get('godot_chat:2010').subarray(13));
const body=Buffer.from(code);for(const {at,label}of patches)body.writeInt32BE(labels.get(label)-at,at+2);
const ncs=Buffer.alloc(13+body.length);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(ncs.length,9);ncs.set(body,13);parseNcs(ncs);entries.set('godot_chat:2010',ncs);
const ifo=typedGff(parseGff(entries.get('module:2014')).root);ifo.fields.Mod_Name=f(12,'Godot Containers');ifo.fields.Mod_Tag=f(10,'GodotContainers');entries.set('module:2014',writeGff('IFO ',ifo));
const git=typedGff(parseGff(entries.get('dense_a:2023')).root),chest=git.fields['Placeable List'].value[0];
chest.fields.Tag=f(10,'native_chest');chest.fields.LocName=f(12,'Native container chest');chest.fields.Appearance=f(4,7);chest.fields.HasInventory=f(0,1);chest.fields.Useable=f(0,1);chest.fields.Static=f(0,0);chest.fields.X=f(8,52);chest.fields.Y=f(8,40);entries.set('dense_a:2023',writeGff('GIT ',git));
const count=entries.size,keys=160,resources=keys+count*24,start=resources+count*8,bytes=Buffer.alloc(start+[...entries.values()].reduce((sum,value)=>sum+value.length,0));bytes.write('MOD V1.0');bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);let cursor=start;
for(const [index,[key,value]]of [...entries].entries()){const split=key.lastIndexOf(':');bytes.write(key.slice(0,split),keys+index*24,16,'ascii');bytes.writeUInt32LE(index,keys+index*24+16);bytes.writeUInt16LE(Number(key.slice(split+1)),keys+index*24+20);bytes.writeUInt32LE(cursor,resources+index*8);bytes.writeUInt32LE(value.length,resources+index*8+4);bytes.set(value,cursor);cursor+=value.length;}
assert.equal(parseErf(bytes).entries.size,count);await fs.writeFile(output,bytes,{flag:'wx'});await fs.writeFile(path.join(home,'nwm/GodotContainers.nwm'),bytes,{flag:'wx'});
const result={scope:'Authored local fixture; installed clothing templates/models are referenced only; server creates actual chest items',module:'GodotContainers',sha256:createHash('sha256').update(bytes).digest('hex'),command:'-native-chest',items:8,template:'nw_cloth001',position:[52,40,0],appearance:7};await fs.writeFile(report,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
