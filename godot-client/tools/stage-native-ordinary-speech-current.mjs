import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

// Fixed accepted run only: exact report inventory, never a workspace traversal.
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const workspace=path.dirname(project),run='native-script-floating-ordinary-current-v1';
const directory=path.join(project,'.cache/ordinary-speech-current-acceptance/sealed-v1');
const reportPath='reports/'+run+'.json',runnerPath='.cache/script-floating-authority/'+run+'/runner.json';
const digest=b=>crypto.createHash('sha256').update(b).digest('hex');
const read=p=>JSON.parse(fs.readFileSync(path.join(project,p),'utf8'));
const report=read(reportPath),runner=read(runnerPath),ordinary=report.scriptFloatingProof.ordinarySpeechProof;
const native=ordinary.native,allTrue=o=>Object.values(o).every(v=>v===true);
if(!report.success||report.nativeExit!==0||!report.sourceUnchanged||report.publicConnections!==0||report.unpinnedProtocolModules.length||
 !report.headless||!runner.success||runner.failure||!runner.serverCleaned||runner.endpoint!=='127.0.0.1:5129'||runner.privateKeysLogged||runner.publicConnections!==0||runner.nativeBuilds!==0||
 ![...runner.nativeOutputs,...runner.encryptedProfiles,...runner.protectedProcesses].every(v=>v.unchanged===true)||
 !report.scriptFloatingProof.success||!allTrue(report.scriptFloatingProof.checks)||Object.keys(report.scriptFloatingProof.checks).length!==10||
 report.scriptFloatingProof.native.checks!==16||!report.scriptFloatingProof.native.success||!report.scriptFloatingNativeExit.success||Object.keys(report.scriptFloatingNativeExit.checks).length!==9||!allTrue(report.scriptFloatingNativeExit.checks)||
 !ordinary.success||Object.keys(ordinary.checks).length!==9||!allTrue(ordinary.checks)||!native.success||native.checks!==15||native.failures.length||
 !Object.values(native.freshPopupPreferences).every(v=>v.mode===2&&v.largeFont===true)||
 ![native.first,native.replacement].every(v=>v.mode===2&&v.font==='ttf fnt_default_hr 16'&&allTrue(v.clock))||
 native.first.viewInstance!==native.replacement.viewInstance||native.first.registryOrdinal!==native.replacement.registryOrdinal||native.expiry.length!==1)
 throw Error('Exact authoritative acceptance/preservation predicate rejected; do not relabel');
if(fs.existsSync(directory))throw Error('Existing snapshot preserved');
const inputs=new Map(),evidence=new Map();
function prepare(relative,expected,kind){
 const source=path.resolve(project,relative),name=path.relative(workspace,source).replaceAll('\\','/');
 if(!source.startsWith(workspace+path.sep)||name.split('/').includes('..')||/(?:\.dpapi$|(?:^|\/)(?:cryptographic_secret|ticket\.json)$)/i.test(name))throw Error('Excluded evidence path: '+name);
 const bytes=fs.readFileSync(source),sha256=digest(bytes);if(expected&&sha256!==expected)throw Error('Accepted input drift: '+name);
 const row={path:name,sha256,bytes:bytes.length};(kind==='input'?inputs:evidence).set(name,{row,bytes});return row;
}
for(const [relative,sha]of Object.entries(report.sourceSha256))prepare(relative,sha,'input');
const proposal=read('reports/native-ordinary-speech-current-live-proposal-v2.json');
for(const row of proposal.changes){const name='godot-client/'+row.path;if(!inputs.has(name))prepare(row.path,row.sha256,'input');}
for(const p of [reportPath,'reports/'+run+'.native.json','reports/'+run+'.native.shutdown.json','reports/'+run+'.engine.log','reports/'+run+'.lobby.cfg',runnerPath,
 '.cache/script-floating-authority/'+run+'/ready-0.json','.cache/script-floating-authority/'+run+'/server/fixture.json',
 '.cache/ordinary-speech/capture-current-v2/proof.json','.cache/ordinary-speech/powershell-preflight-current-v2.json','.cache/ordinary-speech/current-preflight-v2-guards-after.json',
 '.cache/ordinary-speech/native-ordinary-speech-current-boundary-v1/proof.json','reports/native-ordinary-speech-current-live-proposal-v2.json',
 '.cache/ordinary-speech-current-before-v1/manifest.json','tools/stage-native-ordinary-speech-current.mjs'])prepare(p,null,'evidence');
