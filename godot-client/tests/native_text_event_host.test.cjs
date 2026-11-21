'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {createRequire}=require('node:module');
const hostPath=path.resolve(__dirname,'../tools/native-session-host.cjs'),source=fs.readFileSync(hostPath,'utf8');
const first="if(current!==session||connection!==lobby.connection||ending)return;",last="if(message.kind==='object-updates'){const frame=rawCombat.frame";
const start=source.indexOf(first),end=source.indexOf(last,start);
if(start<0||end<start||source.indexOf(first,start+1)>=0)throw Error('Exact current Host text-event anchors changed');
const fragment=source.slice(start,end),hash=value=>crypto.createHash('sha256').update(value).digest('hex');
const dispatch=new Function('current','session','connection','lobby','ending','message','areaGeneration','nativeTextEvents','rawVoice','rawScriptSounds','rawVisual','guiPanelEventForHost','send','report',fragment);
const ownerLine=source.split(/\r?\n/).find(line=>line.startsWith('const nativeTextEvents='));
if(!ownerLine)throw Error('Actual Host native text owner missing');
const instantiate=new Function('require','rawCombat',ownerLine+'return nativeTextEvents;');

async function harness(){
 const {RawCombatEvents}=require('../tools/raw-combat-events.cjs');
 const {GameObjectArray}=await import('../../src/game_object_array.js');
 const {EntityDisclosureLifetimes}=await import('../../src/network_entity_lifetimes.js');
 const identities=new RawCombatEvents(),registry=new GameObjectArray({clientMode:true}),world={areaId:7,registry,entityDisclosures:new EntityDisclosureLifetimes()};
 const object={objectType:5,areaId:7,replicationRemoved:false};assert.equal(registry.addObjectAtPos(0x80000013,object).status,0);
 const current={world},session=current,lobby={connection:3},raw={frame(){return null;}},sent=[],report={};
 const actual=instantiate(createRequire(hostPath),identities);let captures=0;
 const metadata={capture(...args){captures++;return actual.capture(...args);}};
 return {world,registry,identities,object,current,session,lobby,sent,report,metadata,get captures(){return captures;},run(message,overrides={}){return dispatch(overrides.current??current,overrides.session??session,overrides.connection??3,lobby,overrides.ending??false,message,2,overrides.metadata??metadata,raw,raw,raw,()=>null,value=>sent.push(value),report);}};
}

test('actual Host accepted guard prevents stale-session/connection/ending from any metadata capture',async()=>{
 const h=await harness(),speech={kind:'server-speech',objectId:h.object.id,channel:1,text:{text:'Received'}};
 for(const stale of [{session:{}},{connection:2},{ending:true}])h.run(speech,stale);
 assert.equal(h.captures,0);assert.deepEqual(h.sent,[]);assert.deepEqual(h.report,{});
});

test('actual Host preserves all75 original decoded packet fields and echoes actual source lifetime scope',async t=>{
 const h=await harness(),{decodeServerGameMessage}=await import('../../src/network_game_messages.js');
 const a=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../../backups/animations/native-network-chat-writer-observations.json'))),b=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../../backups/animations/native-network-speech-observations.json')));
 const packets=a.cases.filter(r=>r.case.format===1).flatMap(r=>r.packets).concat(b.cases.filter(r=>r.case.format===1).map(r=>r.packet));
 assert.equal(packets.length,75);
 for(const hex of packets){
  const message=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17}}),before=structuredClone(message),count=h.sent.length;
  h.run(message);assert.equal(h.sent.length,count+1);assert.deepEqual(message,before);
  const sent=JSON.parse(JSON.stringify(h.sent.at(-1))),metadata=sent.message.nativeTextEvent;delete sent.message.nativeTextEvent;
  assert.deepEqual(sent,{kind:'ui-protocol',generation:2,message:before});
  assert.equal(metadata.connection,3);assert.equal(metadata.generation,2);assert.equal(metadata.areaId,7);
  if(message.objectId===h.object.id){const raw=h.world.entityDisclosures.transportRow(h.object,h.identities.object(h.object));assert.equal(metadata.source.id,raw.id);assert.equal(metadata.source.nativeLifetime,raw.nativeLifetime);assert.equal(metadata.source.knownLifetime,raw.clientKnownLifetime);}else assert.equal(metadata.source,null);
 }
 assert.equal(h.captures,75);assert.deepEqual(h.report,{});
 t.diagnostic(JSON.stringify({hostSha256:hash(source),fragmentSha256:hash(fragment),firstLine:source.slice(0,start).split('\n').length,lastLine:source.slice(0,end).split('\n').length,scope:'Exact bounded current Host accepted event dispatch plus actual metadata owner/decoder; controlled canonical World and send only, no Host startup/socket/engine/server.'}));
});

test('actual Host adds no channel policy; script floating remains distinct and other forwarded messages stay unchanged',async()=>{
 const h=await harness();
 for(const channel of [1,2,3,4,5,6,8,9,10,11,12,14,15,17,18,19,20,22,30]){
  const message={kind:'server-speech',channel,objectId:h.object.id,text:{text:'Actually received'}};h.run(message);assert.equal(h.sent.at(-1).message.nativeTextEvent.source.id,h.object.id);
 }
 for(const type of [93,94]){const message={kind:'combat-feedback',type,data:{objects:{0:h.object.id},integers:{0:0},strings:{0:{text:'Script received'}}}};h.run(message);assert.equal(h.sent.at(-1).message.nativeTextEvent.source.id,h.object.id);assert.equal(h.sent.at(-1).message.type,type);}
 for(const kind of ['spell-feedback','damage-feedback','attack-feedback','initiative-feedback','dialog-entry','tlk-overrides','inventory-ack','level-up-result']){const message={kind,authoredSentinel:[1,2,3]};h.run(message);assert.equal(h.sent.at(-1).message,message);assert.equal(h.sent.at(-1).message.nativeTextEvent,undefined);}
 const ordinaryFeedback={kind:'combat-feedback',type:92,data:{}};h.run(ordinaryFeedback);assert.equal(h.sent.at(-1).message,ordinaryFeedback);
 const before=h.sent.length;h.run({kind:'item-text-bubble-override',itemId:h.object.id,mode:1,text:'Caption'});assert.equal(h.sent.length,before);
});

test('capture exception preserves original log packet and emits only a bounded generic counter',async()=>{
 const h=await harness(),message={kind:'server-speech',channel:1,objectId:h.object.id,text:{text:'Do not discard'}},metadata={capture(){throw Error('PRIVATE_ERROR_SENTINEL');}};
 h.run(message,{metadata});assert.equal(h.sent.at(-1).message,message);assert.deepEqual(h.report,{nativeTextEventCaptureFailures:1});
 h.report.nativeTextEventCaptureFailures=65535;h.run(message,{metadata});assert.equal(h.report.nativeTextEventCaptureFailures,65535);assert.equal(JSON.stringify(h.sent).includes('PRIVATE_ERROR_SENTINEL'),false);assert.equal(JSON.stringify(h.report).includes('PRIVATE_ERROR_SENTINEL'),false);
});
