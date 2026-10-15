import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnHeartbeatPerception,cleanPersonalReputations,cleanInvitationLists} from '../src/creature_heartbeat.js';
import {NativeAIMaster,scriptSetAILevel} from '../src/native_ai_master.js';
import {ModuleSession} from '../src/module_session.js';
const invalid=0x7f000000;
function fixture(){
  const actor={id:0x80000001,areaId:9,position:[5,0,-5],nativeSpawnState548:1,nativeField948:invalid,
    nativeHeartbeatDay54c:2,nativeHeartbeatTime550:1000,nativeHeartbeatInterval554:6000,nativeHeartbeatCounter584:0,
    nativePerceptionDay578:2,nativePerceptionTime57c:1000,nativePerceptionCounter580:0,nativeAILevel7c:4,nativeAILocked80:0,
    masterId:invalid,associateType:0,nativeField8d6:0,nativeField771:0,nativeFieldEc:8,nativeField58c:0,
    nativeOrphanState918:0,nativeOrphanDay91c:0,nativeOrphanTime920:0,nativeReputationCounter590:0,
    nativeAutoMapTileX6e4:255,nativeAutoMapTileY6e5:255,nativeAutoMapArea6e8:invalid};
  const trace=[],now={day:2,time:4999},area={id:9,nativePlayerCount150:1};
  const p={dayLength:7200000,activeTime:()=>now,worldTime:()=>now,random:()=>{trace.push('random');return 101;},
    runEvent:(o,type)=>trace.push(['script',type]),dead:()=>0,dying:()=>0,possessed:()=>0,pc:()=>0,
    rulesetInt:(n,d)=>d,creature:()=>null,cleanInvitations:()=>trace.push('invitations'),cleanReputations:()=>trace.push('reputations'),
    updateVisibility:()=>trace.push('visibility'),client:()=>null,area:()=>area,setAILevel:(o,v)=>{trace.push(['level',v]);o.nativeAILevel7c=v;},
    clearActions:()=>trace.push('clear'),enqueue:(...args)=>trace.push(['event',...args]),removeDomination:()=>trace.push('domination'),
    controlScript:(o,type)=>trace.push(['control',type]),setAssociateType:(o,v)=>{trace.push(['associate',v]);o.associateType=v;},setMasterId:(o,v)=>{trace.push(['master',v]);o.masterId=v;},
    tile:()=>({x:0,y:0}),updateAutoMap:()=>trace.push('automap')};
  return{actor,trace,now,area,p};
}
test('NPC perception threshold is inclusive 4000 and PC threshold inclusive 200 with exact frame flag',async()=>{
  const {actor,trace,now,p}=fixture();await spawnHeartbeatPerception(actor,1,p);assert.deepEqual(trace,[]);
  now.time=5000;await spawnHeartbeatPerception(actor,1,p);assert.deepEqual(trace,['random','visibility']);assert.equal(actor.nativePerceptionCounter580,1);
  trace.length=0;now.time=5200;p.pc=()=>1;await spawnHeartbeatPerception(actor,0,p);assert.deepEqual(trace,[]);
  await spawnHeartbeatPerception(actor,2,p);assert.deepEqual(trace,[]);
  await spawnHeartbeatPerception(actor,1,p);assert.deepEqual(trace,['random','visibility']);assert.equal(actor.nativePerceptionTime57c,5200);
});
test('perception AI0 counter throttles without advancing time or consuming random; exact 150 executes',async()=>{
  const {actor,trace,now,p}=fixture();actor.nativeAILevel7c=0;actor.nativePerceptionCounter580=148;now.time=5000;
  await spawnHeartbeatPerception(actor,1,p);assert.equal(actor.nativePerceptionCounter580,149);assert.equal(actor.nativePerceptionTime57c,1000);assert.deepEqual(trace,[]);
  await spawnHeartbeatPerception(actor,1,p);assert.deepEqual(trace,['random','visibility']);assert.equal(actor.nativePerceptionTime57c,5000);
});
test('spawn target gates initial heartbeat and visibility; native timer snapshot precedes spawn script',async()=>{
  const {actor,trace,now,p}=fixture();actor.nativeSpawnState548=0;actor.nativeField948=42;actor.nativeHeartbeatTime550=actor.nativePerceptionTime57c=0;now.time=200;
  p.activeTime=()=>({...now});p.runEvent=(o,type)=>{trace.push(['script',type]);if(type===8)now.time=9999;};
  await spawnHeartbeatPerception(actor,0,p);
  assert.deepEqual(trace,[['script',8],['script',0],'invitations','random','random','visibility']);
  assert.equal(actor.nativeSpawnState548,1);assert.equal(actor.nativeHeartbeatTime550,200);assert.equal(actor.nativePerceptionTime57c,200);
  const other=fixture();other.actor.nativeSpawnState548=0;other.actor.nativeHeartbeatTime550=other.actor.nativePerceptionTime57c=0;other.now.time=200;
  await spawnHeartbeatPerception(other.actor,0,other.p);assert.deepEqual(other.trace,[['script',8]]);assert.equal(other.actor.nativeSpawnState548,1);
});
test('zero last time skips first ordinary heartbeat/visibility but still advances caches and random',async()=>{
  const {actor,trace,now,p}=fixture();actor.nativeHeartbeatTime550=actor.nativePerceptionTime57c=0;now.time=7000;
  await spawnHeartbeatPerception(actor,1,p);assert.deepEqual(trace,['random','random']);assert.equal(actor.nativeHeartbeatInterval554,6101);
  assert.equal(actor.nativeHeartbeatTime550,7000);assert.equal(actor.nativePerceptionTime57c,7000);
});
test('heartbeat AI0 throttle uses unsigned interval>>6, still advances reputation counter',async()=>{
  const {actor,trace,now,p}=fixture();actor.nativeAILevel7c=0;actor.nativeHeartbeatCounter584=91;actor.nativeReputationCounter590=30;now.time=7000;
  await spawnHeartbeatPerception(actor,1,p);assert.deepEqual(trace,['reputations']);assert.equal(actor.nativeHeartbeatCounter584,92);assert.equal(actor.nativeHeartbeatTime550,1000);
  trace.length=0;await spawnHeartbeatPerception(actor,1,p);assert.deepEqual(trace,[['script',0],'invitations','random']);assert.equal(actor.nativeHeartbeatCounter584,0);assert.equal(actor.nativeReputationCounter590,2);
});
test('dead and dying skip heartbeat scripts but preserve refresh and perception order',async()=>{
  for(const field of ['dead','dying']){const {actor,trace,now,p}=fixture();now.time=7000;p[field]=()=>1;
    await spawnHeartbeatPerception(actor,1,p);assert.deepEqual(trace,['random','random','visibility']);}
});
test('controlled associate heartbeat respects native status script and domination priorities',async()=>{
  const {actor,trace,now,p}=fixture();now.time=7000;actor.masterId=42;actor.nativeField771=4;actor.associateType=6;
  await spawnHeartbeatPerception(actor,1,p);assert.deepEqual(trace,[['control',4],['control',7],'invitations','domination','random','random','visibility']);assert.equal(actor.nativeFieldEc,0);
  trace.length=0;actor.associateType=5;actor.nativeField771=0;actor.nativeHeartbeatInterval554=6000;actor.nativeHeartbeatTime550=1000;actor.nativePerceptionTime57c=7000;
  p.possessed=()=>1;await spawnHeartbeatPerception(actor,1,p);assert.deepEqual(trace,[['script',0],'invitations','domination','random']);
});
test('orphan henchman expiry uses 300000 remainder inclusive, while summoned associates queue native event11',async()=>{
  const {actor,trace,now,p}=fixture();actor.associateType=1;now.time=7000;
  await spawnHeartbeatPerception(actor,1,p);assert.equal(actor.nativeOrphanState918,1);assert.equal(actor.nativeOrphanTime920,7000);
  trace.length=0;now.time=307000;await spawnHeartbeatPerception(actor,1,p);
  assert.deepEqual(trace.slice(0,4),[['script',0],'invitations',['associate',0],['master',invalid]]);assert.equal(actor.nativeOrphanState918,0);
  trace.length=0;actor.associateType=3;actor.nativeHeartbeatTime550=1000;await spawnHeartbeatPerception(actor,1,p);
  assert.deepEqual(trace.slice(0,4),[['script',0],'invitations','clear',['event',11,actor.id,actor.id,0,null]]);
});
test('client automap follows visibility before perception timestamp and playerless area lowers AI level',async()=>{
  const {actor,trace,now,p,area}=fixture();now.time=5000;p.client=()=>({});area.nativePlayerCount150=0;
  p.updateAutoMap=()=>{trace.push(['automap',actor.nativePerceptionTime57c]);};
  await spawnHeartbeatPerception(actor,1,p);assert.deepEqual(trace,['random','visibility',['automap',1000],['level',0]]);
  assert.equal(actor.nativeAutoMapArea6e8,9);assert.equal(actor.nativeAutoMapTileX6e4,0);
});
test('heartbeat backwards subtraction retains native zero-initialized outputs and compares only day remainder',async()=>{
  const {actor,trace,now,p}=fixture();now.time=500;
  await spawnHeartbeatPerception(actor,1,p);assert.deepEqual(trace,[]);
  now.day=3;now.time=1000;await spawnHeartbeatPerception(actor,1,p);assert.deepEqual(trace,[]);
});
test('personal reputation cleanup removes missing objects and expires only strictly beyond f32 seconds threshold',async()=>{
  const {actor,now,p}=fixture();actor.personalReputationCapacity=16;actor.personalReputationList=[
    {objectId:1,decays:0},{objectId:2,decays:1,day:2,time:1000,duration:4},{objectId:3,decays:0}];
  p.creature=id=>id===1?null:{};now.time=5000;
  await cleanPersonalReputations(actor,p);assert.deepEqual(actor.personalReputationList.map(e=>e.objectId),[2,3]);
  now.time=5001;await cleanPersonalReputations(actor,p);assert.deepEqual(actor.personalReputationList.map(e=>e.objectId),[3]);assert.equal(actor.personalReputationCapacity,16);
});
test('invitation cleanup has separate strict 30/60 second thresholds and force affects outgoing only',async()=>{
  const {actor,now,p}=fixture(),target={};actor.nativeInvitationDay7e0=2;actor.nativeInvitationTime7e4=1000;
  actor.nativeInvitations7e8=[{objectId:2,day:2,time:1000}];actor.nativeInvitations7f0=[{objectId:2,day:2,time:1000}];
  const feedback=[];p.creature=()=>target;p.feedback=(...args)=>feedback.push(args);now.time=31000;
  await cleanInvitationLists(actor,0,p);assert.equal(actor.nativeInvitations7e8.length,1);assert.deepEqual(feedback,[]);
  await cleanInvitationLists(actor,1,p);assert.equal(actor.nativeInvitations7e8.length,0);assert.equal(actor.nativeInvitations7f0.length,1);
  assert.equal(target.nativeInvitationTime7e4,31000);assert.deepEqual(feedback,[[target,43,{objectIds:[actor.id]}]]);
  now.time=61000;await cleanInvitationLists(actor,0,p);assert.equal(actor.nativeInvitations7f0.length,1);
  now.time++;await cleanInvitationLists(actor,0,p);assert.equal(actor.nativeInvitations7f0.length,0);assert.equal(actor.nativeInvitationTime7e4,61000);
});
test('AI levels retain canonical IDs, duplicate guards, capacity and native lock/same-level/invalid priority',()=>{
  const master=new NativeAIMaster(),actor={id:0x80000002,nativeAILevel7c:-1,nativeAILocked80:0};
  assert.equal(master.setLevel(actor,1),1);assert.deepEqual([...master.levels[1].view()],[actor.id]);assert.equal(master.levels[1].capacity,16);
  master.setLevel(actor,1);assert.equal(master.levels[1].count,1);master.setLevel(actor,4);assert.equal(master.levels[1].count,0);assert.equal(master.levels[1].capacity,16);
  actor.nativeAILocked80=1;assert.equal(master.setLevel(actor,4),0);assert.equal(master.setLevel(actor,0),0);
  actor.nativeAILocked80=0;assert.equal(master.setLevel(actor,-1),0);actor.nativeAILevel7c=-1;assert.equal(master.setLevel(actor,-1),1);
});
test('canonical master alias makes perception react to associate ID changes and rejects conflicting cells',()=>{
  const session=new ModuleSession({});const actor=session.register('creature','actor',{masterId:0x80000003});
  assert.equal(actor.nativeStealthTarget8fc,actor.masterId);actor.masterId=6;assert.equal(actor.nativeStealthTarget8fc,6);
  actor.nativeStealthTarget8fc=0x80000004;assert.equal(actor.masterId,0x80000004);
  assert.throws(()=>session.register('creature','conflict',{masterId:1,nativeStealthTarget8fc:2}),/Conflicting/);
});
test('script SetAILevel clamps to0..3, locks after selection, and -1 restores area/combat/master priority',()=>{
  const {actor}=fixture(),master=new NativeAIMaster(),area={nativePlayerCount150:1};
  actor.isPC=false;actor.stats={};const p={master,area:()=>area,possessed:()=>0,creature:()=>({stats:{},isPC:true})};
  scriptSetAILevel(actor,4,p);assert.equal(actor.nativeAILevel7c,3);assert.equal(actor.nativeAILocked80,1);
  scriptSetAILevel(actor,-9,p);assert.equal(actor.nativeAILevel7c,0);assert.equal(actor.nativeAILocked80,1);
  scriptSetAILevel(actor,-1,p);assert.equal(actor.nativeAILevel7c,1);assert.equal(actor.nativeAILocked80,0);
  area.nativePlayerCount150=0;scriptSetAILevel(actor,-1,p);assert.equal(actor.nativeAILevel7c,0);
  actor.nativeField700=1;scriptSetAILevel(actor,-1,p);assert.equal(actor.nativeAILevel7c,2);
  actor.masterId=4;scriptSetAILevel(actor,-1,p);assert.equal(actor.nativeAILevel7c,3);
  p.creature=()=>null;scriptSetAILevel(actor,-1,p);assert.equal(actor.nativeAILevel7c,3);assert.equal(actor.nativeAILocked80,0);
  actor.nativeAILocked80=1;actor.isPC=true;scriptSetAILevel(actor,-1,p);assert.equal(actor.nativeAILocked80,1);
  scriptSetAILevel(actor,-1,{master:null});assert.equal(actor.nativeAILocked80,0);
});
test('live runtime heartbeat invokes authored spawn before native RNG/perception and uses shared AI level storage',async()=>{
  const session=new ModuleSession({}),area=session.register('area','area',{nativePlayerCount150:1});
  const actor=session.register('creature','actor',{areaId:area.id,position:[0,0,0],registerAI:true,scripts:{spawn:'spawn',heartbeat:'beat'},stats:{},combatRound:{}});
  const trace=[];session.damage.runEvent=(o,name)=>{trace.push(name);session.commands.SetAILevel([o.id,4]);};
  session.worldTimer.setTime(2,4000);const time=session.worldTimer.time();
  actor.nativePerceptionDay578=2;actor.nativePerceptionTime57c=0;
  await session.combat.updateSpawnHeartbeat(actor,1,{updateVisibility:()=>trace.push('visible'),random:()=>{trace.push('rand');return 55;}});
  assert.deepEqual(trace,['spawn','rand']);assert.equal(actor.nativeAILevel7c,3);assert.equal(actor.nativeAILocked80,1);
  assert.equal(session.commands.GetAILevel([actor.id]),3);assert.equal(actor.nativePerceptionTime57c,time.time);
  session.worldTimer.setTime(2,8000);await session.combat.updateSpawnHeartbeat(actor,1,{updateVisibility:()=>trace.push('visible'),random:()=>{trace.push('rand');return 55;}});
  assert.deepEqual(trace,['spawn','rand','rand','rand','visible']);
});
