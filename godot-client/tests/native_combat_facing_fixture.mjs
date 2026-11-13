import fs from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {NetworkWorld} from '../../src/network_world.js';
export function facingDeliveryFixture(){
 const world=new NetworkWorld({onDiagnostic:()=>{}}),area=0x80000001,actor=0xffffffce,right=0x80000002,left=0x80000003;
 world.areaId=area;
 world.applyObjectUpdates([{action:'create',id:actor,objectType:5,state:{areaId:area,position:[0,0,0],orientation:{vector:[0,1,0]},animation:0,walkRate:1000,runRate:1000,facingTarget:0x7f000000}},{action:'create',id:right,objectType:9,state:{areaId:area,position:[10,0,0]}},{action:'create',id:left,objectType:9,state:{areaId:area,position:[-10,0,0]}}]);
 const initial=structuredClone([...world.registry.objects.values()]);let revision=0;
 const steps=[];
 for(const [label,target]of [['right',right],['unlock',0x7f000000],['left',left]]){
  world.applyObjectUpdates([{action:'update',id:actor,objectType:5,state:{facingTarget:target}}]);
  const event=world.presentationChanges.find(e=>e.action==='movement');
  steps.push({label,target,records:event?[{id:event.id,revision:++revision,created:false,changes:structuredClone(event.changes),initial:structuredClone(world.registry.get(actor).replicated)}]:[]});
 }
 return {scope:'Actual accepted NetworkWorld movement projection; authored decoded fields, no game-server/decoder claim.',area,actor,right,left,initial,steps};
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const output=process.argv.find(arg=>arg.startsWith('--report='))?.slice(9);if(!output)throw Error('Unused output required');
 await fs.writeFile(output,JSON.stringify(facingDeliveryFixture(),null,2)+'\n',{flag:'wx'});
}
