import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {scriptCopyItem} from '../src/script_item_copy.js';
import {acquireContainerItem} from '../src/item_acquisition.js';
import {acquireStoreItem} from '../src/store_item_acquisition.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-script-item-copy-observations.json',import.meta.url)));
const INVALID=0x7f000000;
test('CopyItem wrapper matches native optional pops, repeated casts, pointer mutation, placement and pushed status',async()=>{
 for(const row of data.rows.filter(r=>r.case.mode==='wrapper')){
  const c=row.case,trace=[],source={id:42,possessorId:c.possessor??INVALID},target={id:101},destination={id:c.id??43},existing={id:44};let popIndex=0,output;
  const cast=name=>o=>{trace.push(['cast',name]);return(name==='world'?c.world!==false:(c.kind??5)===({creature:5,placeable:9,item:6,store:14})[name])?o:null;};
  const acquire=(kind,o,ref,...args)=>{trace.push(['acquire',kind,...args]);if(kind!==14){if(c.mutation==='null')ref.item=null;else if(c.mutation==='existing')ref.item=existing;}return c.acquire??1;};
  const status=await scriptCopyItem(c.argc??3,{pop:type=>{trace.push(['pop',type]);const index=popIndex++;return{ok:index!==c.failPop,value:[42,c.targetId??101,c.variables??1][index]};},push:id=>{output=id;trace.push(['push',id]);return c.push??1;},
   item:id=>{trace.push(['item',id]);return c.source===false?null:source;},construct:()=>{trace.push(['allocate',0x470],['construct',INVALID]);return destination;},copy:(d,s,v)=>{trace.push(['copy',v]);return c.copy??1;},destroy:(o,n)=>trace.push(['destroy',o.id,n]),setPossessor:(o,...args)=>trace.push(['possessor',o.id,...args]),
   object:id=>{trace.push(['object',id]);return c.target===false?null:target;},asWorld:cast('world'),asCreature:cast('creature'),asPlaceable:cast('placeable'),asItem:cast('item'),asStore:cast('store'),
   position:o=>o===source?[1.25,-2.5,3.75]:[2.5,-5,7.5],area:o=>{trace.push(['area',o===source?'source':'target']);return c.area===false?null:{};},addToArea:(o,a,...args)=>trace.push(['addArea',o?.id??0,Number(Boolean(a)),...args]),
   acquireCreature:(...args)=>acquire(5,...args),acquirePlaceable:(...args)=>acquire(9,...args),acquireContainer:(...args)=>acquire(6,...args),acquireStore:(...args)=>acquire(14,...args)});
  assert.equal(status>>>0,row.result,JSON.stringify(c));assert.equal(output,row.output??undefined,JSON.stringify(c));assert.deepEqual(trace,row.trace,JSON.stringify(c));
 }
});
test('complete container acquisition matches original incoming-container rejection, source chains, fit/removal/mutation and possession',async()=>{
 for(const row of data.rows.filter(r=>r.case.mode==='container')){
  const c=row.case,trace=[],repo={},incoming={id:42,possessorId:c.possessor??INVALID,baseItem:49},container={id:101},old={id:102,objectType:c.old??0},bag={id:103,possessorId:c.bagParent??INVALID,baseItem:50},existing={id:44,possessorId:INVALID},ref={item:incoming};
  const repository=o=>o===container?(c.repo===false?null:repo):o===incoming?(c.incomingRepo?repo:null):o===old?(c.oldRepo===false?null:repo):null;
  const result=await acquireContainerItem(container,ref,c.sourceId??INVALID,c.x??255,c.y??255,c.feedback??1,{repository,itemById:id=>{trace.push(['item',id]);return c.bag?bag:null;},
   findPosition:(r,i,flag)=>{trace.push(['find',flag]);return(c.find??1)?{x:1,y:2}:null;},fit:(r,i,x,y)=>{trace.push(['fit',x,y]);return c.fit??1;},objectById:id=>{trace.push(['object',id]);return c.old?old:null;},
   removeCreatureItem:(o,i,...args)=>{trace.push(['cast','creature'],['removeCreature',o.id,i.id,...args]);},removePlaceableItem:(o,i,flag)=>{trace.push(['cast','placeable'],['removePlaceable',i.id,flag]);},removeRepositoryItem:(r,i)=>{trace.push(['cast','item']);if(c.oldRepo!==false)trace.push(['cast','item'],['removeRepo',i.id]);},
   baseInfo:i=>{trace.push(['base',i.baseItem]);return{container:i===incoming?c.container??0:c.bagContainer??0};},
   add:(r,ref,...args)=>{trace.push(['add',...args]);if(c.mutation==='null')ref.item=null;else if(c.mutation==='existing')ref.item=existing;return c.add??1;},removeFromArea:i=>trace.push(['removeArea',i.id]),setPossessor:(i,id,...args)=>{trace.push(['possessor',i.id,id,...args]);i.possessorId=id;}});
  // Native performs one item cast to inspect the previous repository, then a
  // second only for nonnull repositories. The JS canonical record needs no cast.
  if(c.old===6&&c.oldRepo===false&&trace.some(t=>t[0]==='object')){const index=trace.findIndex(t=>t[0]==='object');if(trace[index+1]?.[0]==='add')trace.splice(index+1,0,['cast','item']);}
  assert.equal(result>>>0,row.result,JSON.stringify(c));assert.equal(ref.item?.id??0,row.itemId,JSON.stringify(c));assert.equal(ref.item?.possessorId??null,row.possessor,JSON.stringify(c));assert.deepEqual(trace,row.trace,JSON.stringify(c));
 }
});
test('complete store acquisition matches native plot gate, owner resolution, infinite stock disposal and by-value pointer',async()=>{
 for(const row of data.rows.filter(r=>r.case.mode==='store')){
  const c=row.case,trace=[],store={id:101},item={id:42,plot:c.plot??0,possessorId:c.possessor??INVALID,baseItem:49,tag:'a'},old={id:102,possessorId:INVALID},parent={id:101},existing={id:44,nativeInfinite444:c.infinite??0};
  const result=await acquireStoreItem(store,c.null?null:item,c.flag??0,3,4,{identified:(i,n)=>trace.push(['identified',n]),object:id=>{trace.push(['object',id]);return c.old?old:null;},asCreature:o=>{trace.push(['cast','creature']);return c.old===5?o:null;},asItem:o=>{trace.push(['cast','item']);return c.old===6?o:null;},creature:id=>{trace.push(['creature',id]);return c.parent?parent:null;},
   removeCreatureItem:(o,i,...args)=>trace.push(['removeCreature',o.id,i.id,...args]),panel:(s,base)=>{trace.push(['panel',base]);return c.panel??2;},repository:()=>({}),findTag:()=>{trace.push(['findTag']);return 44;},item:id=>{trace.push(['item',id]);return c.existing?existing:null;},compare:()=>{trace.push(['compare']);return c.compare??1;},destroy:(i,n)=>trace.push(['destroy',i.id,n]),setPossessor:(i,id,...args)=>trace.push(['possessor',i.id,id,...args]),add:(s,ref,...args)=>{trace.push(['storeAdd',...args]);return c.add??1;}});
  assert.equal(result>>>0,row.result,JSON.stringify(c));assert.deepEqual(trace,row.trace,JSON.stringify(c));
 }
});
