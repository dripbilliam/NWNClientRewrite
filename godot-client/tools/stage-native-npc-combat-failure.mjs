import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project),run='native-npc-combat-local-v1',directory=path.join(project,'.cache/npc-combat-evidence',run);
const read=suffix=>JSON.parse(fs.readFileSync(path.join(project,'reports',run+suffix))),report=read('.json'),native=read('.native.json'),isolation=read('.isolation.json');
if(report.success||native.protocol_finish_ack||report.actions?.checks?.length||!report.sourceUnchanged||report.unpinnedProtocolModules?.length||!isolation.nativeOutputsUnchanged||!isolation.encryptedProfilesUnchanged||!isolation.protectedProcessesPreserved||isolation.ownedServerProcesses!==0||!isolation.port5125Closed)throw Error('Unexpected failed-run classification/cleanup; do not relabel');
if(fs.existsSync(directory))throw Error('Existing evidence preserved');fs.mkdirSync(directory,{recursive:true});
const digest=b=>crypto.createHash('sha256').update(b).digest('hex'),pins=[],missing=[];
function copy(relative,expected){
 const source=path.resolve(project,relative),name=path.relative(workspace,source).replaceAll('\\','/');if(!source.startsWith(workspace+path.sep)||name.split('/').includes('..')||/\.dpapi$|(?:^|\/)ticket\.json$/i.test(name))throw Error('Evidence is not owned source/module data');
 const candidates=[source,path.join(project,'.cache/npc-combat-source/native-npc-combat-source-v3/inputs',name)];const exact=candidates.find(file=>fs.existsSync(file)&&(!expected||digest(fs.readFileSync(file))===expected));
 if(!exact){missing.push({path:name,sha256:expected});return;}
 const bytes=fs.readFileSync(exact),sha256=digest(bytes),destination=path.join(directory,'source',name);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,bytes,{flag:'wx'});if(digest(fs.readFileSync(destination))!==sha256)throw Error('Failed-run copy changed');pins.push({path:name,sha256});
}
for(const [relative,sha256]of Object.entries(report.sourceSha256))copy(relative,sha256);
for(const relative of ['join-native.ps1','tools/test-native-actions.ps1','tools/stage-native-npc-combat-failure.mjs'])if(!pins.some(row=>row.path==='godot-client/'+relative))copy(relative);
const fixtureRoot=path.resolve(report.npcCombatFixtureDirectory);if(fixtureRoot!==path.join(workspace,'runtime-logs/native-playability-actions-server')||report.actionFixture.module!=='GodotCombatNpc1')throw Error('Unexpected owned fixture');
for(const relative of ['modules/GodotCombatNpc1.mod','client/nwm/GodotCombatNpc1.nwm'])copy(path.relative(project,path.join(fixtureRoot,relative)),report.actionFixture.sha256);
for(const suffix of ['.json','.native.json','.isolation.json','.native.shutdown.json','.engine.log','.cdb.log'])fs.copyFileSync(path.join(project,'reports',run+suffix),path.join(directory,run+suffix));
const snapshot={success:missing.length===0,sourceExact:missing.length===0,pins,missing,runAccepted:false,nativeChecks:0,reason:native.failure,disconnect:native.protocol_disconnect,serverOutcomeAccepted:false,pixels:false,fullCombat:false,scope:'Failed original NPC encounter before probe; exact source/module and failure/cleanup evidence, never gameplay acceptance.'};fs.writeFileSync(path.join(directory,'snapshot.json'),JSON.stringify(snapshot,null,2)+'\n');console.log(JSON.stringify({...snapshot,pins:pins.length}));process.exitCode=snapshot.success?0:1;
