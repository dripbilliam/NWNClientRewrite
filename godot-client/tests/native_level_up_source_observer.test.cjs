const test=require('node:test'),assert=require('node:assert/strict');
const {SourceLevelUpCheck}=require('../tools/native-level-up-source-check.cjs');
const {SOURCE_PANES}=require('../tools/native-level-up-source-proof.cjs');
function fixture(){
 const actor={id:42,objectType:5,areaId:7,replicated:{stats:{classes:[{id:10,level:15}]},hitPoints:{current:100,maximum:100,fieldE8:0}},playerState:{abilities:{base:[10,14,14,19,10,12]},levelUp:{skills:[1]},feats:[1],spellbooks:{'0':{known:[100]}}}};
 const world={localObjectId:42,areaId:7,registry:new Map([[42,actor]]),entityDisclosures:{token:o=>o===actor?32:0}},session={closed:false,peer:{closed:false},areaGeneration:1,world};
 const observer=new SourceLevelUpCheck({name:'authored-observer-unit',classes:[10,4],requiredStages:['class','attributes','skills','feats','spells','summary'],groupFeat:72});
 let requestSerial=0;
 const request=input=>observer.request(session,1,{...input,generation:1,areaId:7,actorId:42,levelRequest:{version:1,owner:'authored-observer-unit',entry:1,request:++requestSerial,generation:1,areaId:7,actorId:42,nativeLifetime:1,knownLifetime:32,operation:input.operation,token:input.operation==='begin'?-1:input.token??-1}});
 const respond=(handle,result)=>observer.result(handle,session,1,result,{levelRequest:structuredClone(handle.value.requestLevelRequest)});
 const snapshot=()=>({actorId:42,classes:structuredClone(actor.replicated.stats.classes),baseAbilities:[...actor.playerState.abilities.base],skills:[...actor.playerState.levelUp.skills],feats:[...actor.playerState.feats],spellbooks:structuredClone(actor.playerState.spellbooks)});
 const begin=token=>{const handle=request({operation:'begin'}),result={token,snapshot:snapshot(),available:Array(11).fill(true),draftContext:{baseFortitude:0}};respond(handle,result);return handle.value.result.before;};
 const cancel=token=>{const handle=request({operation:'cancel',token});respond(handle,{cancelled:true,sent:true,serverAcknowledged:false});};
 return {actor,world,session,observer,begin,cancel,request,respond};
}
test('trusted begin/proposal observations are detached and current canonical references are required',()=>{
 const f=fixture(),request=f.request({operation:'begin'}),snapshot={actorId:42,classes:[{id:10,level:15,school:0,domains:[1,3]}],baseAbilities:[10,14,14,19,10,12],skills:[1],feats:[1],spellbooks:{'0':{known:[100]}}};
 f.respond(request,{token:1,available:[true],snapshot,draftContext:{baseFortitude:0}});snapshot.skills[0]=99;assert.equal(request.value.result.before.skills[0],1);
 snapshot.classes[0].school=7;snapshot.classes[0].domains[0]=9;assert.deepEqual(request.value.result.before.classes,[{id:10,level:15}]);assert.deepEqual(request.value.result.before.receivedClasses,[{id:10,level:15,school:0,domains:[1,3]}]);
 assert.deepEqual(request.value.result.receivedSnapshot.classes,[{id:10,level:15,school:0,domains:[1,3]}]);assert.equal(request.value.result.receivedSnapshot.skills[0],1);
 const pending=f.request({operation:'submit',token:1,proposal:{classId:10,skills:[1]}});f.world.registry.set(42,{...f.actor});assert.throws(()=>f.respond(pending,{accepted:true}),/retired/);
});
test('failure evidence is detached, bounded and preserves exact numeric module flags',()=>{
 const f=fixture();f.world.module={serverFlags:{field158:0,field164:1}};f.begin(1);
 const saved=f.observer.snapshot();assert.equal(saved.bounded,true);assert.deepEqual(saved.operations[0].moduleFlags.fields.field158,{present:true,kind:'number',value:0});assert.deepEqual(saved.operations[0].moduleFlags.fields.field164,{present:true,kind:'number',value:1});
 f.world.module.serverFlags.field158=true;f.observer.operations[0].result.before.skills[0]=55;assert.equal(saved.operations[0].result.before.skills[0],1);assert.equal(saved.operations[0].moduleFlags.fields.field158.value,0);
 f.world.module.serverFlags.field158='untrusted-string';delete f.world.module.serverFlags.field164;f.begin(2);const invalid=f.observer.snapshot();assert.deepEqual(invalid.operations[1].moduleFlags.fields.field158,{present:true,kind:'string',value:null});assert.deepEqual(invalid.operations[1].moduleFlags.fields.field164,{present:false,kind:'undefined',value:null});
 f.observer.operations[0].oversized='x'.repeat(4*1024*1024);const oversized=f.observer.snapshot();assert.equal(oversized.bounded,false);assert.equal(oversized.operations,undefined);assert.ok(Buffer.byteLength(JSON.stringify(oversized))<512);
 const many=fixture();many.observer.disclosures=Array(65).fill({});assert.equal(many.observer.snapshot().bounded,false);
});
test('actual Host echo is required, detached and matched even on local refusal',()=>{
 const f=fixture(),handle=f.request({operation:'begin'}),echo={levelRequest:structuredClone(handle.value.requestLevelRequest)};
 f.observer.refused(handle,Error('Authored Session refusal'),echo);echo.levelRequest.owner='changed';assert.equal(handle.value.localResultEcho.metadataMatches,true);assert.equal(handle.value.localResultEcho.echoedLevelRequest.owner,'authored-observer-unit');assert.equal(handle.value.localResultEcho.serverAuthority,false);
 const g=fixture(),pending=g.request({operation:'begin'}),wrong={levelRequest:{...pending.value.requestLevelRequest,request:99}};assert.throws(()=>g.observer.result(pending,g.session,1,{token:1,available:[true],snapshot:{}},wrong),/metadata changed/);g.observer.refused(pending,Error('Authored echo refusal'),wrong);assert.equal(pending.value.localResultEcho.metadataMatches,false);assert.ok(g.observer.failure);
 assert.throws(()=>fixture().observer.request(f.session,1,{operation:'begin'}),/requires actual local reply metadata/);
});
test('independent export proves final raw ranks even when last-begin rank cache stays stale',async()=>{
 const f=fixture();f.begin(1);f.cancel(1);f.begin(2);f.cancel(2);const before1=f.begin(3);
 const proposal=(id,ability,known,feats)=>({classId:id,ability,hitDie:3,skills:[1],skillPoints:0,feats,known,removed:{},fieldE34:-1,fieldE48:'',fieldE30:-1,fieldE38:'',domains:[],school:0});
 const first=proposal(10,3,{'0':[101]},[]),request1=f.request({operation:'submit',token:3,proposal:first});f.respond(request1,{accepted:true});
 f.actor.replicated.stats.classes[0].level=16;f.actor.playerState.abilities.base[3]=20;f.actor.playerState.levelUp.skills[0]=2;f.actor.playerState.spellbooks['0'].known.push(101);f.actor.replicated.hitPoints.maximum=105;f.observer.observe(f.session,1);
 const before2=f.begin(4),second=proposal(4,6,{},[72]),request2=f.request({operation:'submit',token:4,proposal:second});f.respond(request2,{accepted:true});
 f.actor.replicated.stats.classes.push({id:4,level:1});f.actor.playerState.feats.push(72);f.actor.replicated.hitPoints.maximum=110;f.observer.observe(f.session,1);
 const presentation=(stage,token)=>{const navigationTicket=[1,7,42,token,1,stage];return {sourceActive:true,genericVisible:false,runtimeOwns:true,paneVisible:true,wanted:true,ready:true,frontend:'res://systems/native_level_up_frontend.gd',identity:[1,7,42],navigationTicket,ticket:[...navigationTicket,2,stage],token,stage,pane:SOURCE_PANES[stage]};};
 const witness=(token,before,p)=>{const cls=structuredClone(before.classes);let c=cls.find(c=>c.id===p.classId);if(!c){c={id:p.classId,level:0};cls.push(c);}c.level++;const raw=before.abilities.map((v,i)=>v+(p.ability===i?1:0));return {ready:true,scope:[1,7,42,token],ticket:[1,7,42,token,1,'summary'],classes:cls,currentClassIndex:cls.indexOf(c),vitals:{raw,racial:Array(6).fill(0),gains:Array(6).fill(0),scores:[...raw],modifiers:raw.map(v=>Math.floor((v-10)/2))},ownedFeats:[...before.feats],primaryFeats:[...before.feats,...p.feats],ownedTypes:before.feats.map(()=>2),primaryTypes:[...before.feats,...p.feats].map(()=>2),literalInt40Membership:{owned:before.feats.includes(40),primary:[...before.feats,...p.feats].includes(40)},moduleFlags:{forceMaximum:false,hideHitPointGain:false},toughnessHPBonus:1,summary:{hitDie:3,displayHitPointGain:5,hiddenHitPointGain:false},serverAcknowledged:false};};
 const native={driver:'native-source-mode1-controls-v1',success:true,checks:20,outcomes:Array.from({length:20},()=>({passed:true})),failures:[],presentations:['class','attributes','skills','spells','summary'].map(s=>presentation(s,3)).concat(['class','skills','feats','summary'].map(s=>presentation(s,4))),steps:[{token:3,before:before1,proposal:first,displayHitPointGain:5,finalizationDiagnostics:witness(3,before1,first),roll:{randomCalls:1,hitDie:3,totalLevel:16}},{token:4,before:before2,proposal:second,displayHitPointGain:5,finalizationDiagnostics:witness(4,before2,second),roll:{randomCalls:1,hitDie:3,totalLevel:17}}]};
 f.observer.prepare(native,f.session,1);
 const {parseGff,getGffStructType,getGffFieldTypes}=await import('../../src/gff.js'),{writeGff,gffField:F,gffRecord:R}=await import('../../src/gff_writer.js');
 const fields={ClassList:F(15,[R({Class:F(5,10),ClassLevel:F(3,16),KnownList0:F(15,[R({Spell:F(2,100)},3),R({Spell:F(2,101)},3)])},2),R({Class:F(5,4),ClassLevel:F(3,1)},2)]),SkillList:F(15,[R({Rank:F(0,3)})]),FeatList:F(15,[R({Feat:F(2,1)}),R({Feat:F(2,72)})])};
 for(const[k,v]of Object.entries({Str:10,Dex:14,Con:14,Int:20,Wis:10,Cha:12}))fields[k]=F(0,v);
 for(const[k,v]of Object.entries({HitPoints:100,CurrentHitPoints:100,MaxHitPoints:110,PregameCurrent:110}))fields[k]=F(3,v);
 const root=parseGff(writeGff('BIC ',R(fields)),'BIC ').root;
 f.observer.exported(f.session,1,root,getGffStructType,getGffFieldTypes);const result=f.observer.finish(f.session,1);assert.equal(result.success,true);assert.equal(result.checks.typedExport,true);assert.equal(f.actor.playerState.levelUp.skills[0],2);assert.equal(result.export.saved.skills[0],3);assert.match(result.scope,/fresh export/);
 const originalNative=f.observer.native;f.observer.native=structuredClone(originalNative);f.observer.native.steps[0].displayHitPointGain=6;f.observer.native.steps[0].finalizationDiagnostics.summary.displayHitPointGain=6;f.observer.native.steps[1].displayHitPointGain=4;f.observer.native.steps[1].finalizationDiagnostics.summary.displayHitPointGain=4;const offset=f.observer.finish(f.session,1);assert.equal(offset.checks.sourceSummaryHpGain,true);assert.equal(offset.checks.sourceSummaryHpGainPerStep,false);assert.equal(offset.success,false);assert.deepEqual(offset.hpAdvancements.map(v=>v.actualMaximumDelta),[5,5]);f.observer.native=originalNative;
 root.SkillList[0].Rank=2;f.observer.exported(f.session,1,root,getGffStructType,getGffFieldTypes);assert.equal(f.observer.finish(f.session,1).success,false);
});
