import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {addRepositoryMoveAction,executeRepositoryMove,receiveRepositoryMoveInput,clearRepositoryMoveAction} from '../src/repository_move.js';
import {createObjectAction,createObjectActionState} from '../src/object_actions.js';
import {repositoryMove} from '../src/item_repository.js';
import {receivePlaceableInventoryDisturbance} from '../src/inventory_disturbance.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-repository-move-observations.json',import.meta.url))),INVALID=0x7f000000;
test('full repository transfer matches original ownership/casts/curses/repositories/rollback/GUI/messages and encumbrance ordering',async()=>{
 for(const row of data.rows){const c=row.case,calls=[],actor={id:99,role:'actor',objectType:5,associateType:c.associateType??0,masterId:c.master??INVALID},item={id:100,role:'item',objectType:6,possessorId:c.possessor??300,baseItem:7,cursed:c.cursed??0,stackSize:7,repositoryX:2,repositoryY:3},bag={id:200,role:'bag',objectType:6,baseItem:8,possessorId:c.bagOwner??99},placeable={id:300,role:'placeable',objectType:9},other={id:101,role:'other',objectType:5},outside={id:102,role:'outside',objectType:5},objects=new Map([actor,item,bag,placeable,other,outside].map(o=>[o.id,o])),repos=Object.fromEntries(['actor','bag','placeable','other','outside'].map(role=>[role,{role}])),primary={ownerId:c.primaryOwner??INVALID,field8:c.openFlag??1,fieldC:c.currentPage??0},alternate={ownerId:c.alternateOwner??101,field8:c.openFlag??1,fieldC:c.currentPage??0};
  const node=createObjectAction(13,0);node.parameterTypes.set([3,3,6,6]);node.parameterData.splice(0,4,100,c.destination??INVALID,c.x??4,c.y??5);let addIndex=0;
  const p={controlled:id=>{calls.push(['controlled',id]);return c.controlled??1;},associatesCanInteract:()=>{calls.push(['associates']);return c.associates??1;},dead:()=>{calls.push(['dead']);return c.dead??0;},dying:()=>{calls.push(['dying']);return c.dying??0;},activityManager:(_o,n)=>calls.push(['activityManager',n]),message:()=>{calls.push(['message']);return c.message===false?null:{};},client:id=>{calls.push(['client',id]);return c.client===false?null:{};},dm:()=>{calls.push(['dm']);return c.dm??0;},item:id=>{calls.push(['item',id]);return c.item===false?null:item;},object:id=>{calls.push(['object',id]);return c.missing?.includes(id)?null:objects.get(id)??null;},creature:id=>{calls.push(['creature',id]);return objects.get(id)??null;},
   asItem:o=>{calls.push(['asItem',o.role]);return o.objectType===6?o:null;},asCreature:o=>{calls.push(['asCreature',o.role]);return o.objectType===5?o:null;},asPlaceable:o=>{calls.push(['asPlaceable',o.role]);return o.objectType===9?o:null;},primary:()=>primary,alternate:()=>alternate,repository:o=>c.nullRepos?.includes(o.role)?null:repos[o.role],
   baseInfo:o=>{calls.push(['baseInfo',o.baseItem]);return{container:o===item?c.container??0:c.bagContainer??1};},contains:(r,o,n)=>{calls.push(['contains',r.role,o.role,n]);return c.contains??1;},move:(r,o,x,y)=>{calls.push(['move',r.role,x,y]);if(c.move===0)return 0;o.repositoryX=x;o.repositoryY=y;return c.move??1;},playerCharacter:()=>{calls.push(['playerCharacter']);return c.pc??1;},closeItem:(o,...args)=>calls.push(['closeItem',o.role,...args]),remove:(r,o)=>{calls.push(['remove',r.role,o.role]);return c.remove??1;},
   addItem:(r,ref,x,y,unused,merge)=>{calls.push(['addItem',r.role,x,y,unused,merge]);addIndex++;const result=addIndex===1?c.add??1:c.restore??1;if(result){if(c.nullItem&&addIndex===1)ref.item=null;else{ref.item.repositoryX=c.resultX??x;ref.item.repositoryY=c.resultY??y;}}return result;},
   setPossessor:(o,newId,...args)=>{calls.push(['setPossessor',o.role,newId,...args]);o.possessorId=newId;},page:(_r,x,y)=>{calls.push(['page',x,y]);return c.page??2;},selectPanelMessage:(_c,page)=>calls.push(['selectPanelMessage',page]),setPanel:(g,_c,page)=>{calls.push(['setPanel',g===primary?'primary':'alternate',page]);g.fieldC=page;},moved:(_c,...args)=>calls.push(['moved',...args]),cancel:(_c,...args)=>calls.push(['cancel',...args]),encumbrance:(o,n)=>calls.push(['encumbrance',o.role,n]),feedback:(_o,n)=>calls.push(['feedback',n])};
  const result=await executeRepositoryMove(actor,node,p),label=JSON.stringify(c);assert.equal(result,row.result,label);assert.deepEqual(calls,row.calls,label);assert.equal(item.possessorId,row.possessor,label);assert.deepEqual([item.repositoryX,item.repositoryY],row.coords,label);assert.deepEqual([primary.fieldC,alternate.fieldC],row.panels,label);
 }
});
test('repository move request matches commandability, canonical item ID, BYTE coordinates and ignored queue return',()=>{
 for(const row of data.requests){const c=row.case,actor={nativeFieldEc:c.commandable,objectActionState:createObjectActionState()},result=addRepositoryMoveAction(actor,{id:100},c.destination,c.x,c.y),calls=[];
  for(const node of actor.objectActionState.list)calls.push(['queue',node.actionId,65535,Array.from({length:node.parameterCount},(_,n)=>[node.parameterTypes[n],node.parameterData[n]])]);assert.equal(result,row.result);assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
});
test('full inventory message subtype9 matches decoded reads, repeated control lookup, casts, action management and rejection',async()=>{
 for(const row of data.inputs){const c=row.case,calls=[],actor={role:'actor'},item={role:'item'};let overflow=0,oids=0,bytes=0;
  const result=await receiveRepositoryMoveInput({}, {overflow:()=>{calls.push(['overflow']);return Number(++overflow===c.overflow);},underflow:()=>{calls.push(['underflow']);return c.underflow??0;},readObjectId:()=>{calls.push(['readObjectId']);return ++oids===1?100:c.destination??INVALID;},readByte:()=>{calls.push(['readByte']);return ++bytes===1?c.x??4:c.y??5;},clientObject:()=>{calls.push(['clientObject']);return c.clientObject===false?null:actor;},asCreature:o=>{calls.push(['asCreature',o.role]);return c.cast===false?null:o;},lookup:id=>{calls.push(['lookup',id]);return{status:c.status??0,object:item};},asItem:o=>{calls.push(['asItem',o.role]);return c.cast===false?null:o;},actionManager:(_o,n)=>calls.push(['actionManager',n]),add:(o,i,...args)=>{calls.push(['add',o.role,i.role,...args]);return c.add??1;},message:()=>calls.push(['message']),cancel:(_c,...args)=>calls.push(['cancel',...args])});
  assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
});
test('repository action cancellation matches native optional cancel message before shared lock/time cleanup',async()=>{
 for(const row of data.clears){const c=row.case,calls=[],actor={id:99,lockOrientationId:c.lock,objectActionState:{startDay:10,startTime:2345}},node=createObjectAction(13,0);node.nativeField9c=c.ready;node.parameterTypes[0]=3;node.parameterData[0]=100;
  const result=await clearRepositoryMoveAction(actor,node,c.head,{message:()=>{calls.push(['message']);return c.message?{}:null;},client:id=>{calls.push(['client',id]);return c.client?{}:null;},cancel:(_c,...args)=>calls.push(['cancel',...args]),setLock:(o,id)=>{calls.push(['lock',id]);o.lockOrientationId=id;}});
  assert.equal(result,row.result);assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(actor.lockOrientationId,row.lock);assert.deepEqual([actor.objectActionState.startDay,actor.objectActionState.startTime],row.start);
 }
});
test('repository cell movement matches original per-node lookup, identity, fit, BYTE coordinates and retained membership',()=>{
 for(const row of data.cells){const c=row.case,calls=[],item={repositoryX:2,repositoryY:3},bag={},ids=[...c.ids],repo={*ids(){yield*ids;}};
  const result=repositoryMove(repo,c.nullItem?null:item,c.x,c.y??5,{lookup:id=>{calls.push(['lookup',id]);return{status:c.status,object:c.nullLookup?null:id===100?item:bag};},fit:(_r,_i,x,y)=>{calls.push(['fit',x,y]);return c.fit;}});
  assert.equal(result,row.result);assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual([item.repositoryX,item.repositoryY],row.coords);assert.deepEqual(ids,c.ids);
 }
});
test('placeable disturbance matches original script27 history and callback without creature hostility mutation',async()=>{
 for(const row of data.disturbs){const c=row.case,calls=[],object={};await receivePlaceableInventoryDisturbance(object,c.caller,{type:27},{integer:(_e,n)=>{calls.push(['integer',n]);return c.integer;},objectId:(_e,n)=>{calls.push(['objectId',n]);return c.eventObject;},runEventScript:(_o,...args)=>calls.push(['runEventScript',...args])});
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual([object.nativeLastDisturbed19c,object.nativeDisturbItem1b0,object.nativeDisturbType1b4],row.disturbed);
 }
});
