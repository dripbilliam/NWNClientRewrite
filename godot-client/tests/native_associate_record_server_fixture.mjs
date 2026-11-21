// Copy a previously accepted authored local fixture into a new private profile.
// No original installation, live profile, module script or received data edits.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';import {fileURLToPath} from 'node:url';
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
export async function createAssociateRecordFixture(directory){
 const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..'),receiptPath=path.join(root,'godot-client/reports/native-quickbar-local-v10.json'),receiptBytes=await fs.readFile(receiptPath),receipt=JSON.parse(receiptBytes);
 assert.equal(receipt.success,true);assert.equal(receipt.sourceUnchanged,true);assert.equal(receipt.actionFixture.module,'GodotQuick3');
 const source=path.join(root,'runtime-logs/native-playability-actions-server/modules/GodotQuick3.mod'),bytes=await fs.readFile(source);assert.equal(sha(bytes),receipt.actionFixture.sha256,'Accepted authored fixture changed');
 for(const [folder,extension]of [['modules','mod'],['client/nwm','nwm']]){await fs.mkdir(path.join(directory,folder),{recursive:true});await fs.writeFile(path.join(directory,folder,'GodotQuick3.'+extension),bytes,{flag:'wx'});}
 const result={module:'GodotQuick3',port:5127,sha256:sha(bytes),acceptedReceiptSha256:sha(receiptBytes),associateTag:'native_speaker',proficiency:receipt.actionFixture.associateProbe.proficiency,scope:'Exact previously accepted authored GodotQuick3 local module copy; unchanged real NPC, proficiency, script/AddHenchman and inventory. No original packaged assets or client state synthesis.'};
 await fs.writeFile(path.join(directory,'fixture.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});return result;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){const directory=process.argv.find(value=>value.startsWith('--directory='))?.slice(12);assert.ok(directory);console.log(JSON.stringify(await createAssociateRecordFixture(directory)));}
