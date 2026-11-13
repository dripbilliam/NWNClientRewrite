import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.resolve(project,'..');
const run='native-combat-presentation-local-v2',directory=path.join(project,'.cache/combat-local-evidence',run);
const read=name=>JSON.parse(fs.readFileSync(path.join(project,'reports',name),'utf8'));
const report=read(run+'.json'),native=read(run+'.native.json'),isolation=read(run+'.isolation.json');
if(!report.success||report.failure||report.actions?.checks.length!==38||report.actions?.failures.length||!report.combatPresentationServerProof?.success||!report.combatPresentationLifecycle?.success||!report.sourceUnchanged||report.unpinnedProtocolModules?.length||report.nativeExit!==0||report.nativeException||!report.debuggerArmed||report.engineErrors||!native.protocol_finish_ack||!native.clean_exit||native.workers_remaining!==0||!isolation.nativeOutputsUnchanged||!isolation.protectedProcessesPreserved||isolation.ownedServerProcesses!==0||!isolation.port5125Closed)throw Error('Strict authoritative receipt is not accepted');
if(fs.existsSync(directory))throw Error('Existing evidence preserved');
fs.mkdirSync(directory,{recursive:true});
const digest=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),pins=[];
function copy(relative,expected){
 const source=path.resolve(project,relative),name=relative.startsWith('../')?relative.slice(3):'godot-client/'+relative;
 if(!source.startsWith(workspace+path.sep)||name.split('/').includes('..'))throw Error('Evidence path leaves workspace');
 const bytes=fs.readFileSync(source),sha256=digest(bytes);
 if(expected&&sha256!==expected)throw Error('Accepted input changed: '+relative);
 const destination=path.join(directory,'source',name);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,bytes,{flag:'wx'});
 if(digest(fs.readFileSync(destination))!==sha256)throw Error('Evidence copy differs');
 pins.push({path:name,sha256});
}
for(const [relative,sha256]of Object.entries(report.sourceSha256))copy(relative,sha256);
for(const relative of ['tools/test-native-actions.ps1','../test/native-combat-check-lifecycle.test.js','reports/native-combat-check-lifecycle-v1.tap','tools/stage-native-combat-locomotion.mjs'])if(!pins.some(row=>row.path==='godot-client/'+relative))copy(relative);
for(const suffix of ['.json','.native.json','.isolation.json'])fs.copyFileSync(path.join(project,'reports',run+suffix),path.join(directory,run+suffix));
fs.writeFileSync(path.join(directory,'snapshot.json'),JSON.stringify({success:true,sourceExact:true,pins,localChecks:38,lifecycleChecks:12,fullCombat:false,pixels:false,gameplayFps:false},null,2)+'\n');
process.stdout.write(JSON.stringify({success:true,directory,files:pins.length,localChecks:38,lifecycleChecks:12,fullCombat:false})+'\n');
