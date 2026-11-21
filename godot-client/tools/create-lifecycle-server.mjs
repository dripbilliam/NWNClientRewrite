// Derives only from our entirely authored DensePerf fixture, never a game
// module. Installed models/items are referenced by resref and not copied.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
import {decodeResourceText,parseErf} from '../../src/resource_archive.js';
import {parseScriptApi,parseNcs} from '../../src/ncs.js';
import {parseGff} from '../../src/gff.js';
import {gffField as f,typedGff,writeGff} from '../../src/gff_writer.js';
const root=path.resolve('.'),home=path.join(root,'runtime-logs/local-multiplayer-server');
const reportName=process.argv.find(a=>a.startsWith('--report='))?.slice(9)??'lifecycle-server-fixture-v3.json';
if(!/^[a-z0-9-]+\.json$/.test(reportName))throw Error('Invalid fixture report name');
const reportPath=path.join(root,'godot-client/reports',reportName);
try{await fs.access(reportPath);throw Error('Fixture report already exists');}catch(e){if(e.code!=='ENOENT')throw e;}
const authored=await fs.readFile(path.join(root,'runtime-logs/dense-performance-server/modules/DensePerf.mod'));
const reference=JSON.parse(await fs.readFile(path.join(root,'backups/animations/dense-server-fixture-v1.json'),'utf8'));
assert.equal(crypto.createHash('sha256').update(authored).digest('hex'),reference.sha256,'Authored fixture identity');
const source=parseErf(authored).entries;
const resolver=await openServerResourceContext({install:path.resolve(root,'../FullDecomp/NwnRootInstall')});
const api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',2009)));
assert.ok((await resolver.getResource('nw_cloth001',2025))?.byteLength,'Installed clothing template exists');
const code=[],fix=[],labels=new Map();
const int=n=>{const b=Buffer.alloc(4);b.writeInt32BE(n);code.push(4,3,...b);};
const float=n=>{const b=Buffer.alloc(4);b.writeFloatBE(n);code.push(4,4,...b);};
const string=s=>{const b=Buffer.from(s,'ascii');code.push(4,5,b.length>>>8,b.length&255,...b);};
const action=(name,argc)=>{const command=api.find(a=>a.name===name);assert.ok(command,name);assert.equal(command.args.length,argc,name);code.push(5,0,command.id>>>8,command.id&255,argc);};
const jump=(op,label)=>{fix.push({at:code.length,label});code.push(op,0,0,0,0,0);};
const probe=()=>{int(0);string('native_probe');action('GetObjectByTag',2);};
const assign=(name,body,target=probe)=>{code.push(0x2c,16,0,0,0,0,0,0,0,0);jump(0x1d,name);body();code.push(0x20,0);labels.set(name,code.length);target();action('AssignCommand',2);};
const commands=['spawn','shape','restore','equip','despawn','a','b'];
for(const command of commands){
 string('-native-'+command);action('GetPCChatMessage',0);code.push(0x0b,0x23);jump(0x1f,'end_'+command);
 if(command==='spawn'){
  string('native_probe');int(0);string('native_spawn');action('GetWaypointByTag',1);action('GetLocation',1);string('godot_probe');int(1);action('CreateObject',5);
  code.push(0x1b,0,0xff,0xff,0xff,0xfc); // discard returned object, not a fabricated ID
 }else if(command==='shape'||command==='restore'){
  int(command==='shape'?9:6);probe();action('SetCreatureAppearanceType',2);
 }else if(command==='despawn'){
  float(0);probe();action('DestroyObject',2);
 }else if(command==='equip')assign('equip_action',()=>{int(1);string('');int(1);probe();string('nw_cloth001');action('CreateItemOnObject',4);action('ActionEquipItem',2);});
 else assign('transfer_'+command,()=>{string('entry_'+command);action('GetWaypointByTag',1);action('GetLocation',1);action('JumpToLocation',1);},()=>action('GetPCChatSpeaker',0));
 labels.set('end_'+command,code.length);
}
code.push(0x20,0);
const body=Buffer.from(code);for(const{at,label}of fix)body.writeInt32BE(labels.get(label)-at,at+2);
const script=Buffer.alloc(13+body.length);script.write('NCS V1.0');script[8]=0x42;script.writeUInt32BE(script.length,9);script.set(body,13);parseNcs(script);
const ifo=typedGff(parseGff(source.get('module:2014')).root);
ifo.fields.Mod_Name=f(12,'Godot Lifecycle');ifo.fields.Mod_Tag=f(10,'GodotLifecycle');ifo.fields.Mod_OnPlrChat=f(11,'godot_chat');
const entries=new Map([['module:2014',writeGff('IFO ',ifo)],['godot_chat:2010',script]]);
let template;
for(const key of ['a','b']){
 const git=typedGff(parseGff(source.get(`dense_${key}:2023`)).root);
 if(!template){template=git.fields['Creature List'].value[0];template.type=0xffffffff;template.fields.FirstName=f(12,'Native');template.fields.LastName=f(12,'Probe');template.fields.Tag=f(10,'native_probe');template.fields.ScriptSpawn=f(11,'');template.fields.ScriptHeartbeat=f(11,'');}
 git.fields['Creature List']=f(15,[]);git.fields['Placeable List']=f(15,git.fields['Placeable List'].value.slice(0,2));
 if(key==='a'){const waypoint=structuredClone(git.fields.WaypointList.value[0]);waypoint.fields.Tag=f(10,'native_spawn');waypoint.fields.XPosition=f(8,53.5);waypoint.fields.YPosition=f(8,40);git.fields.WaypointList.value.push(waypoint);}
 entries.set(`dense_${key}:2023`,writeGff('GIT ',git));entries.set(`dense_${key}:2012`,source.get(`dense_${key}:2012`));
}
entries.set('godot_probe:2027',writeGff('UTC ',template));
const count=entries.size,keys=160,resources=keys+count*24,data=resources+count*8;
const bytes=Buffer.alloc(data+[...entries.values()].reduce((n,b)=>n+b.length,0));bytes.write('MOD V1.0');bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,20);bytes.writeUInt32LE(keys,24);bytes.writeUInt32LE(resources,28);let cursor=data;
for(const[i,[key,value]]of [...entries].entries()){const p=key.lastIndexOf(':');bytes.write(key.slice(0,p),keys+i*24,16,'ascii');bytes.writeUInt32LE(i,keys+i*24+16);bytes.writeUInt16LE(Number(key.slice(p+1)),keys+i*24+20);bytes.writeUInt32LE(cursor,resources+i*8);bytes.writeUInt32LE(value.length,resources+i*8+4);bytes.set(value,cursor);cursor+=value.length;}
assert.equal(parseErf(bytes).entries.size,count);
for(const directory of ['modules','nwm']){await fs.mkdir(path.join(home,directory),{recursive:true});await fs.writeFile(path.join(home,directory,directory==='modules'?'GodotLifecycle.mod':'GodotLifecycle.nwm'),bytes);}
const report={scope:'Authored local module with native server chat scripts; no client replication injection',module:'GodotLifecycle',port:5121,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),commands:commands.map(c=>'-native-'+c),resources:[...entries.keys()]};
await fs.writeFile(reportPath,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(report));
