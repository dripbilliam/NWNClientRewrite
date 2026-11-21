// All module/dialogue/script bytes below are authored. Installed art, tables
// and the script API are read or referenced, never copied into this module.
import fs from 'node:fs/promises';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';
import {parseGff} from '../../src/gff.js';import {typedGff,gffField as f,gffRecord as record,writeGff,encodeGffText} from '../../src/gff_writer.js';
import {parseConversation} from '../../src/conversation.js';import {parseScriptApi,parseNcs} from '../../src/ncs.js';
import {decodeGffText} from '../../src/gff_text.js';import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const root=path.resolve('.'),home=path.join(root,'runtime-logs/local-multiplayer-server');
const reportName=process.argv.find(a=>a.startsWith('--report='))?.slice(9)??'gameplay-server-fixture-v1.json';
if(!/^[a-z0-9-]+\.json$/.test(reportName))throw Error('Invalid fixture report name');
const report=path.join(root,'godot-client/reports',reportName);
try{await fs.access(report);throw Error('Fixture report already exists');}catch(e){if(e.code!=='ENOENT')throw e;}
const baseline=await fs.readFile(path.join(home,'modules/GodotLifecycle.mod')),reference=JSON.parse(await fs.readFile(path.join(root,'godot-client/reports/lifecycle-server-fixture-v3.json')));
assert.equal(crypto.createHash('sha256').update(baseline).digest('hex'),reference.sha256);
const entries=new Map(parseErf(baseline).entries),resolver=await openServerResourceContext({install:path.resolve(root,'../FullDecomp/NwnRootInstall')});
const api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',2009)));
function script(build){
 const code=[],fix=[],labels=new Map(),s={
  int(n){const b=Buffer.alloc(4);b.writeInt32BE(n);code.push(4,3,...b);},
  object(n){const b=Buffer.alloc(4);b.writeUInt32BE(n);code.push(4,6,...b);},
  discard(){code.push(0x1b,0,0xff,0xff,0xff,0xfc);},
  string(value){const b=encodeGffText(value);code.push(4,5,b.length>>>8,b.length&255,...b);},
  action(name,argc){const a=api.find(row=>row.name===name);assert.ok(a,name);assert.equal(a.args.length,argc,name);code.push(5,0,a.id>>>8,a.id&255,argc);},
  equalString(){code.push(0x0b,0x23);},
  jump(op,label){fix.push({at:code.length,label});code.push(op,0,0,0,0,0);},
  label(name){labels.set(name,code.length);},
  assign(name,body){code.push(0x2c,16,0,0,0,0,0,0,0,0);s.jump(0x1d,name);body();code.push(0x20,0);s.label(name);s.action('GetPCChatSpeaker',0);s.action('AssignCommand',2);}
 };build(s);code.push(0x20,0);const body=Buffer.from(code);for(const{at,label}of fix){assert.ok(labels.has(label));body.writeInt32BE(labels.get(label)-at,at+2);}const out=Buffer.alloc(13+body.length);out.write('NCS V1.0');out[8]=0x42;out.writeUInt32BE(out.length,9);out.set(body,13);parseNcs(out);return out;
}
const rgb=(r,g,b)=>decodeGffText(Uint8Array.of(60,99,r,g,b,62)),blue=rgb(135,206,235),green=rgb(1,255,1),yellow=rgb(255,255,1);
const message=(s,value)=>{s.string(value);s.action('GetPCSpeaker',0);s.action('SendMessageToPC',2);};
// Original nw_c2_default4 calls BeginConversation with OBJECT_INVALID in its
// dialogue event (body offsets 214 / 295, header-inclusive ACTION 227 / 308).
// GetPCSpeaker is a DLG-script owner; it is not valid before dialogue starts.
// Script SetCustomToken protects reserved IDs 0..9; use an ordinary ID.
entries.set('godot_talk:2010',script(s=>{s.string('token-ready');s.int(77);s.action('SetCustomToken',2);s.object(1);s.string('godot_dialog');s.action('BeginConversation',2);s.discard();}));
entries.set('godot_pick:2010',script(s=>{message(s,'GODOT_PICK_ACK');s.int(1);s.int(0);s.action('GetPCSpeaker',0);s.string('Select a slot: '+yellow+'server prompt</c>');s.action('FloatingTextStringOnCreature',4);}));
entries.set('godot_end:2010',script(s=>message(s,'GODOT_END_ACK')));
entries.set('godot_abort:2010',script(s=>message(s,'GODOT_ABORT_ACK')));
entries.set('godot_chat:2010',script(s=>{
 for(const command of ['text','a','b']){
  s.string('-native-'+command);s.action('GetPCChatMessage',0);s.equalString();s.jump(0x1f,'end_'+command);
  if(command==='text'){
   s.string(green+'GODOT_CHAT_ACK</c>');s.action('GetPCChatSpeaker',0);s.action('SendMessageToPC',2);
   s.int(1);s.int(0);s.action('GetPCChatSpeaker',0);s.string(blue+'GODOT_FLOAT_ACK</c>');s.action('FloatingTextStringOnCreature',4);
  }else s.assign('assigned_'+command,()=>{s.string('entry_'+command);s.action('GetWaypointByTag',1);s.action('GetLocation',1);s.action('JumpToLocation',1);});
  s.label('end_'+command);
 }
}));
const link=(index,start=false)=>record({Index:f(4,index),Active:f(11,''),...(start?{}:{IsChild:f(0,0),LinkComment:f(10,'')})},0);
const node=(text,links,reply=false,action='')=>record({...(reply?{}:{Speaker:f(10,'')}),Animation:f(4,0xffffffff),AnimLoop:f(0,0),Text:f(12,text),Script:f(11,action),Delay:f(4,0xffffffff),Comment:f(10,'Authored Godot integration test'),Sound:f(11,''),Quest:f(10,''),[reply?'EntriesList':'RepliesList']:f(15,links)},reply?1:0);
const dlg=writeGff('DLG ',record({DelayEntry:f(4,0),DelayReply:f(4,0),NumWords:f(4,0),EndConversation:f(11,'godot_end'),EndConverAbort:f(11,'godot_abort'),EntryList:f(15,[node(blue+'FIRST_ENTRY</c> Hello <FirstName>, <CUSTOM77>.\nChoose '+green+'a server reply</c>.',[link(0),link(1)]),node(blue+'SECOND_ENTRY</c> '+yellow+'Your reply reached the native server.</c>',[link(1)])]),ReplyList:f(15,[node(green+'Choose first</c>',[link(1)],true,'godot_pick'),node(yellow+'Finish</c>',[],true)]),StartingList:f(15,[link(0,true)])}));
assert.equal(parseConversation(dlg).EntryList.length,2);entries.set('godot_dialog:2029',dlg);
const ifo=typedGff(parseGff(entries.get('module:2014')).root);ifo.fields.Mod_Name=f(12,'Godot Gameplay');ifo.fields.Mod_Tag=f(10,'GodotGameplay');ifo.fields.Mod_Entry_Dir_X=f(8,1);ifo.fields.Mod_Entry_Dir_Y=f(8,0);entries.set('module:2014',writeGff('IFO ',ifo));
const npc=typedGff(parseGff(entries.get('godot_probe:2027')).root);npc.type=4;npc.fields.FirstName=f(12,'Native');npc.fields.LastName=f(12,'Speaker');npc.fields.Tag=f(10,'native_speaker');npc.fields.Conversation=f(11,'godot_dialog');npc.fields.ScriptDialogue=f(11,'godot_talk');npc.fields.Description=f(12,blue+'Attuned to Fire</c>\n\n'+green+'Server-authored examination</c>\nName: <FirstName>');npc.fields.XPosition=f(8,54);npc.fields.YPosition=f(8,42);
const git=typedGff(parseGff(entries.get('dense_a:2023')).root);git.fields['Creature List']=f(15,[npc]);entries.set('dense_a:2023',writeGff('GIT ',git));
const count=entries.size,keys=160,resources=keys+count*24,data=resources+count*8,bytes=Buffer.alloc(data+[...entries.values()].reduce((n,b)=>n+b.length,0));bytes.write('MOD V1.0');bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);let cursor=data;
for(const[i,[key,value]]of [...entries].entries()){const p=key.lastIndexOf(':');bytes.write(key.slice(0,p),keys+i*24,16,'ascii');bytes.writeUInt32LE(i,keys+i*24+16);bytes.writeUInt16LE(Number(key.slice(p+1)),keys+i*24+20);bytes.writeUInt32LE(cursor,resources+i*8);bytes.writeUInt32LE(value.length,resources+i*8+4);bytes.set(value,cursor);cursor+=value.length;}
assert.equal(parseErf(bytes).entries.size,count);for(const directory of ['modules','nwm'])await fs.writeFile(path.join(home,directory,directory==='modules'?'GodotGameplay.mod':'GodotGameplay.nwm'),bytes);
const result={scope:'Authored native-server dialogue/examine/prompt fixture; no simulated client replies or copied game assets',module:'GodotGameplay',port:5121,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),npc:[54,42,0],commands:['-native-text','-native-a','-native-b'],dialogueEntries:2,dialogueReplies:2};await fs.writeFile(report,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
