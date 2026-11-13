import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {EventEmitter} from 'node:events';
import {NetworkGameSession} from '../../electron/network_game_session.mjs';
import {NativeMessageWriter} from '../../src/native_message.js';
import {decodeServerGameMessage} from '../../src/network_game_messages.js';
import bridgeModule from './native-clock-bridge.cjs';
import combatModule from './raw-combat-events.cjs';

const {NativeClockBridge}=bridgeModule,{RawCombatEvents}=combatModule;
const here=fileURLToPath(import.meta.url),workspace=path.resolve(path.dirname(here),'../..');
const ID=0x80000042,OTHER=0x80000043,AREA=0x80000001,AREA2=0x80000002,INVALID=0x7f000000;
const BUILD={number:8193,revision:37,postfix:17};
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const detached=value=>JSON.parse(JSON.stringify(value));
function sourcePins(){
 const queue=[here,path.join(workspace,'package.json')],seen=new Set(),rows=[];
 const pattern=/(?:\bfrom\s*|\bimport\s*(?:\(\s*)?|\brequire\s*\(\s*)["'](\.[^"']+)["']/g;
 while(queue.length){
  const file=path.resolve(queue.shift());if(seen.has(file))continue;seen.add(file);
  if(!file.startsWith(workspace+path.sep))throw Error('Fixture source dependency escaped workspace');
  const bytes=fs.readFileSync(file);rows.push({path:path.relative(workspace,file).replaceAll('\\','/'),sha256:hash(bytes)});
  if(!/\.[cm]?js$/.test(file))continue;
  for(const match of bytes.toString('utf8').matchAll(pattern))queue.push(path.resolve(path.dirname(file),match[1]));
 }
 return rows.sort((a,b)=>a.path.localeCompare(b.path));
}
const A=(id,areaId)=>({action:'create',objectType:5,id,state:{areaId,position:[2,3,0],orientation:[1,0,0]}});
const P=id=>({action:'appearance',objectType:5,id,mask:0x400,state:{name:{text:'Authored unknown owner'}}});
const D=()=>({action:'delete',objectType:5,id:ID,remove:1});
const objects=records=>({kind:'object-updates',records,complete:true});
const moduleInfo=()=>({kind:'module-info',module:{minutesPerHour:5}});
const clientArea=id=>({kind:'client-area',area:{id,mapPins:[],sounds:[],placeableLights:[],staticPlaceables:[],time:{},tiles:[]},loadingScreen:0,position:[2,3,0],facing:0,flag:0});
function pausePacket(){
 const ids=[ID,ID,INVALID],writer=new NativeMessageWriter(1);
 writer.create(2+ids.length*4,0xffffffff,1);writer.writeByte(2,2,1);writer.writeBool(1);writer.writeWord(ids.length,16);
 for(const id of ids)writer.writeObjectIdClient(id);
 writer.setPrefix(Uint8Array.of(80,3,9));return Uint8Array.from(writer.getWriteMessage().data);
}
function makeSession(){
 const peer=new EventEmitter(),sent=[],diagnostics=[];
 peer.sendGameMessage=async value=>{sent.push(Array.from(value));throw Error('Runtime fixture must not send a gameplay command');};
 peer.connect=async()=>{throw Error('Runtime fixture must not connect');};
 peer.disconnect=async()=>peer.emit('closed');
 const session=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:BUILD,dispose(){}},resources:{close(){},findFile(){throw Error('Runtime fixture must not load resources');}},language:0,
  openModule:async()=>{throw Error('Runtime fixture must not open assets');},
  decodeMessage:(value,options)=>value instanceof Uint8Array?decodeServerGameMessage(value,options):value,
  onDiagnostic:value=>diagnostics.push(detached(value))});
 return {session,peer,sent,diagnostics,async deliver(message){peer.emit('message',message);await session.delivery;assert.equal(session.closed,false,'Authored accepted fixture must not close');}};
}

