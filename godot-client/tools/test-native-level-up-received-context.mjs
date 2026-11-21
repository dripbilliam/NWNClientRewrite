import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import {networkLevelUpSnapshot} from '../../src/network_level_up.js';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project),label=process.argv[2];
if(!/^[a-z0-9-]{3,80}$/.test(label??''))throw Error('Supply a unique evidence label');
const directory=path.join(project,'.cache/level-up-received-context',label),copy=path.join(directory,'inputs');if(fs.existsSync(directory))throw Error('Existing evidence preserved');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),inputs=new Map();
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;if(!file.startsWith(workspace+path.sep))throw Error('Input leaves workspace');
 const bytes=fs.readFileSync(file);inputs.set(file,{path:path.relative(workspace,file).replaceAll('\\','/'),sha256:hash(bytes)});
 const source=bytes.toString();
 if(file.endsWith('.gd')){for(const m of source.matchAll(/(?:preload|load)\s*\(\s*["']res:\/\/([^"']+)["']/g))include(path.join(project,m[1]));for(const m of source.matchAll(/extends\s+["']res:\/\/([^"']+)["']/g))include(path.join(project,m[1]));}
 if(/\.(?:mjs|js)$/.test(file))for(const m of source.matchAll(/\bfrom\s*["'](\.[^"']+)["']/g))include(path.resolve(path.dirname(file),m[1]));
}
include(path.join(project,'tests/native_level_up_received_context_test.gd'));include(fileURLToPath(import.meta.url));
for(const[file,row]of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);if(hash(fs.readFileSync(target))!==row.sha256)throw Error('Source changed during copy');}
const actor={id:42,objectType:5,areaId:7,nativeLifetime:9,clientKnownLifetime:10,inventoryStats:{},replicated:{stats:{classes:[{id:3,level:2,school:0}],racialType:0,fieldDE4:30,fieldDE6:70}},playerState:{combat:{canLevelUp:true},abilities:{base:[14,14,14,14,14,14]},feats:[0,1],spellbooks:{0:{known:[2]}},levelUp:{fieldDC6:0,skills:[1,2],fieldE34:-1,fieldE48:'Name',fieldE30:-1,fieldE38:'Other',fieldD4:0,fieldC0:0}}};
const rows=[];
function row(name,change=()=>{}){const value=structuredClone(actor);change(value);try{rows.push({name,actor:value,ready:true,snapshot:networkLevelUpSnapshot(value)});}catch{rows.push({name,actor:value,ready:false});}}
row('complete');row('omitted optional stats',a=>{delete a.replicated.stats.racialType;delete a.replicated.stats.fieldDE4;delete a.replicated.stats.fieldDE6;});
row('explicit null optional stats',a=>Object.assign(a.replicated.stats,{racialType:null,fieldDE4:null,fieldDE6:null}));
row('missing feats and books',a=>{delete a.playerState.feats;delete a.playerState.spellbooks;});row('null feats and books',a=>Object.assign(a.playerState,{feats:null,spellbooks:null}));
row('received cache base wins',a=>a.clientAbilityCache={base:[16,12,12,12,12,12]});row('null cache base falls through',a=>a.clientAbilityCache={base:null});
row('missing nested optional class data',a=>delete a.replicated.stats.classes[0].school);row('explicit null nested class data',a=>a.replicated.stats.classes[0].school=null);
row('future levelUp null key remains',a=>a.playerState.levelUp.futureKey=null);row('unavailable levelUp',a=>a.playerState.combat.canLevelUp=false);row('missing base array',a=>delete a.playerState.abilities);
const fixture=JSON.stringify({rows},null,2)+'\n',copiedProject=path.join(copy,'godot-client'),fixturePath=path.join(directory,'snapshot-function-inputs.json');fs.writeFileSync(fixturePath,fixture);
fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Late Level Up Context"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const godot=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(godot));if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected Godot runtime');
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log');const child=spawnSync(godot,['--headless','--path',copiedProject,'--log-file',log,'--script','res://tests/native_level_up_received_context_test.gd','--','--report='+report,'--fixture='+fixturePath],{windowsHide:true,timeout:20000,encoding:'utf8'});
fs.writeFileSync(path.join(directory,'stdout.log'),child.stdout??'');fs.writeFileSync(path.join(directory,'stderr.log'),child.stderr??'');
const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,engine=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
const clean=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(engine+'\n'+child.stderr);
const changed=[...inputs].filter(([file,row])=>hash(fs.readFileSync(file))!==row.sha256).map(([,row])=>row.path);
const proof={success:child.status===0&&!child.error&&clean&&result?.success===true&&!changed.length,checks:result?.checks??0,failures:result?.failures??[],directory,cleanEngine:clean,exitCode:child.status,error:child.error?.message??null,inputs:[...inputs.values()],changedInputs:changed,engineSha256,fixtureSha256:hash(Buffer.from(fixture)),productionApplied:false,gpu:false,sends:0,serverConnections:0,nativeBuilds:0,scope:result?.scope??'No functional result.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:inputs.size,failures:proof.failures.length}));process.exitCode=proof.success?0:1;
