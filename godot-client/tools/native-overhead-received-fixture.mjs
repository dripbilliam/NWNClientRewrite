import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {decodeServerGameMessage} from '../../src/network_game_messages.js';
import {GameObjectArray} from '../../src/game_object_array.js';
import {EntityDisclosureLifetimes} from '../../src/network_entity_lifetimes.js';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project);
const digest=value=>crypto.createHash('sha256').update(value).digest('hex');
export function receivedSpeechFixture({contextAvailable=true}={}){
 const hostPath=path.join(project,'tools/native-session-host.cjs'),source=fs.readFileSync(hostPath,'utf8');
 const first='if(current!==session||connection!==lobby.connection||ending)return;',last="if(message.kind==='object-updates'){const frame=rawCombat.frame",start=source.indexOf(first),end=source.indexOf(last,start);
 if(start<0||end<start||source.indexOf(first,start+1)>=0)throw Error('Current bounded Host text dispatch anchors changed');
 const fragment=source.slice(start,end),dispatch=new Function('current','session','connection','lobby','ending','message','areaGeneration','nativeTextEvents','rawTileVisibility','rawCreatureVisibilityPermission','rawVoice','rawScriptSounds','rawVisual','guiPanelEventForHost','send','report',fragment);
 const ownerLine=source.split(/\r?\n/).find(line=>line.startsWith('const nativeTextEvents='));
 if(!ownerLine)throw Error('Current actual Host text owner missing');
 const require=createRequire(hostPath),identities=new (require('./raw-combat-events.cjs').RawCombatEvents)();
 const owner=new Function('require','rawCombat',ownerLine+'return nativeTextEvents;')(require,identities);
 const registry=new GameObjectArray({clientMode:true}),world={areaId:7,registry,entityDisclosures:new EntityDisclosureLifetimes()};
 const speaker={objectType:5,areaId:7,replicationRemoved:false};if(registry.addObjectAtPos(0x80000013,speaker).status!==0)throw Error('Authored canonical fixture insertion failed');
 const context=contextAvailable?{objectType:5,areaId:7,replicationRemoved:false}:null;if(context&&registry.addObjectAtPos(0xffffffff,context).status!==0)throw Error('Independent token context fixture insertion failed');
 const current={world},empty={frame(){return null;}},messages=[],report={};
 const files=['backups/animations/native-network-chat-writer-observations.json','backups/animations/native-network-speech-observations.json'];
 const originals=files.map(file=>JSON.parse(fs.readFileSync(path.join(workspace,file))));
 if(originals.some(value=>value.target!=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'))throw Error('Original sender fixture identity changed');
 const packets=originals[0].cases.filter(row=>row.case.format===1).flatMap(row=>row.packets).concat(originals[1].cases.filter(row=>row.case.format===1).map(row=>row.packet));
 if(packets.length!==75)throw Error('Original sender packet count changed');
 for(const hex of packets){
  const decoded=decodeServerGameMessage(Buffer.from(hex,'hex'),{clientBuild:{number:8193,revision:37,postfix:17}}),before=JSON.stringify(decoded),count=messages.length;
  dispatch(current,current,3,{connection:3},false,decoded,2,owner,{frames:()=>[]},{frames:()=>[]},empty,empty,empty,()=>null,value=>messages.push(value),report);
  if(messages.length!==count+1||JSON.stringify(decoded)!==before)throw Error('Actual Host did not preserve one original received packet');
 }
 if(Object.keys(report).length)throw Error('Actual Host metadata capture failed');
 return {version:1,scope:{connection:3,generation:2,areaId:7},speaker:world.entityDisclosures.transportRow(speaker,identities.object(speaker)),context:context?world.entityDisclosures.transportRow(context,identities.object(context)):null,messages,provenance:{originalPackets:75,contextAvailable,hostSha256:digest(source),fragmentSha256:digest(fragment),firstLine:source.slice(0,start).split('\n').length,lastLine:source.slice(0,end).split('\n').length,originalFiles:files.map(file=>({path:file,sha256:digest(fs.readFileSync(path.join(workspace,file)))})),scope:'Retained original sender packets through real decoder and bounded actual Host dispatch into controlled canonical speaker; token-context availability explicit. No original-server/live-receive claim.'}};
}