// Read-only source fixture. It exports transport/provenance records and actual
// existing raw identities only, never clock simulation or model/scene data.
export async function nativeClockRuntimeFixture(){
 const sourcePinsBefore=sourcePins(),frames=[],encoded=[],batches=[],raw=new RawCombatEvents();
 const first=makeSession(),second=makeSession();let current=first.session,connection=3;
 const bridge=new NativeClockBridge({isCurrent:(session,value)=>session===current&&value===connection,send(frame,line){frames.push(detached(frame));encoded.push(line);return {status:'accepted',backpressure:false};}});
 function clockContext(session){return {ready:true,connection:session.world.nativeClockLifecycleHistory().connection,generation:session.areaGeneration,areaId:session.world.areaId};}
 function anchorFromRow(session,row){
  if(row===null)return null;
  const context=clockContext(session),witness=Number.isSafeInteger(row.nativeLifetime)&&row.nativeLifetime>0&&Number.isSafeInteger(row.clientKnownLifetime)&&row.clientKnownLifetime>0?[row.id,row.nativeLifetime,row.clientKnownLifetime]:[];
  const where=[context.connection,context.generation,context.areaId];
  return {row:detached(row),witness,where,context,currentAnchor:witness.length===3&&row.objectType===5&&row.areaId===context.areaId};
 }
 function anchor(session,id=ID){
  const object=session.world.registry.get(id);if(!object)return null;
  const row=session.world.entityDisclosures.transportRow(object,{...raw.object(object),nativeClockOwner:session.world.nativeClockOwnerTransport(object)});
  return anchorFromRow(session,row);
 }
 function record(label,start,session,{rawAvailable=true,expected={},anchorValue=undefined,...extra}={}){
  const value={label,connection:session.world.nativeClockLifecycleHistory().connection,generation:session.areaGeneration,areaId:session.world.areaId,frames:detached(frames.slice(start)),rawAvailable,anchor:anchorValue===undefined?(rawAvailable?anchor(session):null):anchorValue,expected,...extra};
  batches.push(detached(value));return batches.at(-1);
 }
 async function delivered(label,session,message,options={}){const start=frames.length;await (session===first.session?first:second).deliver(message);return record(label,start,session,options);}
 try{
  let start=frames.length;assert.equal(bridge.attach(first.session,3).attached,true);
  record('begin',start,first.session,{rawAvailable:false,expected:{eventTypes:['begin'],processTimerConstruction:false}});
  const staleFirstHandler=first.session.listeners('message')[0];assert.equal(typeof staleFirstHandler,'function');
  await delivered('moduleInfo',first.session,moduleInfo(),{rawAvailable:false,expected:{eventTypes:['module-info'],minutesPerHour:5}});
  const fresh=await delivered('freshA',first.session,objects([A(ID,AREA)]),{rawAvailable:false,expected:{eventTypes:['accepted-lifecycle'],constructionCertified:true,beforeClientArea:true,beforeDelayedRaw:true}});
  fresh.capturedAnchor=anchor(first.session);assert.equal(fresh.areaId,INVALID);assert.equal(fresh.generation,0);assert.equal(fresh.anchor,null);assert.equal(fresh.capturedAnchor.currentAnchor,false);
  const capturedFreshRow=detached(fresh.capturedAnchor.row),firstPhysical=capturedFreshRow.nativeClockOwner.physicalToken;
  await delivered('clientArea',first.session,clientArea(AREA),{rawAvailable:false,expected:{eventTypes:['client-area'],beforeDelayedRaw:true}});
  const repeated=await delivered('repeatedA',first.session,objects([A(ID,AREA)]),{rawAvailable:false,expected:{eventTypes:['accepted-lifecycle'],constructionCertified:false,samePhysical:true,beforeDelayedRaw:true}});
  assert.equal(repeated.frames[0].event.physicalToken,firstPhysical);
  const delayed=record('delayedRaw',frames.length,first.session,{rawAvailable:true,anchorValue:anchorFromRow(first.session,capturedFreshRow),expected:{eventTypes:[],publishCapturedFreshRowUnchanged:true,currentAnchor:true}});
  assert.deepEqual(delayed.anchor.row,fresh.capturedAnchor.row);assert.equal(delayed.anchor.currentAnchor,true);
  await delivered('control',first.session,{kind:'object-control',major:5,minor:2,playerId:1,objectId:ID},{expected:{eventTypes:['object-control'],noConstruction:true}});
  const unknown=await delivered('unknownOther',first.session,objects([P(OTHER),A(OTHER,AREA)]),{expected:{eventTypes:['accepted-lifecycle'],otherConstructionCertified:false,recordHistoryComplete:true,actorStillCurrent:true}});
  unknown.otherAnchor=anchor(first.session,OTHER);assert.equal(unknown.anchor.row.nativeClockOwner.physicalToken,firstPhysical);assert.equal(unknown.otherAnchor.row.nativeClockOwner.physicalCurrent,false);
  const transfer=await delivered('areaTransfer',first.session,clientArea(AREA2),{expected:{eventTypes:['client-area'],samePhysical:true,areaChanged:true,currentAnchor:true}});
  assert.equal(transfer.anchor.row.nativeClockOwner.physicalToken,firstPhysical);assert.equal(transfer.anchor.currentAnchor,true);assert.equal(transfer.anchor.row.areaId,AREA2);
  const removal=await delivered('removal',first.session,objects([D()]),{expected:{eventTypes:['accepted-lifecycle'],operation:'remove',physicalCurrent:false,currentAnchor:false,hardDestructionCertified:false}});
  assert.deepEqual(removal.anchor.witness,[]);assert.equal(removal.anchor.row.nativeClockOwner.physicalToken,null);assert.equal(removal.anchor.row.clientKnownLifetime,null);
  const ambiguous=await delivered('ambiguousA',first.session,objects([A(ID,AREA2)]),{expected:{eventTypes:['accepted-lifecycle'],ownership:'unknown',constructionCertified:false,physicalCurrent:false,currentAnchor:true}});
  assert.equal(ambiguous.anchor.currentAnchor,true);assert.equal(ambiguous.anchor.row.nativeClockOwner.physicalToken,null);assert.equal(ambiguous.anchor.row.nativeLifetime,capturedFreshRow.nativeLifetime);assert.notEqual(ambiguous.anchor.row.clientKnownLifetime,capturedFreshRow.clientKnownLifetime);
  current=second.session;connection=4;start=frames.length;
  assert.equal(bridge.attach(second.session,4).attached,true);
  record('reconnectBegin',start,second.session,{rawAvailable:false,expected:{eventTypes:['begin'],runtimeCleanupBefore:true,newConnection:true,newRegistryEpoch:true,processTimerConstruction:false}});
  await delivered('reconnectModuleInfo',second.session,moduleInfo(),{rawAvailable:false,expected:{eventTypes:['module-info'],minutesPerHour:5}});
  await delivered('reconnectClientArea',second.session,clientArea(AREA2),{rawAvailable:false,expected:{eventTypes:['client-area']}});
  const reconnect=await delivered('reconnectFreshA',second.session,objects([A(ID,AREA2)]),{expected:{eventTypes:['accepted-lifecycle'],constructionCertified:true,newPhysical:true,currentAnchor:true}});
  assert.notEqual(reconnect.anchor.row.nativeClockOwner.epoch,capturedFreshRow.nativeClockOwner.epoch);assert.notEqual(reconnect.anchor.row.nativeClockOwner.physicalToken,firstPhysical);assert.notEqual(reconnect.anchor.row.nativeLifetime,capturedFreshRow.nativeLifetime);
  start=frames.length;
  const oldMessage=moduleInfo();oldMessage.module.minutesPerHour=8;
  staleFirstHandler({message:oldMessage,areaGeneration:first.session.areaGeneration});await first.deliver(oldMessage);
  record('staleOldCallback',start,second.session,{expected:{eventTypes:[],staleCallbackDropped:true}});assert.equal(frames.length,start);
  const pauseBytes=pausePacket();const unsupported=await delivered('unsupportedPause',second.session,pauseBytes,{expected:{eventTypes:['module-pause-state'],runtimeSupported:false,reason:'Exact native pause lower callbacks deliberately unavailable; no callback parity claimed'}});
  assert.deepEqual(unsupported.frames[0].event,{type:'module-pause-state',mask:2,value:1,exclusionIds:[ID,ID,INVALID]});
  for(let index=0;index<frames.length;index++)assert.deepEqual(JSON.parse(encoded[index]),frames[index]);
  for(const activeConnection of [3,4])assert.deepEqual(frames.filter(frame=>frame.connection===activeConnection).map(frame=>frame.serial),Array.from({length:frames.filter(frame=>frame.connection===activeConnection).length},(_,index)=>index+1));
  assert.equal(batches.at(-1).label,'unsupportedPause');assert.ok(frames.every(frame=>frame.history.complete));
  assert.deepEqual(first.sent,[]);assert.deepEqual(second.sent,[]);assert.deepEqual(first.diagnostics,[]);assert.deepEqual(second.diagnostics,[]);
  const sourcePinsAfter=sourcePins();assert.deepEqual(sourcePinsAfter,sourcePinsBefore,'Fixture source pins changed');
  const output={version:1,source:'native-clock-runtime-fixture-v1',ids:{actor:ID,other:OTHER,area:AREA,area2:AREA2,invalid:INVALID},
   provenance:{authoredServerDTOs:true,actualSessionWorldBridge:true,actualRawCombatAndDisclosureOwners:true,actualNativePauseWriterDecoder:true,originalServer:false,network:false,resources:false,clockSimulation:false,rendererPreparation:false,sourcePinsBefore,sourcePinsAfter},
   batches,checks:{batchLabels:batches.map(batch=>batch.label),batchCount:batches.length,frameCount:frames.length,allTransportHistoryComplete:true,pauseIsLast:true,delayedRawRowUnchanged:true,oldCallbacksProduceNoFrames:true,sourcePinsUnchanged:true,sourcePinCount:sourcePinsBefore.length},
   bridge:bridge.snapshot(),pausePacket:{bytes:Array.from(pauseBytes),sha256:hash(pauseBytes),provenance:'Authored via actual native writer/decoder; not original captured server bytes'}};
  return detached(output);
 }finally{bridge.retire(current,connection);first.session.finish();second.session.finish();}
}

