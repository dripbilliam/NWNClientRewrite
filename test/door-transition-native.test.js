import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {scriptStringToFloat} from '../src/script_string.js';
import {scriptAngleToVector} from '../src/script_scalar.js';
import {addObjectDoorAction,scriptDoorAction,executeObjectDoorAction} from '../src/door_actions.js';
import {createObjectActionState,actionParameter,addObjectAction} from '../src/object_actions.js';
import {ModuleSession} from '../src/module_session.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const captured=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-door-queue-observations.json',import.meta.url)));
test('door queue records and groups match16 original-instruction observations',()=>{
  for(const row of captured.queue){const actor={nativeFieldEc:row.commandable,objectActionState:createObjectActionState()};actor.objectActionState.nextGroup=row.initialGroup;
    assert.equal(addObjectDoorAction(actor,0xf1234567,-2,row.open),row.result);assert.equal(actor.objectActionState.nextGroup,row.nextGroup);
    const node=actor.objectActionState.list.head?.action;if(row.result){assert.equal(node.actionId,row.action);assert.equal(node.groupId,row.group);assert.equal(actionParameter(node,0),row.target);assert.equal(actionParameter(node,1),row.run);}else assert.equal(node,undefined);
  }
});
test('script door command requires area and exact-one commandability only for opening',()=>{
  const a={nativeFieldEc:2,objectActionState:createObjectActionState()},p={area:()=>({})};scriptDoorAction(a,1,0,true,p);assert.equal(a.objectActionState.list.count,0);
  scriptDoorAction(a,1,0,false,p);assert.equal(a.objectActionState.list.count,1);a.nativeFieldEc=1;scriptDoorAction(a,2,1,true,p);assert.equal(a.objectActionState.list.count,2);
  scriptDoorAction(a,3,0,false,{area:()=>null});assert.equal(a.objectActionState.list.count,2);
});
test('float conversion matches Windows C-locale CRT provider including prefix parsing and float rounding',()=>{
  for(const row of captured.cLocaleFloatProvider){const value=scriptStringToFloat(row.text),buf=Buffer.alloc(4);buf.writeFloatLE(value);
    if(row.double==='nan')assert.ok(Number.isNaN(value));else assert.equal(buf.toString('hex'),row.float32LE,row.text);
  }
  assert.equal(scriptStringToFloat('2.5\0e8'),2.5);assert.equal(scriptStringToFloat('\u00a01.5'),0);assert.equal(scriptStringToFloat('1e-50'),0);assert.ok(Object.is(scriptStringToFloat('-1e-50'),-0));
});
test('AngleToVector uses native single-precision radian conversion and native XYZ',()=>{
  assert.deepEqual(scriptAngleToVector(0),[1,0,0]);
  assert.deepEqual(scriptAngleToVector(90),[-4.371138828673793e-8,1,0]);
  assert.deepEqual(scriptAngleToVector(-90),[-4.371138828673793e-8,-1,0]);
  assert.throws(()=>scriptAngleToVector(Infinity),/Native/);
});
test('base-object open/close actions defer state and push same-group half-second wait',async()=>{
  const a={id:0xf1234567,objectType:10,nativeFieldEc:1,objectActionState:createObjectActionState()},target={id:2},events=[];
  for(const open of [true,false]){a.objectActionState=createObjectActionState();addObjectDoorAction(a,target.id,0,open);const node=a.objectActionState.list.shift();
    assert.equal(await executeObjectDoorAction(a,node,{dead:()=>0,dying:()=>0,object:()=>target,enqueue:(...args)=>events.push(args)}),2);
    const wait=a.objectActionState.list.head.action;assert.equal(wait.actionId,30);assert.equal(wait.groupId,node.groupId);assert.equal(actionParameter(wait,0),.5);
  }
  assert.deepEqual(events,[[7,a.id,target.id],[6,a.id,target.id]]);
});
test('door event mirrors state to linked door before running only source callback with original caller',async()=>{
  const s=new ModuleSession({}, {runStartupScripts:false,runNativeAI:false}),area=s.register('area','area',{resRef:'area'}),a=s.register('door','a',{areaId:area.id,position:[0,0,0],bearing:0,linkedTo:'B',linkedToFlags:1,scripts:{open:'open',closed:'closed'}}),b=s.register('door','b',{areaId:area.id,position:[2,0,0],tag:'B'}),caller=s.register('door','caller',{areaId:area.id,position:[0,0,-1]}),calls=[];
  s.program=async n=>n;s.vm={run:async(...args)=>calls.push({args,a:a.animationState,b:b.animationState})};
  // This coordinator fixture isolates paired events; full native map/budge
  // lower owners have their own original-code comparisons.
  area.nativeGeometry={objects:{load:async()=>{}}};s.lifecycle.budgeCreatures=async()=>{};s.automap.updatePlayersInArea=async()=>{};
  a.orientation=[0,0,-1];
  await s.receiveDoorUseEvent(a,caller.id,true);assert.equal(a.animationState,1);assert.equal(a.nativeAnimationD8,50);assert.equal(a.eventObjects.opened,caller.id);assert.equal(b.animationState,1);assert.equal(b.eventObjects.opened,undefined);
  await s.receiveDoorUseEvent(a,OBJECT_INVALID,false);assert.equal(a.animationState,0);assert.equal(a.eventObjects.closed,OBJECT_INVALID);
  await s.receiveDoorUseEvent(a,OBJECT_INVALID,true);assert.equal(a.animationState,2);
  assert.deepEqual(calls.map(c=>[c.args[0],c.args[1],c.args[2].scriptEventContext,c.a,c.b]),[['open',a.id,10000,1,1],['closed',a.id,10001,0,0],['open',a.id,10000,2,2]]);
  a.nativeDoorField498=0;await s.receiveDoorUseEvent(a,caller.id,false);assert.equal(a.animationState,3);assert.equal(a.nativeAnimationD8,72);
});
test('door constructor registers canonical ID in AI level0 and shared frame drains captured situations',async()=>{
  const s=new ModuleSession({}, {runStartupScripts:false,runNativeAI:false}),area=s.register('area','area',{}),door=s.register('door','door',{areaId:area.id,authored:{CurrentHP:10}}),calls=[];
  assert.equal(door.nativeAILevel7c,0);assert.ok(s.aiMaster.levels[0].view().includes(door.id));
  addObjectAction(door.objectActionState,37,65535,[{type:5,value:{program:{},stack:[]}}]);s.runSituation=async(_s,id)=>calls.push(id);
  await s.updateWorldObject(door,0);assert.deepEqual(calls,[door.id]);assert.equal(door.objectActionState.list.count,0);
});
