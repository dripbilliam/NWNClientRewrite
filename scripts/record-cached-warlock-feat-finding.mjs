// Preserve the actual-data differential as a finding, not a relaxed rule.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const files={};const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
function read(file){const bytes=fs.readFileSync(path.join(root,file));files[file]=sha(bytes);return JSON.parse(bytes);}
const prefix='godot-client/.cache/cached-warlock-complete/cached-warlock-feat-comparison-v2/';
const proof=read(prefix+'runner.json'),result=read(prefix+'result.json');
assert.ok(proof.success&&proof.cleanEngine&&proof.checks===297&&proof.changedInputs.length===0&&proof.changedData.length===0&&proof.changedNative.length===0);
const fixture=read('godot-client/.cache/cached-warlock-creation/cached-arelith-warlock-tail-v5/fixture.json');
read('godot-client/reports/native-package-feat-recommendation-source-v1.json');
const cases=result.observations.featComparison.map(row=>{
 const generic=row.generic.map(choice=>choice.id);assert.deepEqual(generic,row.nativeSelected);
 assert.deepEqual(row.slots,{bonus:1,normal:2});assert.equal(row.nativeRemaining,1);assert.equal(row.nativeCanAccept,false);
 const base=row.candidates.find(choice=>choice.id===2300);assert.equal(base.inPreference,false);assert.ok(base.native.allowed&&base.genericBonus&&!base.genericNormal);
 return {packageId:row.packageId,preference:row.preference,preSkillRanks:row.preSkillRanks,slots:row.slots,generic:row.generic,nativeSelected:row.nativeSelected,remaining:row.nativeRemaining,manualCanAccept:row.nativeCanAccept,basePact:base};
});
assert.deepEqual(cases.map(row=>row.packageId),[149,310,311,312,313,314]);
files['scripts/record-cached-warlock-feat-finding.mjs']=sha(fs.readFileSync(fileURLToPath(import.meta.url)));
const target=path.join(root,'godot-client/reports/native-cached-warlock-automatic-feats-finding-v1.json');assert.ok(!fs.existsSync(target));
const report={manifest:fixture.manifest,scope:'Actual cached Arelith Warlock, physical-control pre-skill draft, private generic/native preference-only comparison. All6 raw packages;149 remains hidden/data-only.',sources:files,acceptedDiagnostic:{checks:297,cleanEngine:true,sourceInputs:proof.inputs.length,dataInputs:proof.dataInputs.length,actorUnchanged:true},cases,finding:'No generic candidate mismatch. Every preference exhausts with one unused class-bonus slot. An allowed base Pact is absent from the preferences. Original automatic caller ignores the remainder, while current generic BIC validation demands all slots; manual canAccept correctly remains false.',proposedOwnership:{owner:'root/native_ui_parity',scope:'Distinct source-automatic recommendation receipt and validation only, reproducing exact pre-skill prescribed IDs/order/current table/class/race/ability context. Preserve manual completion and generic validation; reject stale/forged/changed selections.',notAuthorizedByThisReport:['Adding non-preference filler feats.','Blindly skipping every feat error for packageSource.','Changing raw cached tables or assigning hidden149 through UI.']},automaticBicAccepted:false,manualFullPathAccepted:{case:'cached-warlock-complete-v5',checks:342},serverAdmissionProven:false,productionEditedByThisScript:false,networkConnections:0};
fs.writeFileSync(target,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({report:path.relative(root,target),sha256:sha(fs.readFileSync(target)),cases:cases.length,diagnosticChecks:297,automaticBicAccepted:false}));
