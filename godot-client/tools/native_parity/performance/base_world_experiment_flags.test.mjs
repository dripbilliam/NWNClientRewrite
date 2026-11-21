import test from 'node:test';
import assert from 'node:assert/strict';
import {baseWorldExperimentFlags,validateReplayCapsuleOptions} from './replay_client_capsule.mjs';

test('existing capsules keep both experiments off',()=>{
 assert.deepEqual(baseWorldExperimentFlags(undefined),[]);
 assert.deepEqual(baseWorldExperimentFlags({}),[]);
 assert.deepEqual(baseWorldExperimentFlags({baseOwner:'original',baseTemplates:'original'}),[]);
});
test('reviewed variants isolate retained service and earlier template lookup',()=>{
 assert.deepEqual(baseWorldExperimentFlags({baseOwner:'retained'}),['--base-scenery-owner=retained']);
 const both={baseOwner:'retained',baseTemplates:'retained'},before=structuredClone(both);
 assert.deepEqual(baseWorldExperimentFlags(both),['--base-scenery-owner=retained','--base-scenery-templates=retained']);
 assert.deepEqual(both,before);
});
test('missing owner dependency cannot silently produce a non-exercised candidate',()=>{
 for(const value of [{baseTemplates:'retained'},{baseOwner:'original',baseTemplates:'retained'}])assert.throws(()=>baseWorldExperimentFlags(value),/requires/);
});
test('unreviewed fields and values cannot become engine or script arguments',()=>{
 for(const value of [null,[],true,'--path=other',{baseOwner:'true'},{baseOwner:'retained --path=other'},{baseOwner:1},{baseOwner:undefined},{renderThread:'safe'},JSON.parse('{"__proto__":"retained"}')])assert.throws(()=>baseWorldExperimentFlags(value),/reviewed/);
});
test('caller cannot override reviewed experiments',()=>{
 for(const name of ['base-scenery-owner','base-scenery-templates','base-scenery-template-probe','base-scenery-admission','shared-animation-preparation','base-scenery-stream','static-scenery'])assert.throws(()=>validateReplayCapsuleOptions({sourceProject:'unused'},key=>key===name?'retained':undefined),/reviewed pinned capsule/);
 assert.doesNotThrow(()=>validateReplayCapsuleOptions({sourceProject:'unused'},()=>undefined));
});

test('common-source scheduling control and combined candidate select exact native modes',()=>{
 const control={baseOwner:'retained',baseTemplates:'retained',baseReadyProbe:'ordinary',baseAdmission:'ordinary'};
 const combined={...control,baseReadyProbe:'ready',baseAdmission:'timed'};
 const original=structuredClone(combined);
 assert.deepEqual(baseWorldExperimentFlags(control),['--base-scenery-owner=retained','--base-scenery-templates=retained']);
 assert.deepEqual(baseWorldExperimentFlags(combined),['--base-scenery-owner=retained','--base-scenery-templates=retained','--base-scenery-template-probe=ready','--base-scenery-admission=timed']);
 assert.deepEqual(combined,original);
});

test('ready probing requires retained templates while timed admission is independently selectable',()=>{
 for(const value of [{baseReadyProbe:'ready'},{baseOwner:'retained',baseReadyProbe:'ready'},{baseOwner:'retained',baseTemplates:'original',baseReadyProbe:'ready'}])assert.throws(()=>baseWorldExperimentFlags(value),/requires/);
 assert.deepEqual(baseWorldExperimentFlags({baseAdmission:'timed'}),['--base-scenery-admission=timed']);
 assert.deepEqual(baseWorldExperimentFlags({baseReadyProbe:'ordinary',baseAdmission:'ordinary'}),[]);
});

test('scheduling modes reject cross-mode values and injected arguments',()=>{
 for(const value of [{baseOwner:'ready'},{baseTemplates:'timed'},{baseReadyProbe:'retained'},{baseAdmission:'retained'},{baseReadyProbe:true},{baseAdmission:null},{baseAdmission:'timed --path=other'}])assert.throws(()=>baseWorldExperimentFlags(value),/Invalid reviewed/);
});

test('pipeline experiments retain old defaults and exact separate flags',()=>{
 assert.deepEqual(baseWorldExperimentFlags({sharedAnimations:'ordinary',baseStreaming:'waves',staticScenery:'individual'}),[]);
 assert.deepEqual(baseWorldExperimentFlags({sharedAnimations:'shared'}),['--shared-animation-preparation=true']);
 assert.deepEqual(baseWorldExperimentFlags({staticScenery:'batched'}),['--static-scenery=batched']);
 assert.deepEqual(baseWorldExperimentFlags({staticScenery:'merged'}),['--static-scenery=merged']);
 assert.deepEqual(baseWorldExperimentFlags({baseOwner:'retained',baseTemplates:'retained',baseStreaming:'continuous'}),['--base-scenery-owner=retained','--base-scenery-templates=retained','--base-scenery-stream=continuous']);
});

test('continuous pipeline prerequisites and enum isolation stay explicit',()=>{
 for(const value of [{baseStreaming:'continuous'},{baseOwner:'retained',baseStreaming:'continuous'},{baseTemplates:'retained',baseStreaming:'continuous'}])assert.throws(()=>baseWorldExperimentFlags(value),/requires/);
 for(const value of [{sharedAnimations:true},{staticScenery:'shared'},{baseStreaming:'batched'},{staticScenery:'batched --path=elsewhere'}])assert.throws(()=>baseWorldExperimentFlags(value),/Invalid reviewed/);
});

test('model draw cache and BASE draw modes stay independent and bounded',()=>{
 assert.deepEqual(baseWorldExperimentFlags({baseDraw:'individual',nativeDrawCache:'none'}),[]);
 assert.deepEqual(baseWorldExperimentFlags({baseDraw:'merged'}),['--base-scenery-draw=merged']);
 assert.deepEqual(baseWorldExperimentFlags({nativeDrawCache:'prepared'}),['--native-draw-cache=prepared','--native-draw-cache-gib=25']);
 for(const value of [{baseDraw:'batched'},{nativeDrawCache:true},{nativeDrawCache:'prepared --path=elsewhere'}])assert.throws(()=>baseWorldExperimentFlags(value),/Invalid reviewed/);
 for(const name of ['base-scenery-draw','native-draw-cache','native-draw-cache-gib'])assert.throws(()=>validateReplayCapsuleOptions({sourceProject:'unused'},key=>key===name?'prepared':undefined),/reviewed pinned capsule/);
});

test('known-property template recipes need an explicit frozen variant',()=>{
 assert.deepEqual(baseWorldExperimentFlags({modelTemplates:'packed'}),[]);
 assert.deepEqual(baseWorldExperimentFlags({modelTemplates:'recipe'}),['--model-template=recipe']);
 for(const value of [{modelTemplates:true},{modelTemplates:'duplicate'},{modelTemplates:'recipe --path=x'}])assert.throws(()=>baseWorldExperimentFlags(value),/Invalid reviewed/);
 assert.throws(()=>validateReplayCapsuleOptions({sourceProject:'unused'},key=>key==='model-template'?'recipe':undefined),/reviewed pinned capsule/);
});
