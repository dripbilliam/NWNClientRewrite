import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function stage(input,output,transform){const file=path.join(root,input),destination=path.join(root,output);if(fs.existsSync(destination))throw Error('Existing derivative retained: '+destination);const source=fs.readFileSync(file);let code=source.toString();const replace=(a,b)=>{if(code.split(a).length!==2)throw Error('Source seam differs: '+a.slice(0,90));code=code.replace(a,b);};transform(replace);fs.writeFileSync(destination,code,{flag:'wx'});return {source:{file,sha256:sha(source)},output:{file:destination,sha256:sha(code)}};}
const watcher=stage('watch-module-v3.ps1','watch-module-v4.ps1',replace=>{
 replace('version=1;success=$true;run=$Run;processId=$particleClient.Id;createdFileTimeUtc=$particleCreated;','version=4;success=$true;run=$Run;processId=$particleClient.Id;createdFileTimeUtc=$particleCreated;createdFileTimeUtcExact=$particleCreated.ToString([Globalization.CultureInfo]::InvariantCulture);');
});
const runner=stage('run-replay.cjs','run-core-survey-a.cjs',replace=>{
 replace(" if(selection.renderGap.trainingOnly===true)throw Error('Instrumented PGO training cannot enter the FPS runner');"," if(selection.renderGap.trainingOnly===true)throw Error('Instrumented PGO training cannot enter the CPU placement diagnostic');\n if(!selection.renderGap.extraFlags.includes('--particle-core-survey')||!selection.renderGap.extraFlags.includes('--frame-pacing-metrics=on'))throw Error('Explicit CPU survey plus independent main-thread pacing proof required');");
 replace("const watcher=path.join(__dirname,'watch-module-v3.ps1');","const watcher=path.join(__dirname,'watch-module-v4.ps1');");
 replace(" await adapter.readSelection(proof.selection.file,proof.selection.sha256);\n const result=",` await adapter.readSelection(proof.selection.file,proof.selection.sha256);
 const core=report.native?.render_gap?.core_survey;
 const coreLifetimeProof={success:core?.process_id===moduleProof?.processId&&typeof core?.process_creation_100ns_exact==='string'&&/^[1-9][0-9]*$/.test(core.process_creation_100ns_exact)&&core.process_creation_100ns_exact===moduleProof?.createdFileTimeUtcExact,processId:core?.process_id??null,surveyCreationExact:core?.process_creation_100ns_exact??null,watcherCreationExact:moduleProof?.createdFileTimeUtcExact??null,scope:'Exact Windows PID and decimal FILETIME equality; numeric JSON FILETIME values are not used for identity.'};
 const result=`);
 replace('const result={success:processes.every(p=>p.exit===0)&&audit.success','const result={performanceAccepted:false,diagnosticOnly:true,coreLifetimeProof,success:coreLifetimeProof.success&&report.renderGapVerification?.features?.coreSurvey===true&&processes.every(p=>p.exit===0)&&audit.success');
 replace("scope:proof.profile?'Diagnostic attribution only; not profile-off FPS acceptance':'Profile-off matched replay; bounded visual inspection/repeated-pair acceptance remain separate'","scope:'CPU placement frame-entry snapshot diagnostic only. All replay timings are excluded from FPS acceptance. Actual main-thread/FILETIME/topology gates and the exact owned process/module remain required.'");
});
console.log(JSON.stringify({watcher,runner,scope:'Source-only private diagnostic derivatives; original V3 watcher and generic replay runner unchanged.'}));
