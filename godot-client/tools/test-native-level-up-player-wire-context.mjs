import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import {NativeMessageReader,NativeMessageWriter} from '../../src/native_message.js';
import {readPlayerState} from '../../src/network_player_state.js';
import {networkLevelUpSnapshot} from '../../src/network_level_up.js';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project),label=process.argv[2];
if(!/^[a-z0-9-]{3,80}$/.test(label??''))throw Error('Supply a unique evidence label');
const directory=path.join(project,'.cache/level-up-player-wire-context',label),copy=path.join(directory,'inputs');if(fs.existsSync(directory))throw Error('Existing evidence preserved');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),inputs=new Map();
function include(file){file=path.resolve(file);if(inputs.has(file))return;if(!file.startsWith(workspace+path.sep))throw Error('Input leaves workspace');const bytes=fs.readFileSync(file);inputs.set(file,{path:path.relative(workspace,file).replaceAll('\\','/'),sha256:hash(bytes)});const text=bytes.toString();if(file.endsWith('.gd')){for(const match of text.matchAll(/(?:preload|load)\s*\(\s*["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));for(const match of text.matchAll(/extends\s+["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));}if(/\.(?:mjs|js)$/.test(file))for(const match of text.matchAll(/\bfrom\s*["'](\.[^"']+)["']/g))include(path.resolve(path.dirname(file),match[1]));}
include(path.join(project,'tests/native_level_up_player_wire_context_test.gd'));include(fileURLToPath(import.meta.url));
for(const [file,row]of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);if(hash(fs.readFileSync(target))!==row.sha256)throw Error('Source changed during copy');}
const rows=[];
for(const bit of [1,0]){
 const writer=new NativeMessageWriter(1);writer.create(128,0xffffffff,1);writer.writeObjectIdClient(42);writer.writeWord(1);writer.writeWord(10);writer.writeDword(0);writer.writeInt(0);writer.writeBool(bit);
 if(bit){writer.writeWord(0);writer.writeByte(1);writer.writeByte(2);writer.writeInt(-1);writer.writeStringBytes(new Uint8Array());writer.writeInt(-1);writer.writeStringBytes(new Uint8Array());writer.writeDword(0);writer.writeByte(0);}
 const bytes=writer.getWriteMessage().data.subarray(3),reader=new NativeMessageReader(1);reader.setReadMessage(bytes,bytes.length,0xffffffff,1);
 const decoded=readPlayerState(reader,{number:8193,revision:37,postfix:17},{skillCount:2});
 if(decoded.id!==42||decoded.mask!==1||decoded.state.combat.canLevelUp!==bit||typeof decoded.state.combat.canLevelUp!=='number'||reader.messageReadOverflow()||reader.messageReadUnderflow())throw Error('Real decoded I-mask1 fixture differs');
 const actor={id:42,objectType:5,areaId:7,nativeLifetime:9,clientKnownLifetime:10,inventoryStats:{},replicated:{stats:{classes:[{id:3,level:2,school:0}],racialType:0,fieldDE4:30,fieldDE6:70}},playerState:{...decoded.state,abilities:{base:[14,14,14,14,14,14]},feats:[0,1],spellbooks:{0:{known:[2]}}}};
 let snapshot,ready=true;try{snapshot=networkLevelUpSnapshot(actor);}catch{ready=false;}
 rows.push({name:'native-bit'+bit,actor,ready,snapshot,packetSha256:hash(bytes),packetBytes:bytes.length});
}
const fixture=JSON.stringify({rows},null,2)+'\n',fixturePath=path.join(directory,'actual-i-mask1.json');fs.writeFileSync(fixturePath,fixture);
const copiedProject=path.join(copy,'godot-client');fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Level Up Player Wire Context"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(engine));if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected engine');
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log'),child=spawnSync(engine,['--headless','--path',copiedProject,'--log-file',log,'--script','res://tests/native_level_up_player_wire_context_test.gd','--','--report='+report,'--fixture='+fixturePath],{windowsHide:true,timeout:20000,encoding:'utf8'});
fs.writeFileSync(path.join(directory,'stdout.log'),child.stdout??'');fs.writeFileSync(path.join(directory,'stderr.log'),child.stderr??'');
const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,engineLog=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'',clean=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(engineLog+'\n'+child.stderr),changed=[...inputs].filter(([file,row])=>hash(fs.readFileSync(file))!==row.sha256).map(([,row])=>row.path),changedCopies=[...inputs.values()].filter(row=>hash(fs.readFileSync(path.join(copy,row.path)))!==row.sha256).map(row=>row.path);
const proof={success:child.status===0&&!child.error&&clean&&result?.success===true&&!changed.length&&!changedCopies.length,checks:result?.checks??0,failures:result?.failures??[],inputs:[...inputs.values()],changedInputs:changed,changedCopies,fixtureSha256:hash(fixture),cleanEngine:clean,exitCode:child.status,error:child.error?.message??null,engineSha256,serverConnections:0,gpu:false,nativeBuilds:0,scope:result?.scope??'No completed wire projection result.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:proof.inputs.length}));process.exitCode=proof.success?0:1;
