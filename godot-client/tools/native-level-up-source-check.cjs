'use strict';
// Test-only observer. NetworkGameSession and the original server keep ownership
// of requests, acceptance and replicated state. No proposal/actor is modified.
const {isDeepStrictEqual}=require('node:util');
const scopeOwner=require('./native-creation-hp-owner.cjs');
const proof=require('./native-level-up-source-proof.cjs');
const {receivedSnapshot}=require('./native-level-up-snapshot-evidence.cjs');
const {captureLevelUpReplyScope}=require('./native-level-up-reply-scope.cjs');
const clone=value=>structuredClone(value);
const equalIds=(a,b)=>Array.isArray(a)&&Array.isArray(b)&&isDeepStrictEqual([...a].sort((x,y)=>x-y),[...b].sort((x,y)=>x-y));
const classes=value=>value.map(c=>({id:c.id,level:c.level}));
const total=value=>value.reduce((n,c)=>n+c.level,0);
function hp(actor){const value=actor.replicated?.hitPoints;if(!value||!Number.isInteger(value.current)||!Number.isInteger(value.maximum)||!Number.isInteger(value.fieldE8))throw Error('Canonical received HP disclosure is unavailable');return {current:value.current,maximum:value.maximum,temporary:value.fieldE8};}
function moduleFlags(session){
 const flags=session?.world?.module?.serverFlags;
 return {source:'session.world.module.serverFlags',fields:Object.fromEntries(['field158','field164'].map(key=>{const present=Boolean(flags&&Object.hasOwn(flags,key)),value=present?flags[key]:undefined,kind=typeof value;return [key,{present,kind,value:kind==='boolean'||kind==='number'&&Number.isFinite(value)?value:null}];}))};
}
function fromBegin(snapshot,actor){
 if(!snapshot||snapshot.actorId!==actor.id||!Array.isArray(snapshot.classes)||!Array.isArray(snapshot.baseAbilities)||snapshot.baseAbilities.length!==6||!Array.isArray(snapshot.skills)||!Array.isArray(snapshot.feats)||!snapshot.spellbooks)throw Error('Actual received begin snapshot is incomplete');
 return {actorId:actor.id,classes:classes(snapshot.classes),receivedClasses:clone(snapshot.classes),abilities:[...snapshot.baseAbilities],skills:[...snapshot.skills],feats:[...snapshot.feats],spellbooks:clone(snapshot.spellbooks),hp:hp(actor)};
}
function actualReplyEcho(handle,levelReply,result=null){
 const request=handle.value.requestLevelRequest;
 if(!levelReply||Reflect.ownKeys(levelReply).length!==1||!Object.hasOwn(levelReply,'levelRequest')||!request)throw Error('Actual local level-up reply metadata is missing');
 const echo=captureLevelUpReplyScope({operation:request.operation,generation:request.generation,areaId:request.areaId,actorId:request.actorId,levelRequest:levelReply.levelRequest});
 if(!isDeepStrictEqual(request,echo.levelRequest))throw Error('Actual local level-up reply metadata changed');
 return {action:'native-level-up',operation:handle.value.operation,requestToken:handle.value.token,requestLevelRequest:clone(request),echoedLevelRequest:clone(echo.levelRequest),metadataMatches:true,nestedResultToken:result?.token??null,serverAuthority:false,correlationScope:'Detached actual outgoing request metadata and captured Host echo. Local UI correlation only; original Session/server result ownership remains separate.'};
}
class SourceLevelUpCheck{
 constructor(recipe){this.recipe=clone(recipe);this.operations=[];this.classHistory=[];this.disclosures=[];this.lastClasses='';this.owner=null;this.exportOwner=null;this.export=null;this.native=null;this.failure=null;}
 current(session,connection){return this.owner&&scopeOwner.current(this.owner,session,connection);}
 request(session,connection,input){
  if(!['begin','cancel','submit'].includes(input.operation)||this.operations.length>=16)throw Error('Owned level-up operation exceeds its bounded schema');
  const requestEcho=captureLevelUpReplyScope(input);if(!requestEcho)throw Error('Source level-up request requires actual local reply metadata');
  const owner=scopeOwner.capture(session,connection);
  if(this.owner&&!scopeOwner.current(this.owner,session,connection))throw Error('Owned level-up authority scope retired');
  this.owner??=owner;
  const value={sequence:this.operations.length,at:Date.now(),operation:input.operation,scope:{...owner.scope},token:input.token??null,requestLevelRequest:clone(requestEcho.levelRequest),proposal:input.operation==='submit'?clone(input.proposal):null,pending:true};
  if(input.operation==='begin')value.moduleFlags=moduleFlags(session);
  if(Buffer.byteLength(JSON.stringify(value))>128*1024)throw Error('Owned level-up proposal exceeds evidence bound');
  this.operations.push(value);return {value,owner};
 }
 result(handle,session,connection,result,levelReply){
  scopeOwner.assertCurrent(handle.owner,session,connection);handle.value.pending=false;handle.value.completedAt=Date.now();
  handle.value.localResultEcho=actualReplyEcho(handle,levelReply,result);
  if(handle.value.operation==='begin'){
   if(!Number.isSafeInteger(result?.token)||result.token<0||!Array.isArray(result.available)||result.available.some(v=>typeof v!=='boolean'))throw Error('Original begin result/availability is incomplete');
   const full=receivedSnapshot(result.snapshot);
   handle.value.result={token:result.token,available:[...result.available],receivedSnapshot:full,before:fromBegin(full,handle.owner.actor),draftContext:clone(result.draftContext??null)};
  }else handle.value.result={accepted:result?.accepted===true,cancelled:result?.cancelled===true,sent:result?.sent===true,serverAcknowledged:result?.serverAcknowledged??null};
  this.observe(session,connection);
 }
 refused(handle,error,levelReply){if(handle){handle.value.pending=false;try{handle.value.localResultEcho=actualReplyEcho(handle,levelReply);}catch{handle.value.localResultEcho={metadataMatches:false,serverAuthority:false};}handle.value.error=String(error?.message??'Level-up operation failed').slice(0,256);}this.failure??='An owned level-up operation was refused or became uncertain';}
 observe(session,connection){
  if(!this.owner||!this.current(session,connection))return;
  const value=classes(this.owner.actor.replicated?.stats?.classes??[]),key=JSON.stringify(value);
  if(key!==this.lastClasses){if(this.classHistory.length>=16)throw Error('Received class history exceeds bound');this.lastClasses=key;this.classHistory.push({at:Date.now(),classes:value,hp:hp(this.owner.actor),scope:{...this.owner.scope}});}
 }
 disclosure(session,connection,message){
  if(!this.owner||!this.current(session,connection)||message.kind!=='object-updates')return;
  for(const row of message.records??[]){
   if(row.id!==this.owner.scope.actorId||row.action!=='player-state')continue;
   const value=row.state??{},fields=['levelUp','spellbooks','feats','abilities'].filter(k=>Object.hasOwn(value,k));if(!fields.length)continue;
   if(this.disclosures.length<64)this.disclosures.push({at:Date.now(),fields,scope:{...this.owner.scope}});
  }
 }
 snapshot(){
  const limit=4*1024*1024,counts={operations:this.operations.length,classHistory:this.classHistory.length,disclosures:this.disclosures.length};
  if(counts.operations>16||counts.classHistory>16||counts.disclosures>64)return {bounded:false,maxBytes:limit,counts,reason:'Observer record count exceeds its evidence bound'};
  const encoded=JSON.stringify({bounded:true,maxBytes:limit,counts,failure:this.failure,operations:this.operations,classHistory:this.classHistory,disclosures:this.disclosures});
  if(Buffer.byteLength(encoded)>limit)return {bounded:false,maxBytes:limit,counts,reason:'Observer evidence exceeds4MiB; oversized records omitted'};
  return JSON.parse(encoded);
 }
 prepare(native,session,connection){
  if(!this.current(session,connection)||this.native)throw Error('Level-up completion is stale or duplicate');
  if(Buffer.byteLength(JSON.stringify(native))>512*1024||native.driver!=='native-source-mode1-controls-v1'||native.success!==true||!Array.isArray(native.failures)||native.failures.length||!Number.isInteger(native.checks)||native.checks<20||native.checks>512||!Array.isArray(native.outcomes)||native.outcomes.length!==native.checks||native.outcomes.some(v=>v.passed!==true)||!Array.isArray(native.presentations)||native.presentations.length>64||!native.presentations.length||!native.presentations.every(proof.sourcePresentation))throw Error('Actual source UI proof is incomplete or used legacy controls');
  const scope=this.owner.scope,identity=[scope.generation,scope.areaId,scope.actorId],begins=this.operations.filter(v=>v.operation==='begin'&&v.result),tokens=begins.map(v=>v.result.token);
  if(!native.presentations.every(v=>isDeepStrictEqual(v.identity,identity)&&tokens.includes(v.token)))throw Error('Source presentation token/actor scope differs');
  for(const stage of this.recipe.requiredStages)if(!native.presentations.some(v=>v.stage===stage))throw Error('Required original source stage was not exercised: '+stage);
  const submitted=this.operations.filter(v=>v.operation==='submit');
  if(!Array.isArray(native.steps)||native.steps.length!==this.recipe.classes.length||submitted.length!==native.steps.length||submitted.some(v=>v.pending||v.result?.accepted!==true))throw Error('Every source step requires an actual original-server accepted result');
  for(let i=0;i<submitted.length;i++){
   const request=submitted[i],step=native.steps[i],begin=begins.find(v=>v.result.token===request.token);
   if(!begin||request.proposal.classId!==this.recipe.classes[i]||step.token!==request.token||!isDeepStrictEqual(step.proposal,request.proposal)||step.roll?.randomCalls!==1||step.roll.hitDie!==request.proposal.hitDie||step.roll.totalLevel!==total(begin.result.before.classes)+1||!Number.isInteger(step.displayHitPointGain)||step.displayHitPointGain<1||step.displayHitPointGain>127)throw Error('Source proposal/real private roll differs from the observed typed request');
   const witness=step.finalizationDiagnostics;
   if(!proof.finalizationWitness(witness,identity,step.token)||witness.classes[witness.currentClassIndex].id!==request.proposal.classId||witness.summary.hitDie!==request.proposal.hitDie||witness.summary.displayHitPointGain!==step.displayHitPointGain||!native.presentations.some(v=>v.stage==='summary'&&v.token===step.token&&isDeepStrictEqual(v.navigationTicket,witness.ticket)))throw Error('Source numeric finalization witness is incomplete, oversized or retired');
   if(!isDeepStrictEqual(classes(step.before.classes),begin.result.before.classes)||!isDeepStrictEqual(step.before.abilities,begin.result.before.abilities)||!isDeepStrictEqual(step.before.skills,begin.result.before.skills))throw Error('Source draft does not start from its actual received begin');
   if(!request.proposal.skills.some(v=>v>0))throw Error('Source Skills did not change a real rank');
  }
  if(this.recipe.groupFeat!==null&&!submitted.some(v=>v.proposal.feats.includes(this.recipe.groupFeat)))throw Error('Actual grouped Feat was not proposed');
  if(this.recipe.requiredStages.includes('spells')&&!submitted.some(v=>Object.values(v.proposal.known??{}).some(a=>a.length)))throw Error('Actual caster acquired no spell through the source pane');
  if(this.operations.filter(v=>v.operation==='cancel'&&v.result?.cancelled&&v.result.sent&&v.result.serverAcknowledged===false).length<2)throw Error('Actual Class and Summary cancellation intents are missing');
  if(this.failure||this.operations.some(v=>v.pending||v.error))throw Error('An uncertain/refused/stale operation cannot become acceptance');
  this.native=clone(native);this.observe(session,connection);this.exportOwner=scopeOwner.capture(session,connection);return true;
 }
 exported(session,connection,root,structType,fieldTypes){
  scopeOwner.assertCurrent(this.exportOwner,session,connection);
  this.export={at:Date.now(),scope:{...this.exportOwner.scope},saved:proof.exportedFacts(root,structType,fieldTypes),canonicalClasses:classes(this.exportOwner.actor.replicated.stats.classes),hp:hp(this.exportOwner.actor)};
 }
 finish(session,connection){
  if(!this.current(session,connection)||!this.native||!this.export)throw Error('Original export/current authority is missing');
  const begins=this.operations.filter(v=>v.operation==='begin'&&v.result),submits=this.operations.filter(v=>v.operation==='submit'),first=begins[0].result.before,expectedClasses=clone(first.classes),abilities=[...first.abilities],skills=[...first.skills],feats=[...first.feats];
  const known=new Map(first.classes.map((cls,index)=>{const book=first.spellbooks[String(index)]??first.spellbooks[index];if(!book||!Array.isArray(book.known))throw Error('Initial received spellbook storage is incomplete');return [cls.id,[...book.known]];}));
  const expectedHistory=[],hpAdvancements=[];
  for(const operation of submits){
   const index=expectedHistory.length,previousClasses=clone(expectedClasses),begin=begins.find(v=>v.result.token===operation.token),nextSubmit=submits[index+1];
   const p=operation.proposal;let cls=expectedClasses.find(v=>v.id===p.classId);if(!cls){cls={id:p.classId,level:0};expectedClasses.push(cls);known.set(p.classId,[]);}cls.level++;
   expectedHistory.push(clone(expectedClasses));if(p.ability<6)abilities[p.ability]++;p.skills.forEach((v,i)=>skills[i]+=v);for(const id of p.feats)if(!feats.includes(id))feats.push(id);
   const book=known.get(p.classId);for(const id of Object.values(p.removed??{}).flat()){const at=book.indexOf(id);if(at>=0)book.splice(at,1);}for(const id of Object.values(p.known??{}).flat())if(!book.includes(id))book.push(id);
   const nextBegin=nextSubmit?begins.find(v=>v.sequence>operation.sequence&&v.sequence<nextSubmit.sequence&&v.result.token===nextSubmit.token):null;
   const afterClasses=nextSubmit?nextBegin?.result.before.classes:this.export.canonicalClasses,afterHP=nextSubmit?nextBegin?.result.before.hp.maximum:this.export.hp.maximum,afterScope=nextSubmit?nextBegin?.scope:this.export.scope,beforeHP=begin?.result.before.hp.maximum,summary=this.native.steps[index]?.displayHitPointGain;
   const scoped=Boolean(begin&&isDeepStrictEqual(begin.scope,operation.scope)&&isDeepStrictEqual(afterScope,operation.scope)&&isDeepStrictEqual(begin.result.before.classes,previousClasses)&&isDeepStrictEqual(afterClasses,expectedClasses));
   hpAdvancements.push({token:operation.token,accepted:operation.result.accepted===true,scopedClassProgression:scoped,beforeMaximum:beforeHP??null,afterMaximum:afterHP??null,actualMaximumDelta:Number.isInteger(beforeHP)&&Number.isInteger(afterHP)?afterHP-beforeHP:null,sourceSummaryDelta:summary,anchor:nextSubmit?'next-accepted-step-begin':'fresh-original-export',matches:scoped&&operation.result.accepted===true&&Number.isInteger(beforeHP)&&Number.isInteger(afterHP)&&afterHP-beforeHP===summary});
  }
  const saved=this.export.saved,expectedMaximum=first.hp.maximum+this.native.steps.reduce((n,step)=>n+step.displayHitPointGain,0),checks={sourceOnly:true,actualServerResults:submits.every(v=>v.result.accepted),canonicalClasses:isDeepStrictEqual(this.export.canonicalClasses,expectedClasses),replicatedEveryAdvancement:expectedHistory.every(expected=>this.classHistory.some(v=>isDeepStrictEqual(v.classes,expected))),exportClasses:isDeepStrictEqual(classes(saved.classes),expectedClasses),exportAbilities:isDeepStrictEqual(saved.abilities,abilities),exportRawSkills:isDeepStrictEqual(saved.skills,skills),exportFeats:feats.every(id=>saved.feats.includes(id)),exportKnown:expectedClasses.every(c=>equalIds(saved.classes.find(v=>v.id===c.id)?.known.flat(),known.get(c.id))),sourceSummaryHpGain:expectedMaximum===this.export.hp.maximum,exportMaximumHP:saved.hp.maximum===this.export.hp.maximum,positiveHP:this.export.hp.maximum>0,temporaryHP:this.export.hp.temporary===0};
  if(this.recipe.requiredStages.includes('domains'))checks.exportDomains=submits.filter(v=>v.proposal.domains?.length===2).every(v=>isDeepStrictEqual(saved.classes.find(c=>c.id===v.proposal.classId)?.domains,v.proposal.domains));
  checks.typedExport=Boolean(saved.metadata&&['HitPoints','CurrentHitPoints','MaxHitPoints'].every(k=>saved.metadata.hp[k]===3)&&saved.metadata.skillRankBytes&&saved.metadata.featWords&&saved.metadata.classes.every(c=>c.class===5&&c.level===3&&c.knownWords.every(Boolean)&&c.memorizedWords.every(Boolean)));
  checks.sourceSummaryHpGainPerStep=hpAdvancements.length===submits.length&&hpAdvancements.every(value=>value.matches);
  checks.localReplyMetadataEchoes=this.operations.every(value=>value.requestLevelRequest&&value.localResultEcho?.metadataMatches===true&&isDeepStrictEqual(value.requestLevelRequest,value.localResultEcho.echoedLevelRequest));
  return {success:Object.values(checks).every(Boolean),sourceOnly:true,checks,case:this.recipe.name,expectedMaximumFromSourceSummaries:expectedMaximum,hpAdvancements,operations:this.operations,classHistory:this.classHistory,liveDisclosures:this.disclosures,export:this.export,sourcePresentationCount:this.native.presentations.length,scope:'Actual source mode1 controls, immutable original begin/proposals/server results, canonical replicated classes/HP and independent original BIC export. Raw skills are proved by fresh export; each Summary gain uses the next trusted begin or final export. No post-submit begin-cache freshness, blanket heal or server cancel ACK is invented.'};
 }
}
module.exports={SourceLevelUpCheck};
