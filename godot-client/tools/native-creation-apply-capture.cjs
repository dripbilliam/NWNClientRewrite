'use strict';
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const {validateCapture}=require('./native-world-radial-capture.cjs');
const digest=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function validateCreationCapture(ledger,setupBytes,rawBytes,original){
 const captured=original?.creationApplyDiagnostic;
 if(original?.endpoint!=='127.0.0.1:5129'||original.creationVaultFixture?.kind!=='owned-native-first-level-vault'||original.creationVaultFixture?.module!=='Prelude'||original.creationVaultFixture?.public!==false||original.creationVaultFixture?.serverVault!==true||!original.creationProof?.success)throw Error('Capture lacks the owned local source-creation provenance');
 if(!ledger?.setup||!ledger.snapshot||!captured?.setup||!captured.snapshot||captured.setup.sha256!==ledger.setup.sha256||captured.snapshot.sha256!==ledger.snapshot.sha256)throw Error('Capture is not retained in the final owned diagnostic report');
 if(setupBytes.length>65536||rawBytes.length>8*1024*1024||setupBytes.length!==ledger.setup.bytes||rawBytes.length!==ledger.snapshot.bytes||digest(setupBytes)!==ledger.setup.sha256||digest(rawBytes)!==ledger.snapshot.sha256)throw Error('Exact bounded capture bytes changed');
 const setupFrame=setupBytes.toString('utf8'),text=rawBytes.toString('utf8');if(!text.endsWith('\n'))throw Error('Exact capture lacks its final frame terminator');
 const rawFrames=text.slice(0,-1).split('\n').map(row=>row+'\n');
 const value={version:1,setupFrame,rawFrames,setupSha256:digest(setupBytes),framesSha256:digest(rawBytes)};
 const identity=validateCapture(value);
 for(const key of ['connection','serial','generation','objects'])if(identity[key]!==ledger.snapshot[key])throw Error('Captured snapshot identity differs');
 if(JSON.stringify(identity.setup.resourceSources)!==JSON.stringify(original.creationResourceSources))throw Error('Captured active resource descriptor differs');
 return {value,identity};
}
async function readCreationCapture(file){
 const project=path.resolve(__dirname,'..'),reports=path.join(project,'reports')+path.sep;
 file=path.resolve(file);if(!file.startsWith(reports)||!/^native-creation-[a-z0-9-]+\.apply\.phases\.json$/.test(path.basename(file)))throw Error('Explicit owned creation diagnostic ledger required');
 const prefix=file.slice(0,-'.phases.json'.length),reportFile=file.replace(/\.apply\.phases\.json$/,'.json');
 const [ledgerBytes,reportBytes]=await Promise.all([fs.readFile(file),fs.readFile(reportFile)]);
 if(ledgerBytes.length>512*1024||reportBytes.length>8*1024*1024)throw Error('Owned diagnostic metadata exceeds bound');
 const ledger=JSON.parse(ledgerBytes),original=JSON.parse(reportBytes);
 if(ledger.setup?.file!==prefix+'.setup.jsonl'||ledger.snapshot?.file!==prefix+'.raw.jsonl')throw Error('Captured filenames differ from the owned ledger');
 const [setupBytes,rawBytes]=await Promise.all([fs.readFile(ledger.setup.file),fs.readFile(ledger.snapshot.file)]);
 const opened=validateCreationCapture(ledger,setupBytes,rawBytes,original);
 return {...opened,ledger,original,sha256:digest(rawBytes),ledgerSha256:digest(ledgerBytes),reportSha256:digest(reportBytes)};
}
module.exports={validateCreationCapture,readCreationCapture};
