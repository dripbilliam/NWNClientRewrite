import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {scriptMoveAwayObject,scriptMoveAwayLocation,executeMoveAway} from '../src/move_away.js';
import {createObjectActionState,createObjectAction,addObjectAction,setActionParameter} from '../src/object_actions.js';
import {clearCreatureMovementAction} from '../src/combat_lifecycle.js';
import {ModuleSession} from '../src/module_session.js';
import {parse2da} from '../src/area.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-move-away-observations.json',import.meta.url))),f=Math.fround;
const bits=value=>{const d=new DataView(new ArrayBuffer(4));d.setFloat32(0,value,true);return d.getInt32(0,true);};
const view=n=>({id:n.actionId,group:n.groupId,types:[...n.parameterTypes].slice(0,n.parameterCount),values:n.parameterData.slice(0,n.parameterCount)});
function fixture(c){
 const state=createObjectActionState();state.nextGroup=17;state.lastGroup=42;
 for(const[id,group,target]of c.queue??[])addObjectAction(state,id,group,[{type:3,value:target}]);
 const actor={id:99,objectType:c.creature===false?6:5,nativeFieldEc:c.commandable??1,objectActionState:state,lockOrientationId:c.lock??0x7f000000,nativePathInfo:c.path===false?null:{}},target={id:100},area={id:88},otherArea={id:89},calls=[];
 const p={dead:()=>{calls.push(['dead']);return c.dead??0;},dying:()=>{calls.push(['dying']);return c.dying??0;},position:o=>(o===actor?c.origin??[0,0,0]:c.threat??[1,0,0]).map(f),area:o=>{calls.push(['area',o===actor?'actor':'target']);return o===actor?c.sameArea===false?otherArea:area:c.targetArea===false?null:area;},areaById:id=>{calls.push(['areaById',id]);return c.areaExists===false?null:area;},object:id=>{calls.push(['lookup',id]);return c.targetExists===false?null:target;},
  cancel:(_o,id,group)=>{calls.push(['cancel',id,group]);for(let link=state.list.head;link;){const next=link.next;if(link.action.groupId===group)state.list.remove(link);link=next;}return 1;},
  away:(_area,from,to,distance,path)=>{calls.push(['away',from,to,distance,path===actor.nativePathInfo&&path!==null]);return c.away??[7.25,-8.5,9.75];},
  moveBack:(_o,...args)=>{calls.push(['moveBack',...args]);state.lastGroup=state.nextGroup++;},moveFront:(_o,...args)=>calls.push(['moveFront',...args]),waitFront:(_o,group)=>calls.push(['waitFront',group]),messageAvailable:()=>c.message!==false,setLock:(_o,id)=>calls.push(['unlock',id])};
 const id=c.mode==='object'?3:c.mode==='location'?44:c.actionId??3,node=createObjectAction(id,9);node.nativeField9c=c.interruptible??1;
 const params=id===3?[[3,100],[1,c.run??0],[2,bits(c.distance??40)],[1,c.retries??10]]:[...(c.threat??[1,0,0]).map(v=>[2,bits(v)]),[1,c.run??0],[2,bits(c.distance??40)],[1,c.retries??10]];params.forEach(([t,v],i)=>setActionParameter(node,i,t,v));state.startDay=7;state.startTime=88;return{actor,target,state,node,p,calls};
}

test('complete native object/location flee action gates, duplicate-group cancellation, retry placement and move/wait order match',async()=>{
 assert.equal(data.rows.length,904);
 for(const row of data.rows){const c=row.case;if(!['object','location'].includes(c.mode))continue;const{actor,node,state,p,calls}=fixture(c);assert.equal(await executeMoveAway(actor,node,p),row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual([...state.list].map(view),row.queue,JSON.stringify(c));}
});

test('decoded move-away VM commands preserve native defaults, commandability differences, radius boundary and queue parameter ownership',async()=>{
 for(const row of data.rows){const c=row.case;if(!['objectCommand','locationCommand'].includes(c.mode))continue;
  if(c.failPop){assert.equal(row.result,(-639)>>>0);assert.deepEqual(row.queue,[]);continue;}
  const{actor,target,state,p,calls}=fixture(c),self=c.actorExists===false?null:actor,argc=c.argc??3,run=argc>1?c.run??0:0,distance=argc>2?c.distance??40:40;
  if(c.mode==='objectCommand')scriptMoveAwayObject(self,c.targetExists===false?null:target,run,distance);
  else await scriptMoveAwayLocation(self,{position:(c.threat??[1,0,0]).map(f),areaId:88},run,distance,p);
  const expected=row.calls.filter(c=>!['pop','lookup','creature','disposeLocation'].includes(c[0]));assert.deepEqual(calls,expected,JSON.stringify(c));assert.deepEqual([...state.list].map(view),row.queue,JSON.stringify(c));assert.equal(row.result,0);assert.equal(row.disposed,c.mode==='locationCommand');
 }
});

test('move-away actions use the original shared cancellation tail and Turned is the native kind4 state constructor',async()=>{
 const s=new ModuleSession(null);
 for(const row of data.rows){const c=row.case;
  if(c.mode==='turned'){const e=s.commands.EffectTurned([],{self:99});assert.deepEqual({type:e.type,subtype:e.subtype,durationType:e.durationType,integers:e.integers,creatorId:e.creatorId},row.output);}
  else if(c.mode==='clear'){const{actor,state,node,p,calls}=fixture(c);assert.equal(await clearCreatureMovementAction(actor,node,c.head,p),row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls);assert.deepEqual([state.startDay,state.startTime],row.stamp);}
 }
});

test('bounded native state-script bodies select active physical SCRIPTNAME rows including byte narrowing and forced associate row7',async()=>{
 for(const row of data.rows){const c=row.case;if(!['control','control7'].includes(c.mode))continue;const calls=[],s=new ModuleSession(null),actor={id:99,nativeFieldEc:1},index=c.mode==='control7'?7:c.state,table=parse2da('2DA V2.0\n\nSCRIPTNAME\n'+Array.from({length:256},(_,i)=>`${i} ${i===index?(c.script||'****'):'unselected_script'}`).join('\n'));
  s.items.table=async name=>{assert.equal(name,'statescripts');return table;};s.runScript=async(name,id)=>{calls.push(['table',index,'SCRIPTNAME'],['script',name,id,1,0]);actor.nativeFieldEc=c.scriptCommandable;};await s.combat.runControlScript(actor,index);
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(row.commandable,0,'Native caller restores commandability after the script, separately covered by heartbeat integration');
 }
});