for(const p of ['modules/ScriptFloat1.mod','client/nwm/ScriptFloat1.nwm'])prepare('.cache/script-floating-authority/'+run+'/server/'+p,report.scriptFloatingServerFixture.moduleSha256,'evidence');
fs.mkdirSync(directory,{recursive:true});
function save(category,entry){const out=path.join(directory,category,entry.row.path);fs.mkdirSync(path.dirname(out),{recursive:true});fs.writeFileSync(out,entry.bytes,{flag:'wx'});if(digest(fs.readFileSync(out))!==entry.row.sha256)throw Error('Readback differs: '+entry.row.path);}
for(const v of inputs.values())save('inputs',v);for(const v of evidence.values())save('evidence',v);
const inputManifest={version:1,run,source:'Terminal report sourceSha256 plus exact approved dedicated harness supplement',authoritativeInputs:Object.keys(report.sourceSha256).length,pins:[...inputs.values()].map(v=>v.row),sourceExact:true};
const inputBytes=Buffer.from(JSON.stringify(inputManifest,null,2)+'\n');fs.writeFileSync(path.join(directory,'input-manifest.json'),inputBytes,{flag:'wx'});
const acceptance={schema:'native-ordinary-speech-current-acceptance-v1',success:true,run,method:'Exactly one authorized headless original-local-server run; no retry',
 command:'pwsh -NoProfile -File godot-client/tools/test-native-ordinary-speech-live.ps1 -Run '+run,
 acceptance:{ordinaryNative:15,ordinaryCapture:9,inheritedScriptNative:16,inheritedScriptCapture:10,inheritedScriptExit:9,nativeExit:0},
 runtime:{endpoint:runner.endpoint,headless:report.headless,engine:report.engineRuntime,module:report.scriptFloatingServerFixture.module,moduleSha256:report.scriptFloatingServerFixture.moduleSha256,serverSha256:report.scriptFloatingServerFixture.serverSha256,publicConnections:0,nativeBuilds:0},
 ordinary:{freshPopupPreferences:native.freshPopupPreferences,source:native.source,scope:native.scope,font:native.first.font,mode:native.first.mode,oneSharedClock:{first:native.first.clock,replacement:native.replacement.clock},sameView:true,sameRegistryOrdinal:true,first:native.first,replacement:native.replacement,preReplacementRemaining:native.preReplacementRemaining,expiry:native.expiry,anchorBindings:native.anchorBindings,visual:native.visual},
 preservation:{sourceUnchanged:true,unpinnedProtocolModules:[],serverCleaned:runner.serverCleaned,outputs:runner.nativeOutputs,encryptedProfilesUnchanged:runner.encryptedProfiles.every(v=>v.unchanged),protectedProcesses:runner.protectedProcesses,privateKeysLogged:false,credentialsCopied:false,userProfileFilesCopied:false},
 separatePriorScopes:{pureCapture:{checks:33,path:'.cache/ordinary-speech/capture-current-v2/proof.json'},powershellPreflight:{checks:6,path:'.cache/ordinary-speech/powershell-preflight-current-v2.json'},copiedBoundary:{checks:8,pins:688,path:'.cache/ordinary-speech/native-ordinary-speech-current-boundary-v1/proof.json'}},
 snapshot:{directory:path.relative(project,directory).replaceAll('\\','/'),inputManifest:'input-manifest.json',inputManifestSha256:digest(inputBytes),authoritativeInputs:inputManifest.authoritativeInputs,totalInputs:inputs.size,evidence:[...evidence.values()].map(v=>v.row),readbackVerified:true,archiveCreated:false},
 limits:['Headless model/head-anchor/projection, Canvas visibility, font/layout and native timer evidence; no rendered pixels or GPU/performance claim.',
 'No authored hover caption in this run; cachedOwnerCaptionPresent=false at expiry. Remote relation-decorated hover restoration is not established.',
 'Only the installed controlled creature and ordinary Talk replacement/expiry route were exercised; not every channel, portrait, mode/font hot-change, camera or lifetime transition.',
 'Inherited ScriptFloating16/10/9 remains a distinct scope; this report does not promote prior layout evidence into pixel or full visual parity.',
 'Historical proposal remains pre-authorization evidence; this new receipt records the later explicit grant and actual accepted execution.']};
