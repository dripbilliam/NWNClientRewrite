// Offline creation regression against a previously authenticated manifest.
// No character upload, account creation, original-cache lookup or HTTP access.
import fs from 'node:fs/promises';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {resolveServerResources} from '../src/network_resources.js';
import {loadCreationRules,initialCreationDraft,creationErrors,creationSpellOptions,creationSpellCount,creationSpellSlots,rows,num,cell,creationHeadModels,creationPortraits,creationVoices,recommendCreation,creationClassRequirement} from '../src/character_creation.js';
const [install,cacheDirectory,advertisementFile,output]=process.argv.slice(2),advertisement=JSON.parse(await fs.readFile(advertisementFile,'utf8'));
const report={startedAt:new Date().toISOString(),httpAttempts:0,diagnostics:[],classes:[],races:[],failures:[]},resources=installedNetworkResources({install,cacheDirectory,reuseInstalledNWSync:false,onDiagnostic:d=>report.diagnostics.push(d),contentOptions:{fetch:()=>{report.httpAttempts++;throw Error('Offline creation probe may not fetch');}}});
try{
 const result=await resolveServerResources(advertisement.requirements,{...resources,language:0,onDiagnostic:d=>report.diagnostics.push(d)});if(!result.ready)throw Error('Cached server resources are unavailable');
 const resolver=await resources.openModule(null,result.resolved),rules=await loadCreationRules(resolver);report.manifest=advertisement.requirements.advertisement.hash;report.classColumns=rules.classes.columns;report.classAvailability=rows(rules.classes).map((c,id)=>({id,label:cell(c,'Label'),player:num(c,'PlayerClass'),prerequisite:cell(c,'PreReqTable')}));report.initial=initialCreationDraft(rules);report.initialClass=rows(rules.classes)[report.initial.classId];
 // Test each first-level playable class separately, including a martial class
 // with absent caster-only cells, and each playable race with the initial class.
 for(const [classId,cls]of rows(rules.classes).entries())if(num(cls,'PlayerClass')){
  try{const draft=initialCreationDraft(rules);draft.classId=classId;draft.packageId=num(cls,'Package');const validation=creationErrors(draft,rules),levels=[];for(let level=0;level<10;level++)levels.push({level,options:creationSpellOptions(draft,rules,level).length,choices:creationSpellCount(draft,rules,level),slots:creationSpellSlots(draft,rules,level)});report.classes.push({id:classId,label:cell(cls,'Label'),caster:num(cls,'SpellCaster'),available:!creationClassRequirement(draft,rules,classId),validationCount:validation.length,levels});}catch(error){report.failures.push({classId,error:error.message,stack:error.stack});}
 }
 for(const [raceId,race]of rows(rules.racialtypes).entries())if(num(race,'PlayerRace')){try{const draft=initialCreationDraft(rules);draft.raceId=raceId;const validation=creationErrors(draft,rules);report.races.push({id:raceId,heads:creationHeadModels(draft,rules).length,portraits:creationPortraits(draft,rules).length,voices:creationVoices(draft,rules).length,validationCount:validation.length});}catch(error){report.failures.push({raceId,error:error.message,stack:error.stack});}}
 report.success=report.failures.length===0;if(!report.success)process.exitCode=1;
}catch(error){report.failure={message:error.message,stack:error.stack};process.exitCode=1;}
finally{resources.close();report.finishedAt=new Date().toISOString();await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({success:report.success,httpAttempts:report.httpAttempts,classes:report.classes.length,races:report.races.length,failures:report.failures.length,failure:report.failure}));}
