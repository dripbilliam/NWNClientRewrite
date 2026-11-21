// Current-source acceptance of shared UI construction; not complete UI parity.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const home=fileURLToPath(new URL('../',import.meta.url));
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const evidence=[],runs=[];
async function read(file){const bytes=await fs.readFile(path.join(home,file));evidence.push({file,sha256:hash(bytes)});return JSON.parse(bytes);}
const required=['core-final-v1','settings-final-v1','picker-final-v1','disconnect-final-v1','style-final-v1','pregame-final-v1','ingame-final-v1','multiplayer-final-v1','game-options-final-v1','picker-input-final-v2','inventory-final-v1','barter-final-v1','desktop-v3','store-final-v1','examine-final-v1','journal-final-v1','players-final-v1','spells-final-v1','keys-final-v1','video-final-v1'];
let checks=0;
for(const name of required){
 const stem='reports/native-menu-framework-'+name;
 const result=await read(stem+'.json'),proof=await read(stem+'.debugger.json');
 assert.equal(result.success,true,name);assert.deepEqual(result.failures,[],name);assert.ok(Number.isInteger(result.checks)&&result.checks>0,name);
 for(const key of ['success','sourceUnchanged','armed'])assert.equal(proof[key],true,name+': '+key);
 for(const key of ['exception','engineOrLifetimeError'])assert.equal(proof[key],false,name+': '+key);
 assert.equal(proof.debuggerExit,0,name);assert.equal(proof.publicConnections,0,name);
 for(const [file,digest] of Object.entries(proof.sourceSha256))assert.equal(hash(await fs.readFile(path.join(home,file))),digest,name+': stale '+file);
 checks+=result.checks;runs.push({name,checks:result.checks,graphical:proof.graphical});
}
for(const [file,review] of [
 ['reports/native-menu-framework-style-final-v1.graphics.png','Original-art shared Client Options: fonts, checks, choice and close control.'],
 ['reports/native-menu-framework-pregame-final-v1-main.png','Original main-menu composition and source captions.'],
 ['reports/native-menu-framework-ingame-final-v1-scaled.png','Original in-game menu remains source-sized at125% scale.']
]){
 const bytes=await fs.readFile(path.join(home,file));assert.equal(bytes.subarray(1,4).toString(),'PNG');evidence.push({file,sha256:hash(bytes),review});
}
const archive='backups/native-menu-framework-v1.zip',checkpoint=await read(archive+'.verified.json');
assert.equal(checkpoint.verified,true);assert.equal(hash(await fs.readFile(path.join(home,archive))),checkpoint.sha256);
for(const entry of checkpoint.manifest){
 const file=entry.sourceScope==='workspace'?path.join(home,'..',entry.source):path.join(home,entry.file);
 assert.equal(hash(await fs.readFile(file)),entry.sha256,entry.file+': changed since checkpoint');
}
const result={success:true,checks,runs,publicGameplayConnections:0,fullUiParity:false,goalComplete:false,checkpoint:{file:archive,sha256:checkpoint.sha256,files:checkpoint.files},evidence,scope:'Shared menu definitions/control construction/window theming and original-asset native input. Game actions remain controller-owned; specialized widgets and original layout parsers remain dedicated. These are local authored-state UI checks, not a new connected-server or performance acceptance.'};
await fs.writeFile(path.join(home,'reports/native-menu-framework-audit-v1.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({...result,evidence:undefined,runs:result.runs.length}));
