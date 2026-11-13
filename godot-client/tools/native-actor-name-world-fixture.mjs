// Authored decoded-like protocol records through the actual canonical and
// transport owners. This generator does no TLK/text resolution or scene/model
// preparation. The consuming Godot fixture owns text bytes and UI assertions.
import assert from 'node:assert/strict';
import {NetworkWorld} from '../../src/network_world.js';
import combatModule from './raw-combat-events.cjs';
import scopeModule from './native-text-event-scope.cjs';
import deltaModule from './raw-world-deltas.cjs';
const {RawCombatEvents}=combatModule,{NativeTextEventScope}=scopeModule,{RawWorldDeltas}=deltaModule;
const ID=0x80000042,AREA=91,CONNECTION=3,GENERATION=7;
const copy=value=>JSON.parse(JSON.stringify(value));
const A=()=>({action:'create',objectType:5,id:ID,state:{position:[2,4,0],orientation:[0,1,0],animation:0,visualTransform:{keys:[],entries:[]}}});
const P=name=>({action:'appearance',objectType:5,id:ID,mask:0x400,state:{name}});
const U=name=>({action:'update',objectType:5,id:ID,mask:0x10000,state:{name}});
const D=()=>({action:'delete',objectType:5,id:ID,remove:1});
const speech=text=>({kind:'server-speech',channel:1,objectId:ID,text:{text}});

function context(){
 const diagnostics=[],world=new NetworkWorld({onDiagnostic:value=>diagnostics.push(copy(value))});
 // The authored area/connection are test scope inputs, not native area data or
 // scene preparation. Every actor/name mutation below uses actual World.apply.
 world.areaId=AREA;
 world.apply({kind:'object-control',major:5,minor:2,playerId:0,objectId:ID});
 const identities=new RawCombatEvents(),events=new NativeTextEventScope(identities),deltas=new RawWorldDeltas();
 return{world,diagnostics,identities,events,deltas,connection:CONNECTION,generation:GENERATION,serial:0,last:null};
}
const scope=c=>({connection:c.connection,generation:c.generation,areaId:c.world.areaId});
const state=c=>c.world.nativeActorNameFor(c.world.registry.get(ID));
function apply(c,records,complete=true){
 const message={kind:'object-updates',complete,records:copy(records)};
 assert.equal(c.world.apply(message),true);return message;
}
function rows(c){
 return[...c.world.registry.objects.values()].map(object=>c.world.entityDisclosures.transportRow(object,{
  ...c.identities.object(object),nativeActorNameState:c.world.nativeActorNameFor(object),
 })).map(copy);
}
function snapshot(c,label,expected={}){
 const worldRows=rows(c),actorNameHistory=c.world.nativeActorNameHistory();
 const data={objects:worldRows,actorNameHistory,controlledId:c.world.localObjectId,entry:c.world.entry,time:c.world.time,module:c.world.module,ui:{}};
 const serial=++c.serial,wire=c.deltas.plan({connection:c.connection,generation:c.generation,serial,data});
 const {objects:ignored,...header}=copy(data);void ignored;
 const step={kind:wire?.bridgeMode==='full'?'snapshot':'delta',label,scope:scope(c),objects:wire?copy(wire.objects):[],removed:wire?copy(wire.removedObjectIds):[],header,actorNameHistory:copy(actorNameHistory),worldRows,changedIDs:wire?wire.objects.map(row=>row.id):[],expected:copy(expected)};
 step.bridge=wire?{mode:wire.bridgeMode,serial,baseSerial:wire.bridgeBaseSerial}:{mode:'unchanged',serial:null,baseSerial:null};
 if(wire)assert.equal(c.deltas.acknowledge({connection:c.connection,generation:c.generation,serial}),true);
 c.last=copy(step);return step;
}
function capture(c,label,body,expected={}){
 const message=speech(body),nativeTextEvent=c.events.capture(c.world,message,c.generation,c.connection);
 assert.ok(nativeTextEvent&&nativeTextEvent.source,'authored chat requires an actual current source');
 return{kind:'speech',label,scope:scope(c),message:copy({...message,nativeTextEvent}),nativeTextEvent:copy(nativeTextEvent),expected:copy(expected)};
}
function data(c,label,message){
 c.world.apply(copy(message));return{kind:'data',label,scope:scope(c),message:copy(message)};
}
function assertRows(step){
 for(const row of step.worldRows){
  assert.equal(row.id,ID);assert.ok(Number.isSafeInteger(row.nativeLifetime)&&row.nativeLifetime>0);
  if(row.replicationRemoved)assert.equal(row.clientKnownLifetime,null);
  else assert.ok(Number.isSafeInteger(row.clientKnownLifetime)&&row.clientKnownLifetime>0);
 }
 assert.deepEqual(step.header.actorNameHistory,step.actorNameHistory);
 assert.deepEqual(step.changedIDs,step.objects.map(row=>row.id));
}

