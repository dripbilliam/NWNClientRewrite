// Receiver-trace -> authored codec bytes -> actual decoder -> bounded actual
// Host ingress. These bytes are NOT a retained original native writer capture.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {isDeepStrictEqual} from 'node:util';
import {NativeMessageWriter} from '../../src/native_message.js';
import {scriptStringBytes} from '../../src/script_string.js';
import {decodeServerGameMessage} from '../../src/network_game_messages.js';
import {GameObjectArray} from '../../src/game_object_array.js';
import {EntityDisclosureLifetimes} from '../../src/network_entity_lifetimes.js';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project);
const digest=value=>crypto.createHash('sha256').update(value).digest('hex');
export const SCRIPT_FLOATING_TARGET_STATES=Object.freeze(['known-unrendered','missing','removed','other-area','noncreature','unknown-area']);
export function receivedScriptFloatingFixture({targetState='known-unrendered',disclosure='initial',worldAreaAvailable=true}={}){
 if(!SCRIPT_FLOATING_TARGET_STATES.includes(targetState))throw Error('Explicit ScriptFloating fixture target state required');
 if(typeof worldAreaAvailable!=='boolean')throw Error('Explicit world area availability required');
 if(!['initial','redisclosed'].includes(disclosure)||disclosure!=='initial'&&targetState!=='known-unrendered')throw Error('Explicit known-target disclosure transition required');
 const hostPath=path.join(project,'tools/native-session-host.cjs'),source=fs.readFileSync(hostPath,'utf8');
 const first='if(current!==session||connection!==lobby.connection||ending)return;',last="if(message.kind==='object-updates'){const frame=rawCombat.frame",start=source.indexOf(first),end=source.indexOf(last,start);
 if(start<0||end<start||source.indexOf(first,start+1)>=0)throw Error('Current bounded Host text dispatch anchors changed');
 const fragment=source.slice(start,end),dispatch=new Function('current','session','connection','lobby','ending','message','areaGeneration','nativeTextEvents','rawTileVisibility','rawCreatureVisibilityPermission','rawVoice','rawScriptSounds','rawVisual','guiPanelEventForHost','send','report',fragment);
 const ownerLine=source.split(/\r?\n/).find(line=>line.startsWith('const nativeTextEvents='));
 if(!ownerLine)throw Error('Current actual Host text owner missing');
 const require=createRequire(hostPath),identities=new (require('./raw-combat-events.cjs').RawCombatEvents)();
 const owner=new Function('require','rawCombat',ownerLine+'return nativeTextEvents;')(require,identities);
 const registry=new GameObjectArray({clientMode:true}),world={areaId:worldAreaAvailable?7:null,registry,entityDisclosures:new EntityDisclosureLifetimes()};
 const id=0x80000000,target=targetState==='missing'?null:{objectType:targetState==='noncreature'?9:5,...(targetState==='unknown-area'?{}:{areaId:targetState==='other-area'?8:7}),replicationRemoved:targetState==='removed'};
 if(target&&registry.addObjectAtPos(id,target).status!==0)throw Error('Authored canonical target insertion failed');
 let previousTarget=null;
 if(disclosure==='redisclosed'){
  previousTarget=world.entityDisclosures.transportRow(target,identities.object(target));
 }
 const file='backups/animations/native-client-feedback-layouts.json',bytes=fs.readFileSync(path.join(workspace,file)),layouts=JSON.parse(bytes);
 if(layouts.target!=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a')throw Error('Original receiver trace binary identity changed');
 const rows=layouts.cases.filter(row=>[93,94].includes(row.type));if(rows.length!==16)throw Error('Original ScriptFloating receiver trace count changed');
 const current={world},empty={frame(){return null;}},messages=[],previousMessages=[],report={},packets=[];
 for(const row of rows){
  if(row.error!==null)throw Error('Original receiver trace rejected');
  const writer=new NativeMessageWriter(1);writer.create(128,0xffffffff,1);writer.writeWord(row.type);
  for(const read of row.reads){
   if(read.kind==='object')writer.writeObjectIdClient(read.value);
   else if(read.kind==='int')writer.writeInt(read.value);
   else if(read.kind==='bool')writer.writeBool(read.value);
   else if(read.kind==='string'){const value=scriptStringBytes('S'+read.value);writer.writeCExoString({bytes:value,length:value.length});}
   else throw Error('Unexpected ScriptFloating receiver field kind');
  }
  writer.setPrefix(Uint8Array.of(80,18,11));const packet=Uint8Array.from(writer.getWriteMessage().data),build={number:8193,revision:row.buildOk?37:34,postfix:row.buildOk?17:0};
  const decoded=decodeServerGameMessage(packet,{serverBuild:build}),before=JSON.stringify(decoded),count=messages.length;
  const expected=structuredClone(row.outputs[0]);for(const [key,value]of Object.entries(expected.data.strings))expected.data.strings[key]={text:value};
  if(!isDeepStrictEqual(decoded,{kind:'combat-feedback',...expected,major:18,minor:11}))throw Error('Actual codec disagrees with original receiver field trace');
  if(disclosure==='redisclosed'&&previousMessages.length===0){
   dispatch(current,current,3,{connection:3},false,decoded,2,owner,{frames:()=>[]},{frames:()=>[]},empty,empty,empty,()=>null,value=>previousMessages.push(structuredClone(value)),report);
   target.replicationRemoved=true;world.entityDisclosures.observeAccepted([{action:'delete',id}],registry);target.replicationRemoved=false;
  }
  dispatch(current,current,3,{connection:3},false,decoded,2,owner,{frames:()=>[]},{frames:()=>[]},empty,empty,empty,()=>null,value=>messages.push(value),report);
  if(messages.length!==count+1||JSON.stringify(decoded)!==before)throw Error('Actual Host changed/dropped original decoded fields');
  packets.push({type:row.type,mode:row.mode,buildOk:row.buildOk,serverBuild:build,hex:Buffer.from(packet).toString('hex'),major:18,minor:11});
 }
 if(Object.keys(report).length)throw Error('Actual Host metadata capture failed');
 return {version:1,scope:{connection:3,generation:2,areaId:world.areaId},targetState,disclosure,worldAreaAvailable,previousTarget,previousMessages,target:target?world.entityDisclosures.transportRow(target,identities.object(target)):null,messages,packets,provenance:{nativeWriterCapture:false,originalReceiverTraces:16,authoredCodecPackets:16,priorHostMessageCount:previousMessages.length,hostSha256:digest(source),fragmentSha256:digest(fragment),firstLine:source.slice(0,start).split('\n').length,lastLine:source.slice(0,end).split('\n').length,originalFiles:[{path:file,sha256:digest(bytes)}],scope:'Original receiver field traces through authored NativeMessageWriter bytes, actual decoder and bounded actual Host ingress; controlled canonical target only. Optional accepted D/re-A uses the existing disclosure owner, never invented lifetime values. No original-writer/server/live/GPU claim. No renderer/channel policy in this adapter.'}};
}
