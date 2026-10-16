import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {executeAreaWait,receiveAreaReady,movePlayerToArea,realizeAssociates} from '../src/player_area.js';
const raw=id=>{const raw=new DataView(new ArrayBuffer(0x100));raw.setInt32(0x24,id,true);return{raw};};
test('area readiness, canonical player placement and associate realization match 5,688 original executions',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-player-area-observations.json',import.meta.url)));assert.equal(data.rows.length,5688);
 for(const row of data.rows){
  const c=row.case,calls=[],actor={id:99,nativeField89c:c.pc??1,associateType:c.associateType??0,nativePathInfo:raw(0),nativeLastClientArea4f4:88,nativePendingAreaPosition4f8:[11,12,13],position:[1,2,3]},
   client={nativeLoadState50:c.load??2},area={id:88},other={id:89},module={id:66},children=[100,101].map((id,i)=>({id,nativePathInfo:raw(id),nativeLastClientArea4f4:i===0?89:0x7f000000,nativePendingAreaPosition4f8:[7+i,8+i,9+i],nativeField89c:c.pc??1,nativeField58c:777,nativeField54c:888,nativeField550:999})),ids=c.nullList?null:[...(c.ids??[100,102,101])];
  let modes=0,safes=0,adds=0;
  const p={
   controlled:id=>{calls.push(['controlled',id]);return c.controlled??0;},area:o=>{calls.push(['area',o.id]);return c.rootArea===false?null:area;},
   overflow:()=>{calls.push(['overflow']);return c.overflow??0;},serverMode:()=>{calls.push(['mode']);const values=c.modes??[2,2];return values[Math.min(modes++,values.length-1)];},
   clientObject:()=>{calls.push(['clientObject',client.nativeLoadState50]);return c.object===false?null:actor;},
   addAudience:-9,otherAudience:-10,addPlayer:audience=>{calls.push(['addPlayer',audience]);return(c.adds??[1,1])[adds++];},
   allPlayers:()=>{calls.push(['allPlayers']);return c.all??1;},movePlayer:()=>calls.push(['movePlayer']),updateParty:audience=>{calls.push(['party',audience]);return c.party??1;},
   pauseState:code=>{calls.push(['pauseState',code]);return(c.pause??[0,0])[code-1];},sendPause:(...a)=>calls.push(['sendPause',...a]),
   asCreature:o=>{calls.push(['asCreature']);return o;},lookup:id=>{calls.push(['lookup',id]);return c.module===false?null:module;},asModule:o=>{calls.push(['asModule']);return o;},moduleId:()=>66,
   module:()=>{calls.push(['module']);return module;},moduleArea:(_module,id)=>{calls.push(['moduleArea',id]);return id===88&&c.area!==false?area:id===89&&c.pending!==false?other:null;},
   safeLocation:(a,point,range,path,flag,out)=>{
    const values=c.safe??[1,1],writes=c.write??[true,true];calls.push(['safe',a?.id??null,point.slice(),range,path.raw.getInt32(0x24,true),flag]);
    if(writes[Math.min(safes,writes.length-1)])out.point=[20+safes,30+safes,40+safes];return values[Math.min(safes++,values.length-1)];
   },
   subareas:(o,p,id)=>calls.push(['subareas',o.id,p.slice(),id]),addToArea:(o,a,...v)=>calls.push(['addArea',o.id,a?.id??null,...v]),
   realizeAssociates:o=>{calls.push(['realize',o.id]);if(c.truncate)ids.splice(1);},updateVisible:o=>calls.push(['visible',o.id]),
   possessedFamiliar:o=>{calls.push(['possessed',o.id]);return c.possessed??0;},updateAutoMap:(o,id)=>calls.push(['automap',o.id,id]),
   associates:()=>ids,creature:id=>{calls.push(['creature',id]);return children.find(o=>o.id===id)??null;},position:o=>o.position,
   warning:message=>calls.push(['warning',message]),clearActions:o=>calls.push(['clear',o.id,o.nativeField58c]),
  };
  let result;
  if(c.operation==='wait')result=await executeAreaWait(actor,{},p);
  else if(c.operation==='ack')result=await receiveAreaReady(client,c.subtype??3,p);
  else if(c.operation==='move')await movePlayerToArea(client,p);
  else await realizeAssociates(actor,p);
  const got={calls,load:client.nativeLoadState50,owner:actor.nativePathInfo.raw.getInt32(0x24,true),children:children.map(o=>[o.nativeField58c,o.nativeField54c,o.nativeField550]),...(['ack','wait'].includes(c.operation)?{result}:{})};
  assert.deepEqual(got,{calls:row.calls,load:row.load,owner:row.owner,children:row.children,...(['ack','wait'].includes(c.operation)?{result:row.result}:{})},JSON.stringify(c));
 }
});