export function actorNameWorldFixture(){
 const cases={};let protocolChecks=0;
 const check=callback=>{callback();protocolChecks++;};
 {
  const c=context(),steps=[];
  apply(c,[A(),P({firstName:{text:'Actor First'},lastName:{text:'Actor Last'}})]);
  steps.push(snapshot(c,'actor-p',{actorFirst:'Actor First',actorLast:'Actor Last',constructor:'new'}));
  const before=state(c);apply(c,[U({firstName:{text:'Party First'},lastName:{text:'Party Last'}})]);
  steps.push(snapshot(c,'party-u-only',{actorFirst:'Actor First',partyFirst:'Party First'}));
  steps.push(capture(c,'actor-after-party-u','Basic actor body'));
  check(()=>assert.deepEqual(state(c),before));check(()=>assert.equal(c.world.registry.get(ID).replicated.name.firstName.text,'Party First'));
  cases.actorVersusParty={steps};
 }
 {
  const c=context(),steps=[];apply(c,[A(),P({text:'Name at event'})]);steps.push(snapshot(c,'initial-name'));
  const old=capture(c,'captured-before-rename','Old receipt body',{actorFirst:'Name at event'});
  apply(c,[P({text:'Name in newer raw'})]);steps.push(snapshot(c,'newer-raw-before-old-event',{actorFirst:'Name in newer raw'}));
  // Native event was captured first; deliberately deliver it after a newer raw
  // snapshot to exercise the real bridge coalescing/order distinction.
  steps.push(old);steps.push(capture(c,'new-event-after-newer-raw','New receipt body',{actorFirst:'Name in newer raw'}));
  check(()=>assert.equal(old.nativeTextEvent.actorName.state.publication.first.text,'Name at event'));
  check(()=>assert.equal(steps[1].worldRows[0].nativeActorNameState.publication.first.text,'Name in newer raw'));
  cases.eventBeforeNewRaw={steps};
 }
 {
  const c=context(),steps=[];apply(c,[A(),P({text:'Published raw name'})]);steps.push(snapshot(c,'old-raw'));
  apply(c,[P({text:'New event name'})]);steps.push(capture(c,'new-p-event-before-raw','New event before raw body',{actorFirst:'New event name'}));
  // No raw publication occurred between P and this event. The consuming UI's
  // object map still has step0 until step2 is delivered.
  steps.push(snapshot(c,'publish-new-p-after-event',{actorFirst:'New event name'}));
  check(()=>assert.equal(steps[0].worldRows[0].nativeActorNameState.publication.first.text,'Published raw name'));
  check(()=>assert.equal(steps[1].nativeTextEvent.actorName.state.publication.first.text,'New event name'));
  cases.eventBeforeItsRaw={steps};
 }
 {
  const c=context(),steps=[];apply(c,[A()]);steps.push(snapshot(c,'fresh-ctor-without-p',{publication:null,constructor:'new'}));
  steps.push(capture(c,'ctor-empty-chat','Ctor empty body',{constructorEmpty:true}));
  check(()=>assert.equal(state(c).publication,null));check(()=>assert.deepEqual(state(c).override,{known:true,text:''}));
  cases.constructorEmpty={steps};
 }
 {
  const c=context(),steps=[];
  steps.push(data(c,'custom-at-p',{kind:'custom-token',id:12,text:'Café at P'}));
  steps.push(data(c,'direct-override-at-p',{kind:'tlk-overrides',entries:[{strRef:200,text:'<CUSTOM12>'}]}));
  apply(c,[A(),P({firstName:{strRef:200,gender:1},lastName:{text:'Last at P'}})]);
  steps.push(snapshot(c,'captured-ref-custom-p'));
  const captured=state(c);
  steps.push(data(c,'later-custom',{kind:'custom-token',id:12,text:'Later token'}));
  steps.push(data(c,'later-direct-override',{kind:'tlk-overrides',entries:[{strRef:200,text:'Later override'}]}));
  steps.push(capture(c,'chat-keeps-p-snapshot','Captured CUSTOM body',{firstRef:200,selectedOverride:'<CUSTOM12>'}));
  steps.push(snapshot(c,'unchanged-actor-after-live-data'));
  check(()=>assert.deepEqual(state(c),captured));
  check(()=>assert.deepEqual(captured.publication.environment.customTokens.records,[{id:12,bytes:[67,97,102,233,32,97,116,32,80]}]));
  check(()=>assert.equal(steps[5].nativeTextEvent.actorName.state.publication.first.override.text,'<CUSTOM12>'));
  cases.capturedCustomOverride={steps};
 }
 {
  const c=context(),steps=[];apply(c,[A(),P({firstName:{strRef:100,gender:1},lastName:{strRef:101,gender:0}})]);
  steps.push(snapshot(c,'base-selection-at-p'));
  steps.push(data(c,'late-override-after-base-p',{kind:'tlk-overrides',entries:[{strRef:100,text:'Not the stored base selection'}]}));
  steps.push(capture(c,'base-selection-chat','Base ref body',{selectedOverridePresent:false,firstRef:100,lastRef:101}));
  check(()=>assert.deepEqual(state(c).publication.first.override,{known:true,present:false}));
  cases.baseBeforeLateOverride={steps};
 }
 {
  const c=context(),steps=[];apply(c,[A(),P({firstName:{strRef:999,gender:0},lastName:{text:'Pending last'}})]);
  steps.push(snapshot(c,'pending-base-p'));steps.push(capture(c,'pending-base-chat','Pending base body',{firstRef:999,pending:true}));
  apply(c,[P({text:'Replacement before base ready'})]);steps.push(snapshot(c,'new-p-retires-pending-base'));
  steps.push(capture(c,'current-after-pending-replaced','Replacement body',{actorFirst:'Replacement before base ready'}));
  const prior=c.world.registry.get(ID),nativeBefore=c.identities.identity(prior),knownBefore=c.world.entityDisclosures.token(prior);
  apply(c,[D()]);steps.push(snapshot(c,'removed-retained-proxy',{removed:true}));
  check(()=>assert.equal(c.world.registry.get(ID),prior));check(()=>assert.equal(steps.at(-1).removed.length,0));
  apply(c,[A()]);steps.push(snapshot(c,'ambiguous-redisclosure-without-p',{publicationCurrent:false}));
  steps.push(capture(c,'chat-after-ambiguous-redisclosure','Ambiguous body',{namePending:true}));
  check(()=>assert.equal(c.identities.identity(c.world.registry.get(ID)),nativeBefore));
  check(()=>assert.notEqual(c.world.entityDisclosures.token(c.world.registry.get(ID)),knownBefore));
  check(()=>assert.equal(state(c).publication.current,false));
  apply(c,[P({text:'Current P after redisclosure'})]);steps.push(snapshot(c,'current-p-after-redisclosure'));
  steps.push(capture(c,'chat-after-current-p','Republished body',{actorFirst:'Current P after redisclosure'}));
  cases.pendingThenReplaceRemoveReuse={steps};
 }
 {
  const c=context(),steps=[];
  apply(c,[U({text:'Generic proxy party name'})]);steps.push(snapshot(c,'generic-proxy-before-a',{privateState:null}));
  apply(c,[A(),P({text:'P on unknown constructor'})]);steps.push(snapshot(c,'unknown-constructor-after-generic-proxy',{constructor:'unknown',overrideKnown:false}));
  steps.push(capture(c,'unknown-constructor-chat','Unknown constructor body',{namePending:true}));
  check(()=>assert.equal(state(c).construction.kind,'unknown'));check(()=>assert.equal(state(c).override.known,false));
  cases.genericProxyUnknown={steps};
 }
 {
  const c=context(),steps=[];apply(c,[A(),P({text:'Before history taint'})]);steps.push(snapshot(c,'complete-before-taint'));
  const before=capture(c,'captured-before-history-taint','Before taint body');
  apply(c,[],false);steps.push(snapshot(c,'incomplete-prefix-taints-history',{historyComplete:false}));
  steps.push(capture(c,'chat-after-incomplete-prefix','After taint body',{historyComplete:false}));
  apply(c,[P({text:'Later complete packet'})],true);steps.push(snapshot(c,'complete-packet-does-not-repair-history',{historyComplete:false}));
  steps.push(before);
  check(()=>assert.equal(c.world.nativeActorNameHistory().complete,false));
  check(()=>assert.equal(before.nativeTextEvent.actorName.historyComplete,true));
  check(()=>assert.equal(steps[2].nativeTextEvent.actorName.historyComplete,false));
  cases.stickyIncompleteHistory={steps};
 }
 {
  const c=context(),steps=[];apply(c,[A(),P({text:'Before rejected transaction'})]);steps.push(snapshot(c,'before-rejected-transaction'));
  const before=state(c),serial=c.world.nativeActorNameSequence();
  let rejected=false;try{apply(c,[P({text:'Must roll back'}),{action:'create',objectType:6,id:ID,state:{}}]);}catch{rejected=true;}
  check(()=>assert.equal(rejected,true));check(()=>assert.deepEqual(state(c),before));check(()=>assert.equal(c.world.nativeActorNameSequence(),serial));
  steps.push(snapshot(c,'rejection-taints-without-committing-name',{historyComplete:false,actorFirst:'Before rejected transaction'}));
  steps.push(capture(c,'chat-after-rejected-transaction','Rejected-history body',{historyComplete:false}));
  cases.rejectedTransactionHistory={steps};
 }
 {
  const c=context(),steps=[];apply(c,[A(),P({firstName:{strRef:999,gender:0},lastName:{text:'Old pending'}})]);
  steps.push(snapshot(c,'old-connection-pending'));const old=capture(c,'old-connection-event','Old connection body',{firstRef:999});
  steps.push(old);const oldObject=c.world.registry.get(ID),oldNative=c.identities.identity(oldObject),oldKnown=c.world.entityDisclosures.token(oldObject);
  c.world.reset();c.world.areaId=AREA;c.connection=CONNECTION+1;c.generation=GENERATION+1;
  c.world.apply({kind:'object-control',major:5,minor:2,playerId:0,objectId:ID});
  apply(c,[A(),P({text:'Reconnect current actor'})]);steps.push(snapshot(c,'new-connection-same-id',{constructor:'new',actorFirst:'Reconnect current actor'}));
  steps.push(capture(c,'new-connection-chat','Reconnect body',{actorFirst:'Reconnect current actor'}));
  const stale=copy(old);stale.label='replay-old-event-in-new-scope';stale.scope=scope(c);stale.expected={stale:true};steps.push(stale);
  check(()=>assert.notEqual(c.world.registry.get(ID),oldObject));check(()=>assert.notEqual(c.identities.identity(c.world.registry.get(ID)),oldNative));
  check(()=>assert.notEqual(c.world.entityDisclosures.token(c.world.registry.get(ID)),oldKnown));
  check(()=>assert.equal(c.world.nativeActorNameFor(oldObject),null));
  check(()=>assert.equal(stale.message.nativeTextEvent.connection,CONNECTION));check(()=>assert.equal(stale.scope.connection,CONNECTION+1));
  cases.reconnectScope={steps};
 }
 for(const scenario of Object.values(cases))for(const step of scenario.steps){
  if(step.kind==='snapshot'||step.kind==='delta')check(()=>assertRows(step));
  else if(step.kind==='speech')check(()=>assert.deepEqual(step.message.nativeTextEvent,step.nativeTextEvent));
 }
 const fixture={version:1,id:ID,areaId:AREA,connection:CONNECTION,generation:GENERATION,references:{baseFirst:100,baseLast:101,pending:999,override:200},
  provenance:{method:'actual NetworkWorld.apply +private getter +RawCombatEvents +EntityDisclosureLifetimes +NativeTextEventScope.capture +RawWorldDeltas',authoredDecodedRecords:true,originalPacketExecution:false,jsTextResolution:false,scenePreparation:false,networkConnections:0},
  protocolChecks,cases};
 // The consumer writes this exact detached JSON data. No Map, Uint8Array,
 // private canonical object, method, or live-world reference crosses it.
 return copy(fixture);
}
