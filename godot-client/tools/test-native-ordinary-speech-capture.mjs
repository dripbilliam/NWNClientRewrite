import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import {NativeMessageWriter} from '../../src/native_message.js';
import {scriptStringBytes} from '../../src/script_string.js';
import {decodeServerGameMessage} from '../../src/network_game_messages.js';
import {GameObjectArray} from '../../src/game_object_array.js';
import {EntityDisclosureLifetimes} from '../../src/network_entity_lifetimes.js';
const require=createRequire(import.meta.url),{OrdinarySpeechCapture,MARKERS}=require('./native-ordinary-speech-capture.cjs'),{RawCombatEvents}=require('./raw-combat-events.cjs'),{NativeTextEventScope}=require('./native-text-event-scope.cjs');
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),source=fs.readFileSync(path.join(project,'tools/native-session-host.cjs'),'utf8'),start=source.indexOf('if(current!==session||connection!==lobby.connection||ending)return;'),end=source.indexOf("if(message.kind==='object-updates'){const frame=rawCombat.frame",start),fragment=source.slice(start,end);
assert(start>=0&&end>start);const dispatch=new Function('current','session','connection','lobby','ending','message','areaGeneration','nativeTextEvents','rawVoice','rawScriptSounds','rawVisual','guiPanelEventForHost','send','report',fragment);
let checks=0;function check(fn){fn();checks++;}
function setup(){const identities=new RawCombatEvents(),registry=new GameObjectArray({clientMode:true}),actor={objectType:5,areaId:7,replicationRemoved:false};assert.equal(registry.addObjectAtPos(0xffffffff,actor).status,0);const session={phase:'playing',closed:false,peer:{closed:false},areaGeneration:2,serverBuild:{number:8193,revision:37,postfix:17},world:{areaId:7,localObjectId:actor.id,registry,entityDisclosures:new EntityDisclosureLifetimes()}},capture=new OrdinarySpeechCapture(decodeServerGameMessage,identities),nativeTextEvents=new NativeTextEventScope(identities),observed={kind:'observed',connection:3,generation:2,areaId:7,nativeProcessId:123,state:{ready:true,admission_ready:true,object_visuals_complete:true,pending_batches:0,entities:1,hidden:0,desired:1,generation:2,area_id:7,controlled_id:actor.id}};capture.ready(session,3,observed);capture.arm(session,3);return{session,capture,nativeTextEvents,actor};}
function speech(text,channel=1){const w=new NativeMessageWriter(1);w.create(128,0xffffffff,1);w.writeObjectIdClient(0xffffffff);const bytes=scriptStringBytes(text);w.writeCExoString({bytes,length:bytes.length});w.setPrefix(Uint8Array.of(80,9,channel));return Buffer.from(w.getWriteMessage().data);}
function deliver(s,bytes,{connection=3,ending=false}={}){s.capture.packet(s.session,connection,bytes);const message=decodeServerGameMessage(bytes,{serverBuild:s.session.serverBuild}),before=structuredClone(message),frames=[],empty={frame(){return null}},report={};dispatch(s.session,s.session,connection,{connection:3},ending,message,2,s.nativeTextEvents,empty,empty,empty,()=>null,f=>{frames.push(f);s.capture.delivered(f,s.session,3)},report);assert.deepEqual(message,before);assert.deepEqual(report,{});return frames;}
const live=setup(),original=JSON.parse(fs.readFileSync(path.join(project,'reports/native-script-floating-original-server-packets-v3.json')));
for(const packet of original.packets)deliver(live,Buffer.from(packet.hex,'hex'));
for(const text of MARKERS){live.capture.command({kind:'chat',channel:1,text,generation:2,areaId:7},live.session,3);check(()=>assert.equal(deliver(live,speech(text)).length,1));}
const popupDefaults=()=>({mode:2,largeFont:true}),popupClock=()=>({delegated:true,sharedRecord:true,registryTracked:true,registered:true});
const native={success:true,checks:16,failures:[],scope:live.capture.scope,source:live.capture.source,ordinarySpeech:{success:true,checks:15,failures:[],freshPopupPreferences:Object.fromEntries(['stored','gameplay','owner','registry'].map(key=>[key,popupDefaults()])),scope:live.capture.scope,source:live.capture.source,first:{serial:live.capture.speechDeliveries[0].metadata.serial,mode:2,font:'ttf fnt_default_hr 16',clock:popupClock()},replacement:{serial:live.capture.speechDeliveries[1].metadata.serial,mode:2,font:'ttf fnt_default_hr 16',clock:popupClock()}}};
check(()=>assert(live.capture.finish(native).success));
check(()=>assert.equal(Object.keys(live.capture.finish(native).checks).length,10));
check(()=>assert.equal(live.capture.finish(native).ordinarySpeechProof.checks.inheritedChecksPreserved,true));
check(()=>assert.equal(live.capture.nativeExit({success:true,playable:true,object_visuals_complete:true,environment_accepted:true,workers_remaining:0,protocol_finish_ack:true,world:{ready:true,generation:2,area_id:7,controlled_id:0xffffffff},gameplay_success:false},true).success,true));
check(()=>assert.equal(Object.keys(live.capture.nativeExit({},false).checks).length,9));
const dto=live.capture.finish(native);dto.ordinarySpeechProof.deliveries[0].metadata.source.nativeLifetime=999;check(()=>assert.notEqual(live.capture.speechDeliveries[0].metadata.source.nativeLifetime,999));
check(()=>assert.equal(live.capture.finish({...native,success:false}).success,false));
check(()=>assert.equal(live.capture.finish({...native,checks:15}).success,false));
check(()=>assert.equal(live.capture.finish({...native,ordinarySpeech:{...native.ordinarySpeech,first:{serial:999}}}).success,false));
for(const mutate of [value=>{value.checks=13},value=>{value.freshPopupPreferences.stored.mode=1},value=>{value.freshPopupPreferences.owner.largeFont=false},value=>{value.first.font='ttf fnt_default 14'},value=>{value.replacement.mode=1},value=>{value.first.clock.sharedRecord=false},value=>{value.replacement.clock.delegated=false},value=>{value.replacement.clock.registryTracked=false}]){
 const wrongNative=structuredClone(native);mutate(wrongNative.ordinarySpeech);check(()=>assert.equal(live.capture.finish(wrongNative).success,false));
}
const stale=setup();check(()=>assert.throws(()=>stale.capture.command({kind:'chat',channel:1,text:MARKERS[0],generation:1,areaId:7},stale.session,3)));
check(()=>assert.throws(()=>stale.capture.command({kind:'chat',channel:2,text:MARKERS[0],generation:2,areaId:7},stale.session,3)));
check(()=>assert.throws(()=>stale.capture.command({kind:'chat',channel:1,text:MARKERS[1],generation:2,areaId:7},stale.session,3)));
const reuse=setup();reuse.actor.replicationRemoved=true;check(()=>assert.throws(()=>reuse.capture.command({kind:'chat',channel:1,text:MARKERS[0],generation:2,areaId:7},reuse.session,3)));
const wrong=setup();deliver(wrong,speech(MARKERS[0]),{connection:2});check(()=>assert.equal(wrong.capture.speechDeliveries.length,0));check(()=>assert.notEqual(wrong.capture.speechFailure,null));
const duplicate=setup();deliver(duplicate,speech(MARKERS[0]));deliver(duplicate,speech(MARKERS[0]));check(()=>assert.notEqual(duplicate.capture.speechFailure,null));
const unrelated=setup();deliver(unrelated,speech('unrelated local fixture'));check(()=>assert.equal(unrelated.capture.speechPackets.length,0));check(()=>assert.equal(unrelated.capture.speechDeliveries.length,0));
const ended=setup();const frames=deliver(ended,speech(MARKERS[0]),{ending:true});check(()=>assert.equal(frames.length,0));
check(()=>assert(source.includes("if(ordinarySpeechCheck&&!scriptFloatingCheck)throw Error('Ordinary speech requires the composed ScriptFloating check')")));
check(()=>assert.equal(fs.readFileSync(path.join(project,'tools/native-session-bootstrap.cjs'),'utf8').includes("'--script-floating-check'].some"),true));
const liveWrapper=fs.readFileSync(path.join(project,'tools/test-native-ordinary-speech-live.ps1'),'utf8');
check(()=>assert(liveWrapper.includes("@('.layout.cfg','.settings.cfg','.lobby.cfg')")&&liveWrapper.includes('Fresh popup-default check requires absent run-specific preferences; existing file preserved')));
check(()=>assert(liveWrapper.includes('-OrdinarySpeechCheck -ScriptFloatingDirectory $floatingHome -Headless -EngineRuntime editor -LocalOnly')&&liveWrapper.includes("$_.ProcessId-eq7568")&&liveWrapper.includes('ProcessId -eq 25060')));
const hash=f=>crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex'),label=process.argv[2];if(!/^[a-z0-9-]{3,90}$/.test(label??''))throw Error('Unique pure evidence label required');const directory=path.join(project,'.cache/ordinary-speech',label);fs.mkdirSync(directory,{recursive:false});
const proof={success:true,checks,hostSha256:hash(path.join(project,'tools/native-session-host.cjs')),hostFragmentSha256:crypto.createHash('sha256').update(fragment).digest('hex'),captureSha256:hash(path.join(project,'tools/native-ordinary-speech-capture.cjs')),originalPacketFixture:{path:'reports/native-script-floating-original-server-packets-v3.json',sha256:hash(path.join(project,'reports/native-script-floating-original-server-packets-v3.json'))},scope:'Pure Node: authored canonical session and ordinary codec bytes through actual decoder/bounded Host fragment. Retained prior original ScriptFloating packets exercise inherited10/9; authored native DTO only tests the gate, never live authority.',engines:0,serverConnections:0,keyReads:0,gpu:false};fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(proof));
