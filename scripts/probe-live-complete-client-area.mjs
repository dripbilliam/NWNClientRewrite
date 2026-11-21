import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {RESOURCE_TYPE,decodeResourceText} from '../src/resource_archive.js';
import {parse2da} from '../src/area.js';
import {sendClientArea,setAreaTransitionBmp,clearLastSentAutomap,loadingScreenString} from '../src/client_area_message.js';
import {NativeServerMessage,NativeMessageReader,nativeMessageProviders} from '../src/native_message.js';
import {areaPackCase} from './area-pack-case.mjs';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',resolver=await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),s=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
const table=parse2da(decodeResourceText(await resolver.getResource('loadscreens',RESOURCE_TYPE.TWO_DA))),client=s.combat.broadcastProviders().client(s.player.id),reports=[],cases=[];
// Explicit isolated PLAYER_ID/language/expansion fixtures, distinct from the
// registry's canonical OBJECT_ID. No real transport or automatic ready signal.
client.nativePlayerId48=42;client.nativeLanguage4c=0;
for(const format of [0,1])for(const area of s.areas.values()){
 client.nativeAreaTransitionBmp20=-1;client.nativeLastUpdateObjectA8={nativeLastSentMap170:new Uint8Array(128),nativeLastSentMapArea178:88};
 const message=new NativeServerMessage(format),calls=[],writes=[],random=[],initialBmp=client.nativeAreaTransitionBmp20,point=[24.25,14.5,0],orientation=[.3,.9,0],flag=0;let packet;
 const scalar=nativeMessageProviders({messageName:()=> 'captured Area/ClientArea',log:()=>{},server:()=>s,netLayer:()=>({}),
  send:(_net,id,data,length,sendFlag)=>{packet=data.slice(0,length);calls.push(['transportBoundary',id,length,sendFlag]);return 1;}});
 const p={...scalar,module:()=>s.module,serverMode:()=>2,clientObject:c=>s.registry.get(c.object.id),clearLastMap:clearLastSentAutomap,
  setBmp:(c,value,text)=>{calls.push(['setBmp',value]);setAreaTransitionBmp(c,value,text);},loadingCount:()=>table.orderedRows.length,tileset:a=>a.tilesetResRef,
  loadingString:(row,column)=>{const result=loadingScreenString(table,row,column);calls.push(['loadingString',row,column,result]);return result;},random:()=>{const value=s.random.next();random.push(value);return value;},warning:site=>calls.push(['warning',site]),
  writeInt:(m,...args)=>{writes.push(['int',...args]);scalar.writeInt(m,...args);},writeFloat:(m,...args)=>{writes.push(['float',...args]);scalar.writeFloat(m,...args);},writeBool:(m,...args)=>{writes.push(['bool',...args]);scalar.writeBool(m,...args);},
  packArea:async(a,x,y,z,c)=>{calls.push(['packArea',a.id,x,y,z]);return s.areaMessages.pack(message,a,x,y,z,c,{clients:[client],hasExpansion:()=>1});},
 };
 assert.equal(await sendClientArea(message,client,area,point,orientation,flag,p),1);assert.equal(client.nativeAreaTransitionBmp20,-1);
 assert.equal(client.nativeLastUpdateObjectA8.nativeLastSentMap170,null);assert.deepEqual([...packet.subarray(0,3)],[80,4,1]);
 const reader=new NativeMessageReader(format);assert.equal(reader.setReadMessage(packet.subarray(3),packet.length-3,42,1),1);
 assert.equal(reader.readInt(),writes[0][1]);for(const entry of writes.slice(1,5))assert.equal(reader.readFloat(),Math.fround(entry[1]));assert.equal(reader.readBool(),0);
 assert.equal(reader.readObjectIdServer(),area.id);const resource=reader.readCResRef(16);assert.equal(Buffer.from(resource).toString('ascii').split('\0')[0],area.resRef);
 const custom=reader.readBool(),reference=custom?0:reader.readBool();if(reference){reader.readByte(1,1);reader.readDword(32);}else reader.readCExoString(32);
 const packPoint=calls.find(c=>c[0]==='packArea').slice(2);assert.deepEqual([reader.readInt(),reader.readInt(),reader.readInt()],packPoint);assert.equal(reader.messageReadOverflow(),0);
 const payload=message.getWriteMessage(),packetHex=Buffer.from(packet).toString('hex'),definedMaskHex=Buffer.from(payload.defined).toString('hex'),observation={result:payload.status,length:payload.length,byteLength:message.byteLength14,bitLength:message.bitLength24,bitOffset:message.bitOffset2c,total:message.total28,byteCapacity:message.byteStorage.bytes.length,bitCapacity:message.bitStorage.bytes.length,writing:message.writing30,flag:message.flag60,playerId:message.playerId64};
 const nativeCase=await areaPackCase(s,message,area,client,format);nativeCase.point=packPoint;nativeCase.clientArea={bmp:initialBmp,defaultBmp:area.nativeLoadScreenId350,rows:table.orderedRows.map((_,i)=>loadingScreenString(table,i,'TileSet')),random,point,orientation,flag,packFloats:['float14','float18','float1c'].map(k=>s.module.nativeField108[k])};
 cases.push({case:nativeCase,packetHex,definedMaskHex,observation});reports.push({format,areaId:area.id,resRef:area.resRef,packetBytes:packet.length,selectedScreen:writes[0][1],bodyPrefixDecoded:true,notTransmitted:true,calls});
}
const limits='Complete decoded ClientArea sender, normal live area packer, real scalar/text/ID writers and send envelope assembled together for installed data. Explicit PLAYER_ID42/language0/expansion/modes0,1. Transport captured; native client scene receiver/ready and production client lifecycle remain unfinished.';
await fs.writeFile('backups/animations/live-complete-client-area.json',JSON.stringify({limits,reports,cases},null,2));console.log(JSON.stringify({limits,reports},null,2));
