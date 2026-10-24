// Authored loopback ActivatePortal fixtures; original art remains resource refs.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';import {parseGff} from '../../src/gff.js';import {typedGff,gffField as F,writeGff} from '../../src/gff_writer.js';import {parseScriptApi,parseNcs} from '../../src/ncs.js';import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const home=path.resolve('runtime-logs/local-multiplayer-server'),other=path.resolve('runtime-logs/godot-handoff-server-b'),report=path.resolve('godot-client/reports/handoff-server-fixtures-v1.json');
const source=await fs.readFile(path.join(home,'modules/GodotFeedback1.mod'));assert.equal(createHash('sha256').update(source).digest('hex'),'0923e003ef612d80e5b1423661b05ab6492cbc4ff95edf7e9857751b3fe2a237');
const resolver=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')}),api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',2009)));
try{await fs.access(report);throw Error('Authored handoff fixture report exists');}catch(e){if(e.code!=='ENOENT')throw e;}
const rows=[],writes=[];
for(const [label,profile,port,destination,entry,waypoint]of [['A',home,5121,5122,'dense_a','ArrivalA'],['B',other,5122,5121,'dense_b','ArrivalB']]){
 const module='GodotHand'+label+'1',outputs=['modules','nwm'].map(dir=>path.join(profile,dir,module+(dir==='nwm'?'.nwm':'.mod')));
 const entries=new Map(parseErf(source).entries),ifo=typedGff(parseGff(entries.get('module:2014')).root);
 ifo.fields.Mod_Name=F(12,'Godot Handoff '+label);ifo.fields.Mod_Tag=F(10,module);ifo.fields.Mod_Entry_Area=F(11,entry);entries.set('module:2014',writeGff('IFO ',ifo));
 const git=typedGff(parseGff(entries.get(entry+':2023')).root),arrival=structuredClone(git.fields.WaypointList.value[0]);
 Object.assign(arrival.fields,{Tag:F(10,waypoint),XPosition:F(8,52),YPosition:F(8,40)});git.fields.WaypointList.value.push(arrival);
 // Both servers need the same authored conversation speaker for post-transfer
 // dialogue/examine checks; no original creature data is copied.
 if(label==='B'){const a=typedGff(parseGff(entries.get('dense_a:2023')).root);git.fields['Creature List']=structuredClone(a.fields['Creature List']);}
 entries.set(entry+':2023',writeGff('GIT ',git));
 const code=[],int=n=>{const b=Buffer.alloc(4);b.writeInt32BE(n);code.push(4,3,...b);},string=s=>{const b=Buffer.from(s,'ascii');code.push(4,5,b.length>>>8,b.length&255,...b);},action=(name,n)=>{const row=api.find(v=>v.name===name);assert.equal(row.args.length,n,name);code.push(5,0,row.id>>>8,row.id&255,n);};
 string('-native-portal');action('GetPCChatMessage',0);code.push(0x0b,0x23);const branch=code.length;code.push(0x1f,0,0,0,0,0);
 int(1);string(label==='A'?'ArrivalB':'ArrivalA');string('');string('127.0.0.1:'+destination);action('GetPCChatSpeaker',0);action('ActivatePortal',5);code.push(0x20,0);const tail=code.length;code.push(...entries.get('godot_chat:2010').subarray(13));
 const body=Buffer.from(code);body.writeInt32BE(tail-branch,branch+2);const ncs=Buffer.alloc(13+body.length);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(ncs.length,9);ncs.set(body,13);parseNcs(ncs);entries.set('godot_chat:2010',ncs);
 const count=entries.size,keys=160,resources=keys+count*24,start=resources+count*8,bytes=Buffer.alloc(start+[...entries.values()].reduce((n,v)=>n+v.length,0));bytes.write('MOD V1.0');bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);let cursor=start;
 for(const[index,[key,value]]of[...entries].entries()){const split=key.lastIndexOf(':');bytes.write(key.slice(0,split),keys+index*24,16,'ascii');bytes.writeUInt32LE(index,keys+index*24+16);bytes.writeUInt16LE(Number(key.slice(split+1)),keys+index*24+20);bytes.writeUInt32LE(cursor,resources+index*8);bytes.writeUInt32LE(value.length,resources+index*8+4);bytes.set(value,cursor);cursor+=value.length;}
 assert.equal(parseErf(bytes).entries.size,count);for(const file of outputs){try{assert.deepEqual(await fs.readFile(file),bytes,'An existing handoff fixture differs');}catch(e){if(e.code!=='ENOENT')throw e;writes.push({file,bytes});}}
 rows.push({label,module,profile,port,destination,entry,arrival:{waypoint,position:[52,40,0]},sha256:createHash('sha256').update(bytes).digest('hex')});
}
const result={version:1,servers:rows,command:'-native-portal',scope:'Two owned loopback native servers; real ActivatePortal/character/waypoint flow; authored modules with original model/texture references only'};
for(const {file,bytes}of writes){await fs.mkdir(path.dirname(file),{recursive:true});await fs.writeFile(file,bytes,{flag:'wx'});}
await fs.writeFile(report,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
