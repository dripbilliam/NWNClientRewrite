import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
// Fixed accepted run. Explicit manifests/whitelist only; no traversal or launch.
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project);
const run='native-script-floating-actor-names-v1',baseRelative='.cache/ordinary-speech-native-headers-acceptance/delta-v1';
const base=path.join(project,baseRelative),directory=path.join(project,'.cache/ordinary-speech-actor-names-acceptance/delta-v1');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),read=p=>fs.readFileSync(p),json=p=>JSON.parse(read(p));
const inside=(root,name)=>{const full=path.resolve(root,name);if(!full.startsWith(root+path.sep))throw Error('Path leaves bounded root');return full;};
const manifestBytes=read(path.join(base,'input-manifest.json')),baseSealBytes=read(path.join(base,'seal.json'));
if(hash(manifestBytes)!=='35198b1e965ee6619db14beb68776f15ae094e89bb888f543eeba6e5360b94eb'||hash(baseSealBytes)!=='7ed70446ce41f4a349308893a0434278060f42b0d5558a424242c843aa751563')throw Error('Immutable header base changed');
const manifest=JSON.parse(manifestBytes),baseSeal=JSON.parse(baseSealBytes),legacy=inside(project,manifest.base.path);
const legacyManifestBytes=read(path.join(legacy,'input-manifest.json')),legacySealBytes=read(path.join(legacy,'seal.json'));
if(hash(legacyManifestBytes)!==manifest.base.inputManifestSha256||hash(legacySealBytes)!==manifest.base.sealSha256)throw Error('Immutable original base changed');
const legacyManifest=JSON.parse(legacyManifestBytes),legacySeal=JSON.parse(legacySealBytes);
if(baseSeal.inputManifestSha256!==hash(manifestBytes)||legacySeal.inputManifestSha256!==hash(legacyManifestBytes))throw Error('Prior seal manifest mismatch');
for(const row of legacyManifest.pins)if(hash(read(inside(legacy,'inputs/'+row.path)))!==row.sha256)throw Error('Original base input differs: '+row.path);
for(const row of legacySeal.evidence)if(hash(read(inside(legacy,'evidence/'+row.path)))!==row.sha256)throw Error('Original base evidence differs');
const resolveBase=row=>{
 if(row.origin==='delta')return inside(base,'inputs/'+row.path);
 if(row.origin==='base')return inside(legacy,'inputs/'+row.basePath);
 throw Error('Unknown prior reference kind');
};
const byPath=new Map(),byHash=new Map();
for(const row of manifest.pins){if(hash(read(resolveBase(row)))!==row.sha256)throw Error('Header base input differs: '+row.path);byPath.set(row.path,row);if(!byHash.has(row.sha256))byHash.set(row.sha256,row);}
for(const row of baseSeal.evidence)if(hash(read(inside(base,'evidence/'+row.path)))!==row.sha256)throw Error('Header base evidence differs');
const reportRelative='reports/'+run+'.json',nativeRelative='reports/'+run+'.native.json',runnerRelative='.cache/script-floating-authority/'+run+'/runner.json';
const report=json(path.join(project,reportRelative)),runner=json(path.join(project,runnerRelative)),ordinary=report.scriptFloatingProof?.ordinarySpeechProof,script=report.scriptFloatingProof,all=value=>Object.values(value).every(v=>v===true);
if(!report.success||report.nativeExit!==0||!report.sourceUnchanged||report.unpinnedProtocolModules.length||!report.headless||report.publicConnections!==0||
 !ordinary?.success||ordinary.native?.checks!==15||ordinary.native.failures.length||Object.keys(ordinary.checks).length!==9||!all(ordinary.checks)||
 !script.success||script.native?.checks!==16||Object.keys(script.checks).length!==10||!all(script.checks)||
 !report.scriptFloatingNativeExit.success||Object.keys(report.scriptFloatingNativeExit.checks).length!==9||!all(report.scriptFloatingNativeExit.checks)||
 !runner.success||runner.failure||!runner.serverCleaned||runner.privateKeysLogged||runner.nativeBuilds!==0||runner.publicConnections!==0||
 ![...runner.nativeOutputs,...runner.encryptedProfiles,...runner.protectedProcesses].every(row=>row.unchanged===true))throw Error('Accepted gates or preservation changed');
