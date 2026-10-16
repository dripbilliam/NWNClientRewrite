import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {RESOURCE_TYPE,decodeResourceText} from '../src/resource_archive.js';
import {parse2da} from '../src/area.js';
import {sendClientArea,setAreaTransitionBmp,clearLastSentAutomap,loadingScreenString} from '../src/client_area_message.js';
import {NativeServerMessage,NativeMessageReader,nativeMessageProviders} from '../src/native_message.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',resolver=await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),s=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)}),
 table=parse2da(decodeResourceText(await resolver.getResource('loadscreens',RESOURCE_TYPE.TWO_DA))),client=s.combat.broadcastProviders().client(s.player.id),npc=[...s.registry.objects.values()].find(o=>o.objectType===5&&o!==s.player),reports=[];
// PLAYER_ID42 is an explicit isolated transport fixture. It remains distinct
// from canonical object565; the production GUI adapter invents no PLAYER_ID.
client.nativePlayerId48=42;client.nativeLastUpdateObjectA8={nativeLastSentMap170:new Uint8Array(128),nativeLastSentMapArea178:88};
await s.commands.SetAreaTransitionBMP([2,'ignored'],{self:s.player.id});assert.equal(client.nativeAreaTransitionBmp20,2);
await s.commands.SetAreaTransitionBMP([3,'npc'],{self:npc.id});assert.equal(client.nativeAreaTransitionBmp20,2);
for(const formatMode28 of [0,1])for(const area of s.areas.values()){
 const calls=[],writes=[],message=new NativeServerMessage(formatMode28),point=[24.25,14.5,0];let packet;
 const scalar=nativeMessageProviders({
  messageName:(major,minor)=>{calls.push(['messageNameBoundary',major,minor]);return'captured Area/ClientArea';},
  log:entry=>calls.push(['nativeSendLog',entry]),server:()=>s,netLayer:server=>{assert.equal(server,s);return{};},
  send:(_net,id,data,length,flag)=>{packet=data.slice(0,length);calls.push(['transportBoundary',id,packet[1],packet[2],length,flag]);return 1;},
 });
 const p={...scalar,
  module:()=>s.module,serverMode:()=>2,clientObject:c=>s.registry.get(c.object.id),clearLastMap:clearLastSentAutomap,
  create:(m,size,id,flag)=>{calls.push(['create',size,id,flag]);scalar.create(m,size,id,flag);},setBmp:setAreaTransitionBmp,loadingCount:()=>table.orderedRows.length,
  loadingString:(row,column)=>loadingScreenString(table,row,column),tileset:a=>a.tilesetResRef,random:()=>s.random.next(),warning:site=>calls.push(['warning',site]),
  writeInt:(m,...args)=>{writes.push(['int',...args]);scalar.writeInt(m,...args);},writeFloat:(m,...args)=>{writes.push(['float',...args]);scalar.writeFloat(m,...args);},writeBool:(m,...args)=>{writes.push(['bool',...args]);scalar.writeBool(m,...args);},
  packArea:(a,x,y,z,c)=>{calls.push(['packBoundary',a.id,x,y,z,c.object.id]);return 1;},
 };
 const result=await sendClientArea(message,client,area,point,[.3,.9,0],0,p);assert.equal(result,1);assert.equal(client.nativeAreaTransitionBmp20,-1);
 assert.equal(writes.length,6);assert.equal(writes[0][0],'int');assert.ok(writes[0][1]>=2&&writes[0][1]<table.orderedRows.length);
 assert.equal(client.nativeLastUpdateObjectA8.nativeLastSentMap170,null);assert.equal(client.nativeLastUpdateObjectA8.nativeLastSentMapArea178,0x7f000000);
 const reader=new NativeMessageReader(formatMode28);assert.equal(reader.setReadMessage(packet.subarray(3),packet.length-3,42,1),1);
 assert.equal(reader.readInt(),writes[0][1]);for(const value of writes.slice(1,5))assert.equal(reader.readFloat(),Math.fround(value[1]));assert.equal(reader.readBool(),0);assert.equal(reader.messageReadOverflow(),0);assert.equal(reader.messageReadUnderflow(),0);
 assert.deepEqual([...packet.subarray(0,3)],[80,4,1]);assert.equal(message.getWriteMessage().prefixPending,false);
 reports.push({formatMode28,areaId:area.id,resRef:area.resRef,tileset:area.tilesetResRef,authoredScreen:area.nativeLoadScreenId350,selectedScreen:writes[0][1],screenRow:table.orderedRows[writes[0][1]],writes,calls,
  headerOnlyPacketHex:Buffer.from(packet).toString('hex'),definedMaskHex:Buffer.from(message.getWriteMessage().defined).toString('hex'),headerDecoded:true});
}
const report={playerId:42,controlledObjectId:s.player.id,loadingRows:table.orderedRows.length,moduleEntry:s.module.nativeField108,npcCannotChangePlayerSelection:true,reports,
 limits:'Installed ARE/IFO/active loadscreens data and real per-context script selection/shared RNG feed the verified ClientArea coordinator and split-stream scalar writer, reader and send envelope. Explicit formatMode28 fixture modes 0/1 are not inferred from runtime. PackAreaIntoMessage and net transport remain captured boundaries: packet contains only the scalar ClientArea header; it is incomplete and never transmitted. Native scene-ready/ACK/persistence and actual loading-screen presentation are unfinished.'};
await fs.writeFile('backups/animations/live-client-area-message.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
