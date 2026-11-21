'use strict';
// Freeze the shared replay driver into an NWN-74-only diagnostic copy. This
// never changes the shared driver or its accepted runtime-selection policy.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const shared=path.join(root,'tools/replay-native-loading.mjs');
const target=path.join(__dirname,'replay-render-probe.mjs');
assert(!fs.existsSync(target),'Preserve existing diagnostic driver');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const original=fs.readFileSync(shared,'utf8');
let source=original.replaceAll("from './","from '../").replaceAll("require('./","require('../");
function replaceOnce(before,after){assert.equal(source.split(before).length,2,'Shared driver seam changed');source=source.replace(before,after);}
replaceOnce("const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');","const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');");
const sentinel='const knownEnvironmentDiagnostics=process.argv.includes(\'--nwn62-known-environment-diagnostics\');';
const proof=`const nwn74ReceiptFile=path.join(project,'.cache/nwn74/engine-build-b/receipt.json');
const nwn74Receipt=JSON.parse(await fs.readFile(nwn74ReceiptFile,'utf8'));
if(!productionSelection||engineMode!=='production-selection'||profiling!=='true'||nwn74Receipt.success!==true||nwn74Receipt.originalUntouched!==true||nwn74Receipt.binary?.sha256!=='35e47e75fb71dac4ae91140026d1b333988c1546e8033f86a8624702b12da64f'||sha(await fs.readFile(nwn74Receipt.binary.file))!==nwn74Receipt.binary.sha256)throw Error('NWN-74 private render probe proof differs');
if(privateEngineProbe)throw Error('NWN-74 cannot combine private engine probes');
engineFile=nwn74Receipt.binary.file;
`;
replaceOnce(sentinel,proof+sentinel);
replaceOnce('const featureRuntime=privateEngineProbe?{...productionSelection.runtime,executable:engineFile,executableSha256:privateEngineProbeReceipt.candidateSha256}:productionSelection.runtime;','const featureRuntime={...productionSelection.runtime,executable:engineFile,executableSha256:nwn74Receipt.binary.sha256};');
replaceOnce("const featureOptions=privateEngineProbe?{...productionSelection.performanceOptions,renderCore:{...productionSelection.performanceOptions.renderCore,engineSha256:privateEngineProbeReceipt.candidateSha256,policy:'private-nwn62-classdb-diagnostic-unaccepted'}}:productionSelection.performanceOptions;","const featureOptions={...productionSelection.performanceOptions,renderCore:{...productionSelection.performanceOptions.renderCore,engineSha256:nwn74Receipt.binary.sha256,policy:'private-nwn74-render-probe-unaccepted'}};");
replaceOnce('if(productionSelection)report.productionSelection=productionSelection.evidence;','if(productionSelection)report.productionSelection=productionSelection.evidence;\nreport.privateRenderProbe={issue:"NWN-74",accepted:false,receipt:nwn74ReceiptFile,receiptSha256:sha(await fs.readFile(nwn74ReceiptFile)),engineSha256:nwn74Receipt.binary.sha256};');
fs.writeFileSync(target,source,{flag:'wx'});
console.log(JSON.stringify({target,sha256:sha(fs.readFileSync(target)),shared,sharedSha256:sha(fs.readFileSync(shared)),bytes:Buffer.byteLength(source)}));