const acceptanceRelative='reports/native-ordinary-speech-current-acceptance-v1.json';const acceptanceBytes=Buffer.from(JSON.stringify(acceptance,null,2)+'\n');fs.writeFileSync(path.join(project,acceptanceRelative),acceptanceBytes,{flag:'wx'});
const addendum=`# Current ordinary-speech authority acceptance\n\nThe single authorized \`${run}\` run passed against the owned original server at 127.0.0.1:5129. [Acceptance receipt](reports/native-ordinary-speech-current-acceptance-v1.json) records ordinary native **15**, packet/capture **9**, and the distinct inherited ScriptFloating **16 / 10 / 9** gates. The native process exited 0.\n\nFresh run-specific preferences produced native mode **2**, large font **true**, and applied \`ttf fnt_default_hr 16\`. Both actual Talk messages used one canonical Registry clock, the same Bubble instance and construction ordinal. The second message replaced the first and reset its native duration to four seconds. Actual installed creature models, head anchor, projected position, visible Canvas controls and font/layout were observed; natural expiry released the view/claim without input. No hover caption was authored; the expiry record reports no cached owner caption.\n\nThe wrapper preserved the original server/editor and all other protected process identities, both encrypted profiles and six shared native outputs. Its owned server was cleaned, the ALT lease was released, public connections and builds were zero, and no key payloads were logged or copied.\n\nA verified directory snapshot at \`${acceptance.snapshot.directory}\` contains only the terminal report's **${inputManifest.authoritativeInputs}** pinned inputs, **${inputs.size-inputManifest.authoritativeInputs}** approved dedicated harness supplements and an explicit bounded evidence list. Every copied file was hashed on input and readback. \`input-manifest.json\` SHA-256: \`${digest(inputBytes)}\`. The snapshot excludes credential files, user profiles, server secrets/databases and installed engine/server binaries. It is not a compressed archive.\n\nThe earlier pure capture33, PowerShell6 and copied SessionWorld boundary8/688 are retained as separate preflight scopes. Historical rejected runs and proposals are unchanged. This headless acceptance establishes no GPU, pixel, performance, remote relation-caption restoration or all-channel visual parity. Root owns the combined checkpoint and broader migration status.\n`;
const docRelative='NATIVE-ORDINARY-SPEECH-CURRENT-ACCEPTANCE.md';fs.writeFileSync(path.join(project,docRelative),addendum,{flag:'wx'});
for(const p of [acceptanceRelative,docRelative]){const row=prepare(p,null,'evidence');save('evidence',evidence.get(row.path));}
const sealed={version:1,success:true,run,inputManifestSha256:digest(inputBytes),inputFiles:inputs.size,evidence:[...evidence.values()].map(v=>v.row),files:inputs.size+evidence.size+1,readbackVerified:true,archiveCreated:false};
const sealBytes=Buffer.from(JSON.stringify(sealed,null,2)+'\n');fs.writeFileSync(path.join(directory,'seal.json'),sealBytes,{flag:'wx'});
if(digest(fs.readFileSync(path.join(directory,'input-manifest.json')))!==digest(inputBytes)||digest(fs.readFileSync(path.join(directory,'seal.json')))!==digest(sealBytes))throw Error('Manifest readback differs');
console.log(JSON.stringify({success:true,directory,inputs:inputs.size,authoritativeInputs:inputManifest.authoritativeInputs,evidence:evidence.size,files:sealed.files,inputManifestSha256:digest(inputBytes),sealSha256:digest(sealBytes),acceptanceSha256:digest(acceptanceBytes),docSha256:digest(Buffer.from(addendum))}));
