// Authored server script only. Read installed API signatures/constants; preserve
// the hashed prior authored module and reference original art by resref.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';import {parseGff} from '../../src/gff.js';import {typedGff,gffField as F,writeGff} from '../../src/gff_writer.js';import {parseScriptApi,parseNcs} from '../../src/ncs.js';import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const home=path.resolve('runtime-logs/local-multiplayer-server'),module='GodotFeedback1',name=process.argv.find(a=>a.startsWith('--report='))?.slice(9);
if(!/^[a-z0-9-]+\.json$/.test(name??''))throw Error('Provide unused report name');
const report=path.resolve('godot-client/reports',name),outputs=[path.join(home,'modules',module+'.mod'),path.join(home,'nwm',module+'.nwm')];
for(const file of [report,...outputs]){try{await fs.access(file);throw Error('Fixture exists');}catch(error){if(error.code!=='ENOENT')throw error;}}
const baseline=await fs.readFile(path.join(home,'modules/GodotParty1.mod')),prior=JSON.parse(await fs.readFile('godot-client/reports/party-server-fixture-v1.json'));assert.equal(createHash('sha256').update(baseline).digest('hex'),prior.sha256);
const entries=new Map(parseErf(baseline).entries),resolver=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')}),header=decodeResourceText(await resolver.getResource('nwscript',2009)),api=parseScriptApi(header);
const constant=name=>{const match=new RegExp('^int\\s+'+name+'\\s*=\\s*([0-9]+)\\s*;','m').exec(header);assert.ok(match,name);return Number(match[1]);};
const code=[],int=n=>{const b=Buffer.alloc(4);b.writeInt32BE(n);code.push(4,3,...b);},float=n=>{const b=Buffer.alloc(4);b.writeFloatBE(n);code.push(4,4,...b);},string=s=>{const b=Buffer.from(s,'ascii');code.push(4,5,b.length>>>8,b.length&255,...b);},action=(name,count)=>{const row=api.find(r=>r.name===name);assert.equal(row.args.length,count,name);code.push(5,0,row.id>>>8,row.id&255,count);};
string('-native-feedback');action('GetPCChatMessage',0);code.push(0x0b,0x23);const branch=code.length;code.push(0x1f,0,0,0,0,0);
float(0);action('GetPCChatSpeaker',0);int(constant('DAMAGE_POWER_NORMAL'));int(constant('DAMAGE_TYPE_FIRE'));int(3);action('EffectDamage',3);int(constant('DURATION_TYPE_INSTANT'));action('ApplyEffectToObject',4);
int(1);int(1);action('GetPCChatSpeaker',0);string('GODOT_FEEDBACK_PROMPT');action('FloatingTextStringOnCreature',4);
string('GODOT_FEEDBACK_DONE');action('GetPCChatSpeaker',0);action('SendMessageToPC',2);code.push(0x20,0);const tail=code.length;
code.push(...entries.get('godot_chat:2010').subarray(13));const body=Buffer.from(code);body.writeInt32BE(tail-branch,branch+2);const ncs=Buffer.alloc(13+body.length);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(ncs.length,9);ncs.set(body,13);parseNcs(ncs);entries.set('godot_chat:2010',ncs);
const ifo=typedGff(parseGff(entries.get('module:2014')).root);ifo.fields.Mod_Name=F(12,'Godot Native Feedback Options');ifo.fields.Mod_Tag=F(10,module);entries.set('module:2014',writeGff('IFO ',ifo));
const count=entries.size,keys=160,resources=keys+count*24,start=resources+count*8,bytes=Buffer.alloc(start+[...entries.values()].reduce((n,v)=>n+v.length,0));bytes.write('MOD V1.0');bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);let cursor=start;
for(const[index,[key,value]]of[...entries].entries()){const split=key.lastIndexOf(':');bytes.write(key.slice(0,split),keys+index*24,16,'ascii');bytes.writeUInt32LE(index,keys+index*24+16);bytes.writeUInt16LE(Number(key.slice(split+1)),keys+index*24+20);bytes.writeUInt32LE(cursor,resources+index*8);bytes.writeUInt32LE(value.length,resources+index*8+4);bytes.set(value,cursor);cursor+=value.length;}
assert.equal(parseErf(bytes).entries.size,count);for(const file of outputs)await fs.writeFile(file,bytes,{flag:'wx'});
const result={module,sha256:createHash('sha256').update(bytes).digest('hex'),command:'-native-feedback',damage:{amount:3,type:constant('DAMAGE_TYPE_FIRE')},prompt:'GODOT_FEEDBACK_PROMPT',scope:'Actual native server EffectDamage, ordinary chat and script floating prompt; no client-synthesized damage packets or copied original art'};
await fs.writeFile(report,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
