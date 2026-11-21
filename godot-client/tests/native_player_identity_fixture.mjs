// Actual Session -> World -> same host-header producer; all peers are in memory.
import {EventEmitter} from 'node:events';
import fs from 'node:fs';
import {NativeMessageWriter} from '../../src/native_message.js';
import {NetworkGameSession} from '../../electron/network_game_session.mjs';
import {playerRosterHeader} from '../../src/network_player_roster.js';
const SELECTED=0x80000002,CONTROLLED=0x80000003,OTHER=0x80000004;
function wire(major,minor,write){const w=new NativeMessageWriter(1);w.create(4096,0xffffffff,1);write(w);w.setPrefix(Uint8Array.of(80,major,minor));return Uint8Array.from(w.getWriteMessage().data);}
const text=(w,value)=>w.writeStringBytes(Buffer.from(value,'utf8'));
function roster(minor,rows){return wire(10,minor,w=>{w.writeBool(0);if(minor===1)w.writeByte(rows.length);for(const p of rows){w.writeDword(p.playerId);w.writeObjectIdServer(p.objectId);w.writeBool(p.isDM??0);text(w,p.name);w.writeBool(Boolean(p.character));w.writeByte(p.peerD8);text(w,p.peerC8);if(p.character){w.writeObjectIdServer(p.character.id);for(const name of [p.character.firstName,p.character.lastName]){w.writeBool(0);text(w,name.text);}w.writeWord(p.character.portrait);}}});}
function row(playerId,selectedId=SELECTED){return{playerId,objectId:CONTROLLED,isDM:0,name:'Owned account',peerD8:0,peerC8:'',...(selectedId==null?{}:{character:{id:selectedId,firstName:{text:'Selected'},lastName:{text:'Character'},portrait:6}})};}
function session(){const peer=new EventEmitter();peer.connect=async()=>({build:{number:8193,revision:37,postfix:17}});peer.sendGameMessage=async()=>{};peer.disconnect=async()=>peer.emit('closed');return new NetworkGameSession({peer,identity:{dispose(){}},build:{build:{number:8193,revision:37,postfix:17},dispose(){}},resources:{},language:0,openModule:async()=>null});}
export async function playerIdentityFixture(){
 const s=session();await s.connect({metadata:{connectionType:16}});const stages=[];
 function stage(label,target,lookupAvailable,isPlayer,{roleAvailable=true,dm=false,normal=lookupAvailable&&roleAvailable&&!dm}={}){stages.push({label,target,header:JSON.parse(JSON.stringify(playerRosterHeader(s.world))),expected:{lookupAvailable,isPlayer,roleAvailable,dmPermission:roleAvailable?dm:null,normalAdmission:normal}});}
 stage('initial empty list is not a complete roster',CONTROLLED,false,null);
 await s.receive(roster(2,[row(0)]));stage('positive selected identity before full roster',SELECTED,true,true);stage('controlled alias not selected before full roster',CONTROLLED,false,null);
 await s.receive(roster(1,[row(0)]));stage('complete roster selected',SELECTED,true,true);stage('complete roster controlled alias is not a player character',CONTROLLED,true,false);
 await s.receive(wire(5,2,w=>{w.writeDword(0);w.writeObjectIdServer(OTHER);}));stage('possession control does not rewrite selected identity',SELECTED,true,true);stage('possession controlled target is not selected PC',OTHER,true,false);
 await s.receive(roster(2,[row(1,null)]));stage('received no-character guest is complete metadata',OTHER,true,false);
 await s.receive(roster(2,[row(0,OTHER)]));stage('delta changes selected identity',OTHER,true,true);stage('delta retires old selected identity',SELECTED,true,false);
 const before=JSON.stringify(playerRosterHeader(s.world));let rejected=false;
 try{s.world.apply({kind:'player-list-all',server140:0,players:[row(3),{...row(4),uncloneable(){}}]});}catch{rejected=true;}
 if(!rejected||JSON.stringify(playerRosterHeader(s.world))!==before)throw Error('Roster rollback was not atomic');
 stage('rejected full roster preserves prior complete knowledge',OTHER,true,true);
 s.world.apply({kind:'player-list-add',players:[{playerId:2,objectId:CONTROLLED,character:{id:SELECTED}}]});stage('partial delta cannot justify a negative',0x80000070,false,null);stage('partial explicit selected identity remains positive',SELECTED,true,true);
 await s.receive(wire(10,3,w=>{w.writeBool(0);w.writeDword(2);}));stage('delete partial delta restores complete remaining schema',0x80000070,true,false);
 await s.receive(roster(1,[]));stage('received complete empty roster is known empty',SELECTED,true,false);
 await s.receive(wire(31,22,w=>{w.writeBool(1);w.writeBool(0);w.writeInt(0);}));stage('received DM permission blocks normal context',SELECTED,true,false,{dm:true,normal:false});
 await s.receive(wire(31,22,w=>{w.writeBool(0);w.writeBool(1);w.writeInt(123);}));stage('received false permission restores normal metadata admission',SELECTED,true,false);
 s.world.reset();stage('reset loses both roster and permission',SELECTED,false,null,{roleAvailable:false,normal:false});await s.disconnect();
 const unknown=session();await unknown.connect({metadata:{connectionType:32}});const unknownHeader=JSON.parse(JSON.stringify(playerRosterHeader(unknown.world)));await unknown.disconnect();stages.push({label:'unsupported32 role unavailable',target:SELECTED,header:unknownHeader,expected:{lookupAvailable:false,isPlayer:null,roleAvailable:false,dmPermission:null,normalAdmission:false}});
 return{success:true,stages,scope:'Actual typed in-memory Session/decoder/World/current host producer to native metadata admission. No socket/server/live-client/DM update or Desktop target binding.'};
}
if(process.argv.some(value=>value.startsWith('--report='))){const output=process.argv.find(value=>value.startsWith('--report=')).slice(9);if(fs.existsSync(output))throw Error('Refusing overwrite');fs.writeFileSync(output,JSON.stringify(await playerIdentityFixture(),null,2)+'\n');}