if(fs.existsSync(directory))throw Error('Existing snapshot retained');
const allowed=new Set([
 'godot-client/tools/native-session-host.cjs','godot-client/systems/native_gameplay_ui.gd','godot-client/systems/native_chat_hud.gd','godot-client/systems/server_chat.gd',
 'godot-client/tools/native-text-event-scope.cjs','godot-client/tests/native_live_ordinary_speech_probe.gd','src/network_world.js',
 'godot-client/systems/native_data/actor_name_state.gd','godot-client/systems/native_data/ordinary_speech_header_receipt.gd','godot-client/systems/native_data/talk_text.gd',
 'src/network_actor_name_state.js','godot-client/.cache/script-floating-authority/'+run+'/server/fixture.json'
]);
const safeSource=relative=>{const full=inside(project,relative),name=path.relative(workspace,full).replaceAll('\\','/');if(!full.startsWith(workspace+path.sep)||name.split('/').includes('..')||/(?:\.dpapi$|(?:^|\/)(?:cryptographic_secret|ticket\.json)$)/i.test(name))throw Error('Excluded input');return{full,name};};
// ../src is allowed only after resolution stays in the explicit workspace.
const sourcePath=relative=>{const full=path.resolve(project,relative),name=path.relative(workspace,full).replaceAll('\\','/');if(!full.startsWith(workspace+path.sep)||name.split('/').includes('..')||/(?:\.dpapi$|(?:^|\/)(?:cryptographic_secret|ticket\.json)$)/i.test(name))throw Error('Excluded input');return{full,name};};
const pins=[],changed=[];
for(const[relative,sha256]of Object.entries(report.sourceSha256)){
 const {full,name}=sourcePath(relative),same=byPath.get(name),prior=same?.sha256===sha256?same:byHash.get(sha256);
 if(prior){if(hash(read(resolveBase(prior)))!==sha256)throw Error('Prior ref differs');pins.push({path:name,sha256,origin:'base',basePath:prior.path});}
 else{if(!allowed.has(name)||!/\.(?:gd|js|cjs|json)$/.test(name))throw Error('Unreviewed/nontext delta: '+name);const bytes=read(full);if(hash(bytes)!==sha256)throw Error('Accepted current source drift: '+name);changed.push({path:name,sha256,bytes});pins.push({path:name,sha256,origin:'delta'});}
}
if(changed.length!==12)throw Error('Unexpected changed-text count; retain planned evidence');
fs.mkdirSync(directory,{recursive:true});
const copy=(category,name,bytes,sha256)=>{const destination=inside(directory,category+'/'+name);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,bytes,{flag:'wx'});if(hash(read(destination))!==sha256)throw Error('Copy readback differs');};
for(const row of changed)copy('inputs',row.path,row.bytes,row.sha256);
const evidence=[];
for(const relative of [reportRelative,nativeRelative,'reports/'+run+'.native.shutdown.json','reports/'+run+'.engine.log',runnerRelative,'.cache/script-floating-authority/'+run+'/ready-0.json','tools/stage-native-ordinary-speech-actor-names.mjs']){
 const {full,name}=sourcePath(relative),bytes=read(full),sha256=hash(bytes);copy('evidence',name,bytes,sha256);evidence.push({path:name,sha256,bytes:bytes.length});
}
const referenceNames=['reports/native-ordinary-speech-actor-names-acceptance-v1.json','NATIVE-ORDINARY-SPEECH-ACTOR-NAMES-ACCEPTANCE.md','reports/native-actor-name-live-diagnostics-v1.json','reports/native-actor-name-gameplay-v1.json'];
const evidenceReferences=referenceNames.map(relative=>{const {full,name}=sourcePath(relative),bytes=read(full);return{path:name,sha256:hash(bytes),bytes:bytes.length,origin:'immutable-current-reference'};});
const inputManifest={version:1,run,scope:'Exact accepted1664 source pins;12 whitelisted changed text copies and verified recursive immutable base references only.',
 base:{path:baseRelative,inputManifestSha256:hash(manifestBytes),sealSha256:hash(baseSealBytes),verifiedRecursiveBase:manifest.base},
 pins,baseReferences:pins.filter(row=>row.origin==='base').length,deltaFiles:changed.map(({bytes,...row})=>row),readbackVerified:true,noBinaryCopies:true};
const outBytes=Buffer.from(JSON.stringify(inputManifest,null,2)+'\n');fs.writeFileSync(path.join(directory,'input-manifest.json'),outBytes,{flag:'wx'});
const seal={version:1,success:true,run,inputManifestSha256:hash(outBytes),base:inputManifest.base,inputFiles:pins.length,baseReferences:inputManifest.baseReferences,deltaFiles:changed.length,evidence,evidenceReferences,readbackVerified:true,noBinaryCopies:true,archiveCreated:false,serverLaunches:0,engineLaunches:0,profileCredentialCopies:0};
const sealBytes=Buffer.from(JSON.stringify(seal,null,2)+'\n');fs.writeFileSync(path.join(directory,'seal.json'),sealBytes,{flag:'wx'});
if(hash(read(path.join(directory,'input-manifest.json')))!==hash(outBytes)||hash(read(path.join(directory,'seal.json')))!==hash(sealBytes))throw Error('Final readback differs');
for(const row of pins){const full=row.origin==='delta'?inside(directory,'inputs/'+row.path):resolveBase(byPath.get(row.basePath));if(hash(read(full))!==row.sha256)throw Error('Final input verification failed');}
for(const row of evidence)if(hash(read(inside(directory,'evidence/'+row.path)))!==row.sha256)throw Error('Final evidence verification failed');
for(const row of evidenceReferences)if(hash(read(inside(workspace,row.path)))!==row.sha256)throw Error('Final immutable evidence reference drift');
console.log(JSON.stringify({success:true,directory,pinnedInputs:pins.length,baseReferences:inputManifest.baseReferences,deltaFiles:changed.map(row=>row.path),evidence:evidence.length,evidenceReferences:evidenceReferences.length,inputManifestSha256:hash(outBytes),sealSha256:hash(sealBytes),archiveCreated:false,noBinaryCopies:true}));

