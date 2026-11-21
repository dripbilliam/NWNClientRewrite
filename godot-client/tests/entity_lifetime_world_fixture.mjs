import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {NetworkWorld} from '../../src/network_world.js';
import combat from '../tools/raw-combat-events.cjs';
import deltas from '../tools/raw-world-deltas.cjs';
import framing from '../tools/raw-world-frames.cjs';
const {RawCombatEvents}=combat,{RawWorldDeltas}=deltas,{rawWorldFrames}=framing;
export function entityLifetimeTrace(){
 const id=0x80000002,area=0x80000001,nextArea=0x80000003,stages=[],diagnostics=[];
 let world=new NetworkWorld({onDiagnostic:d=>diagnostics.push(d)}),connection=1,generation=1,serial=0;
 const renderer=new RawCombatEvents(),bridge=new RawWorldDeltas();
 const state=()=>({areaId:world.areaId,position:[1,2,3],orientation:[1,0,0],name:{firstName:{text:'Client-known'},lastName:{text:'fixture'}}});
 const create=()=>({action:'create',objectType:5,id,state:state()});
 const remove=flag=>({action:'delete',objectType:5,id,remove:flag});
 const capture=(name,expected)=>{
  const object=world.registry.get(id),data={area:{id:world.areaId},controlledId:id,objects:[...world.registry.objects.values()].map(o=>world.entityDisclosures.transportRow(o,renderer.object(o)))};
  const changed=bridge.plan({connection,generation,serial:++serial,data});
  const frames=changed?[...rawWorldFrames({connection,generation,serial,data:changed})].map(frame=>JSON.parse(frame)):[];
  if(changed)assert.equal(bridge.acknowledge({connection,generation,serial}),true);
  stages.push({name,expected,connection,generation,area:world.areaId,objectId:id,disclosure:object?world.entityDisclosures.token(object):null,renderLifetime:object?renderer.identity(object):null,frames});
  return stages.at(-1);
 };
 world.areaId=area;world.localObjectId=id;assert.equal(world.apply({kind:'object-updates',records:[create()]}),true);
 const proxy=world.registry.get(id),first=capture('initial','new');
 world.apply({kind:'object-updates',records:[create()]});const repeat=capture('repeated-a','same');
 assert.equal(world.registry.get(id),proxy);assert.equal(repeat.disclosure,first.disclosure);assert.equal(repeat.frames.length,0);
 world.apply({kind:'object-updates',records:[remove(1)]});world.apply({kind:'object-updates',records:[create()]});
 const coalesced=capture('d-a-between-snapshots','replaced');assert.equal(world.registry.get(id),proxy);assert.notEqual(coalesced.disclosure,first.disclosure);assert.equal(coalesced.renderLifetime,first.renderLifetime);
 world.apply({kind:'object-updates',records:[remove(0),create()]});const packet=capture('d-a-in-one-packet','replaced');
 assert.notEqual(packet.disclosure,coalesced.disclosure);assert.equal(packet.renderLifetime,first.renderLifetime);
 const before=structuredClone(proxy),token=world.entityDisclosures.token(proxy);
 assert.throws(()=>world.apply({kind:'object-updates',records:[remove(1),{action:'create',objectType:6,id,state:{}}]}),/Conflicting/);
 assert.deepEqual(proxy,before);assert.equal(world.entityDisclosures.token(proxy),token);assert.equal(capture('rejected-transaction','same').frames.length,0);
 world.apply({kind:'client-area',area:{id:nextArea,width:1,height:1,mapPins:[],sounds:[],placeableLights:[],staticPlaceables:[],time:{}},position:[4,5,6],facing:0});generation++;
 assert.equal(world.registry.get(id),proxy);assert.equal(world.entityDisclosures.token(proxy),token);capture('area-retained-proxy','scope');
 world.apply({kind:'object-updates',records:[remove(1)]});capture('disclosed-removal','removed');
 world.apply({kind:'object-updates',records:[create()]});capture('same-id-after-removal','new');
 const beforeReset=world.entityDisclosures.token(proxy);world.reset();world.areaId=nextArea;world.localObjectId=id;generation++;
 world.apply({kind:'object-updates',records:[create()]});assert.ok(world.entityDisclosures.token(world.registry.get(id))>beforeReset);capture('world-reset','scope');
 world=new NetworkWorld({onDiagnostic:d=>diagnostics.push(d)});world.areaId=nextArea;world.localObjectId=id;connection=2;generation=0;
 world.apply({kind:'object-updates',records:[create()]});const reconnect=capture('reconnect','scope');assert.equal(reconnect.disclosure,first.disclosure);
 return {success:true,objectId:id,stages,diagnostics:diagnostics.map(d=>d.code),scope:'Authored decoded records through actual NetworkWorld retained proxies, original raw identity, production disclosure tagging, RawWorldDeltas and RawWorldFrames; no game-server/client/render acceptance'};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 const output=process.argv.find(arg=>arg.startsWith('--output='))?.slice(9);if(!output)throw Error('An owned output is required');
 const result=entityLifetimeTrace();fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,stages:result.stages.length,frames:result.stages.reduce((n,s)=>n+s.frames.length,0)}));
}