async function cli(){
 const args=process.argv.slice(2);if(args.length!==2||args[0]!=='--output')throw Error('Usage: node godot-client/tools/native-clock-runtime-fixture.mjs --output <fresh .json under godot-client/.cache>');
 const cache=path.join(workspace,'godot-client/.cache'),output=path.resolve(args[1]);
 if(!output.startsWith(cache+path.sep)||path.extname(output)!=='.json')throw Error('Fixture output must be a fresh JSON file under godot-client/.cache');
 let ancestor=path.dirname(output);while(!fs.existsSync(ancestor))ancestor=path.dirname(ancestor);
 const realAncestor=fs.realpathSync(ancestor),realWorkspace=fs.realpathSync(workspace);
 if(realAncestor!==realWorkspace&&!realAncestor.startsWith(realWorkspace+path.sep))throw Error('Fixture output ancestor escapes workspace');
 if(fs.existsSync(output))throw Error('Refusing to overwrite existing fixture');
 const fixture=await nativeClockRuntimeFixture(),bytes=Buffer.from(JSON.stringify(fixture,null,2)+'\n');
 fs.mkdirSync(path.dirname(output),{recursive:true});const fd=fs.openSync(output,'wx');try{fs.writeFileSync(fd,bytes);}finally{fs.closeSync(fd);}
 console.log(JSON.stringify({output:path.relative(workspace,output).replaceAll('\\','/'),sha256:hash(bytes),batches:fixture.checks.batchCount,frames:fixture.checks.frameCount,sourcePins:fixture.checks.sourcePinCount,checks:fixture.checks}));
}
if(process.argv[1]&&path.resolve(process.argv[1])===here)await cli();
