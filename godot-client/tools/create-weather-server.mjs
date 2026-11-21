// Authored fixture bytecode. Installed nwscript signatures are read-only;
// all resources/art remain references, and the prior authored module is hashed.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';import {parseGff} from '../../src/gff.js';import {typedGff,gffField as F,writeGff} from '../../src/gff_writer.js';import {parseScriptApi,parseNcs} from '../../src/ncs.js';import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const module='GodotWeather1',home=path.resolve('runtime-logs/local-multiplayer-server'),name=process.argv.find(v=>v.startsWith('--report='))?.slice(9);
if(!/^[a-z0-9-]+\.json$/.test(name??''))throw Error('Provide unused report name');
const outputs=[path.join(home,'modules',module+'.mod'),path.join(home,'nwm',module+'.nwm')],report=path.resolve('godot-client/reports',name);
for(const p of [...outputs,report]){try{await fs.access(p);throw Error('Output exists');}catch(e){if(e.code!=='ENOENT')throw e;}}
const baseline=await fs.readFile(path.join(home,'modules/GodotFeedback1.mod'));assert.equal(createHash('sha256').update(baseline).digest('hex'),'0923e003ef612d80e5b1423661b05ab6492cbc4ff95edf7e9857751b3fe2a237');
const entries=new Map(parseErf(baseline).entries),context=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')}),api=parseScriptApi(decodeResourceText(await context.getResource('nwscript',2009)));
function builder(){const code=[];return{code,int(v){const b=Buffer.alloc(4);b.writeInt32BE(v);code.push(4,3,...b);},float(v){const b=Buffer.alloc(4);b.writeFloatBE(v);code.push(4,4,...b);},string(v){const b=Buffer.from(v,'ascii');code.push(4,5,b.length>>>8,b.length&255,...b);},action(name,count){const row=api.find(v=>v.name===name);assert.equal(row.args.length,count,name);code.push(5,0,row.id>>>8,row.id&255,count);},finish(){code.push(0x20,0);const b=Buffer.alloc(13+code.length);b.write('NCS V1.0');b[8]=0x42;b.writeUInt32BE(b.length,9);b.set(code,13);parseNcs(b);return b;}};}
const pc=b=>b.action('GetPCChatSpeaker',0),weather=(b,type)=>{b.int(type);pc(b);b.action('GetArea',1);b.action('SetWeather',2);};
// Constants and parameter order checked against the installed read-only nwscript.
const phases={rain:b=>weather(b,1),snow:b=>weather(b,2),clear:b=>weather(b,0)};
const chat=builder(),fix=[];let index=0;
for(const [phase,write]of Object.entries(phases)){const script='gd_wthr_'+(++index),b=builder();write(b);b.string('GODOT_WEATHER_'+phase.toUpperCase());pc(b);b.action('SendMessageToPC',2);entries.set(script+':2010',b.finish());
 chat.string('-native-weather-'+phase);chat.action('GetPCChatMessage',0);chat.code.push(0x0b,0x23);const at=chat.code.length;chat.code.push(0x1f,0,0,0,0,0);pc(chat);chat.string(script);chat.action('ExecuteScript',2);chat.code.push(0x20,0);fix.push({at,to:chat.code.length});
}
chat.code.push(...entries.get('godot_chat:2010').subarray(13));const body=Buffer.from(chat.code);for(const {at,to}of fix)body.writeInt32BE(to-at,at+2);const ncs=Buffer.alloc(13+body.length);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(ncs.length,9);ncs.set(body,13);parseNcs(ncs);entries.set('godot_chat:2010',ncs);
const ifo=typedGff(parseGff(entries.get('module:2014')).root);ifo.fields.Mod_Name=F(12,'Godot Native Weather Commands');ifo.fields.Mod_Tag=F(10,module);entries.set('module:2014',writeGff('IFO ',ifo));
const count=entries.size,keys=160,resources=keys+count*24,start=resources+count*8,bytes=Buffer.alloc(start+[...entries.values()].reduce((n,v)=>n+v.length,0));bytes.write('MOD V1.0');bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);let cursor=start;
for(const[index,[key,value]]of[...entries].entries()){const split=key.lastIndexOf(':');bytes.write(key.slice(0,split),keys+index*24,16,'ascii');bytes.writeUInt32LE(index,keys+index*24+16);bytes.writeUInt16LE(Number(key.slice(split+1)),keys+index*24+20);bytes.writeUInt32LE(cursor,resources+index*8);bytes.writeUInt32LE(value.length,resources+index*8+4);bytes.set(value,cursor);cursor+=value.length;}
assert.equal(parseErf(bytes).entries.size,count);for(const file of outputs)await fs.writeFile(file,bytes,{flag:'wx'});
const result={module,sha256:createHash('sha256').update(bytes).digest('hex'),commands:Object.keys(phases).map(v=>'-native-weather-'+v),scope:'Actual native server SetWeather clear/rain/snow messages via authored PC-executed scripts; no synthesized client weather packets or copied art'};await fs.writeFile(report,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
