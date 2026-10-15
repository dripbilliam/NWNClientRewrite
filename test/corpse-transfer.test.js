import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {acquirePlaceableItem,acquireCorpseItems} from '../src/corpse_transfer.js';
const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-corpse-transfer-observations.json',import.meta.url)));
test('placeable acquisition matches native source removal, null repository, ignored fit result and replaced/null pointers',async()=>{
  for(const row of oracle.acquisitions){const c=row.case,calls=[],o={id:90},owner=c.ownerType?{objectType:c.ownerType}:null,repo={},ref={item:{id:1,possessorId:c.matches?77:78}};
    const result=await acquirePlaceableItem(o,ref,77,255,254,2,{repository:a=>a===o?c.destinationRepo?repo:null:repo,object:()=>owner,
      removeCreature:(_o,item,...args)=>calls.push(['removeCreature',item.id,...args]),removePlaceable:(_o,item,...args)=>calls.push(['removePlaceable',item.id,...args]),removeRepository:(_repo,item)=>calls.push(['removeRepository',item.id]),removeFromArea:item=>calls.push(['removeArea',item.id]),baseInfo:()=>{calls.push(['baseOwner']);return{container:c.container};},addItem:(_repo,ref,...args)=>{calls.push(['add',ref.item.id,...args]);ref.item=c.nullAfter?null:{id:2};return c.result;},setPossessor:(item,...args)=>calls.push(['possessor',item.id,...args])});
    assert.deepEqual({result,calls},{result:row.result,calls:row.calls},JSON.stringify(c));
  }
});
test('corpse collection matches original fourteen slots, copied identities, five size buckets, UINT gold and success counts',async()=>{
  for(const row of oracle.collections){const c=row.case,calls=[],o={id:90},source={id:77,objectType:c.ownerType,nativeGold898:c.gold},items=new Map(oracle.definitions.map(i=>[i.id,{...i}])),repo={head:null};let tail=null,nextId=80;
    for(const id of c.repository){const node={id,next:null};if(tail)tail.next=node;else repo.head=node;tail=node;}
    const construct=()=>{const item={id:nextId++};calls.push(['construct',item.id]);return item;};
    const result=await acquireCorpseItems(o,77,c.filter,{creature:id=>{calls.push(['creature',id]);return c.ownerType===5?source:null;},placeable:id=>{calls.push(['placeable',id]);return c.ownerType===9?source:null;},hasEquipment:()=>c.hasEquipment,repository:()=>c.sourceRepo?repo:null,equipment:(_o,slot)=>{calls.push(['equipment',slot]);return items.get(c.equipment[slot])??null;},repositoryItem:(_r,node)=>items.get(node.id)??null,baseInfo:item=>{calls.push(['base',item.id]);return item;},copyItem:(item,flag)=>{const result=construct();calls.push(['copy',result.id,item.id,flag]);return result;},constructItem:construct,loadTemplate:(item,...args)=>{calls.push(['template',item.id,...args]);return 0;},setGold:(actor,value)=>{calls.push(['gold',value]);actor.nativeGold898=value;},acquire:(_o,ref,...args)=>{calls.push(['acquire',ref.item.id,...args]);return c.result;}});
    assert.deepEqual({result,calls,gold:source.nativeGold898},{result:row.result,calls:row.calls,gold:row.gold},JSON.stringify(c));
  }
});
