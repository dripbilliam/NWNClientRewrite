import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {setClientPauseState,clearClientPauseExclusions,clientActiveTimer,clientPauseExcluded,receiveClientPauseMessage} from '../src/client_pause.js';
import {ClientPausePresentation} from '../src/client_pause_presentation.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-pause-observations.json',import.meta.url))),fields=['mode','fixedRate','counter','previousCounter','paused','pausedDay','pausedTime','dayOffset','timeOffset','minutesPerHour','dayLength','secondsPerDay'];
function fixture(c){
 const calls=[],objects=new Map([11,22,0xf0000001].map(id=>[id,{id,day:77,time:88}])),make=(name,i)=>({name,mode:i%2,fixedRate:30+i,counter:0x123456789abcdef0n+BigInt(i*1000),previousCounter:0x123456789abcdef0n+BigInt(i*1000)-100n,paused:i%2,pausedDay:100+i,pausedTime:200+i,dayOffset:300+i,timeOffset:400+i,minutesPerHour:5+i,dayLength:7200000+i,secondsPerDay:7200+i,time(){calls.push(['time',name]);const[day,time]={world:[10,100],one:[20,200],two:[30,300]}[name];return{day,time};}});
 const state={world:make('world',0),timer1:make('one',1),timer2:make('two',2),flags:c.flags??0,exclusions:c.nullList?null:[...(c.old??[11])],gui:c.gui===false?null:{},controlledId:c.controlledId??11,profileMode:c.profileMode??0},incoming=c.nullIncoming?null:{ids:[...(c.incoming??[])],disposed:false};
 const p={pause:t=>{calls.push(['pause',t.name]);t.paused=1;},unpause:t=>{calls.push(['unpause',t.name]);t.paused=0;},snapshot:t=>{calls.push(['snapshot',t.name]);t.previousCounter=t.counter;t.counter+=100n;},syncPrevious:t=>{calls.push(['sync',t.name]);t.previousCounter=t.counter;},reset:(t,from)=>{calls.push(['reset',t.name,from.name]);for(const key of fields)t[key]=from[key];},
  object:id=>{calls.push(['object',id]);return objects.get(id)??null;},resetObjectTimes:(o,day,time)=>{calls.push(['resetObject',o.id,day,time]);Object.assign(o,{day,time});},asObject:o=>{calls.push(['asObject',o.id]);return c.asObject===false?null:o;},scene:o=>{calls.push(['scene',o.id]);return c.scene===false?null:{};},sceneVirtual:(_scene,offset)=>calls.push(['sceneVirtual',offset]),
  pauseText:id=>calls.push(['pauseText',id]),audio:value=>{if(c.audio!==false)calls.push(['audio',value]);},disposeIncoming:o=>{calls.push(['dispose']);o.ids=[];o.disposed=true;},guiActive:()=>{calls.push(['guiActive']);return c.guiActive??1;},guiBlocked:(_gui,value)=>calls.push(['guiBlocked',value]),guiSetFlags:(_gui,value)=>calls.push(['guiSet',value]),guiClearFlags:(_gui,value)=>calls.push(['guiClear',value])};return{state,incoming,p,calls,objects};
}
const timers=s=>Object.fromEntries([s.world,s.timer1,s.timer2].map(t=>[t.name,Object.fromEntries(fields.map(k=>[k,typeof t[k]==='bigint'?String(t[k]):t[k]]))]));

test('client creature clock matches90 original bounded AI cases and reports undefined outputs instead of sampling seeded caller memory',()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-creature-clock-observations.json',import.meta.url)));assert.equal(data.rows.length,90);
 for(const row of data.rows){const c=row.case,reports=[],o={presentationTime:1000,nativeFrameDay50:c.previous[0],nativeFrameTime54:c.previous[1]},p=new ClientPausePresentation({session:()=>({scheduler:{time:0}}),report:(...a)=>reports.push(a)});p.state={world:{dayLength:1000,time:()=>({day:c.now[0],time:c.now[1]})},flags:0,exclusions:[]};p.objects={get:()=>o};const value=p.now(99);
  if(row.status===0){assert.equal(value,1000+row.elapsed);assert.equal(reports.length,0);}else{assert.equal(value,1000);assert.equal(row.elapsed,c.seedTime);assert.equal(row.outputTime,c.seedTime);assert.equal(row.outputDay,c.seedDay);assert.equal(reports.length,1);assert.equal(reports[0][0],'client.pause-clock-undefined');assert.equal(reports[0][2].status>>>0,row.status);}
  assert.deepEqual([o.nativeFrameDay50,o.nativeFrameTime54],c.now);
 }
});

test('client pause state, post-change old-list clearing, timer selection and creature reset match complete original code',()=>{
 assert.equal(capture.rows.length,759);
 for(const row of capture.rows){const c=row.case;if(c.mode==='receive')continue;const f=fixture(c),{state:s,p,incoming,calls,objects}=f;let result;
  if(c.mode==='set')setClientPauseState(s,c.mask,c.value,incoming,p);else if(c.mode==='clear')clearClientPauseExclusions(s,p);else if(c.mode==='timer')result=clientActiveTimer(s,c.id).name;else if(c.mode==='excluded')result=clientPauseExcluded(s,c.id);else if(c.mode==='reset'){const o=objects.get(11);p.resetObjectTimes(o,c.day,c.time);}
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(s.flags,row.flags);assert.deepEqual(s.exclusions,row.exclusions);assert.equal(Boolean(incoming?.disposed),row.disposed);assert.deepEqual(timers(s),row.timers,JSON.stringify(c));assert.deepEqual(Object.fromEntries([...objects].map(([id,o])=>[id,[o.day,o.time]])),row.stamps,JSON.stringify(c));if(result!==undefined)assert.equal(result,row.result,JSON.stringify(c));
 }
});

test('client module3/9 receiver matches original read order, allocation growth, overflow ownership and GUI refresh gates',()=>{
 for(const row of capture.rows){const c=row.case;if(c.mode!=='receive')continue;const calls=[],unconsumed=[];let index=0,owned;
  const result=receiveClientPauseMessage({allocateIncoming:o=>{owned=o;},byte:(...args)=>{calls.push(['byte',...args]);return c.mask;},bool:()=>{calls.push(['bool']);return c.value;},word:bits=>{calls.push(['word',bits]);return c.incoming.length;},objectId:()=>{calls.push(['objectId']);return c.incoming[index++];},overflow:()=>{calls.push(['overflow']);return c.overflow;},apply:(mask,value,o)=>calls.push(['apply',mask,value>>>0,[...o.ids]]),gui:()=>{calls.push(['gui']);return c.gui?{fieldA8:c.guiA8}:null;},refreshGui:()=>calls.push(['refreshGui']),unconsumedIncoming:(o,reason)=>unconsumed.push({o,reason})});
  assert.equal(result,row.result);assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(owned.disposed,false);assert.equal(row.disposed,false);assert.equal(row.allocated,true);assert.equal(unconsumed.length,1);assert.equal(unconsumed[0].o,owned);assert.equal(unconsumed[0].reason,c.overflow?'overflow':'unchanged-state');assert.equal(owned.capacity,c.incoming.length>16?32:c.incoming.length?16:0);
 }
});
