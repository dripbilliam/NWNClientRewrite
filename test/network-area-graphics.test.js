import test from 'node:test';import assert from 'node:assert/strict';
import {startNetworkAreaGraphics} from '../src/network_area_graphics.js';import {RendererResourceRetirement} from '../src/renderer_resource_retirement.js';import {NetworkFrontend} from '../src/network_frontend.js';import {NetworkWorld} from '../src/network_world.js';
const gate=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return{promise,resolve,reject};};
const area={kind:'client-area',position:[0,0,0],facing:0,area:{id:0x80000001,resRef:'fixture',width:1,height:1,mapPins:[],sounds:[],placeableLights:[],staticPlaceables:[],time:{}}};
test('production frontend imports queued objects during GPU work and acknowledges only completed graphics',async()=>{
 const resources=gate(),graphics=gate(),owner={},events=[],errors=[],retirement=new RendererResourceRetirement();
 const frontend={id:'session',phase:'area-loading',queue:Promise.resolve(),world:new NetworkWorld(),bridge:{areaReady:async(id,generation)=>events.push(['ack',id,generation])},
  onArea:async()=>{await resources.promise;return{graphics:startNetworkAreaGraphics(owner,{prepare:()=>graphics.promise,current:()=>true,complete:()=>events.push(['graphics']),failed:e=>errors.push(e),retirement,ended:()=>events.push(['ended'])})};},
  onUpdates:()=>events.push(['objects']),showError:e=>errors.push(e)};
 NetworkFrontend.prototype.receive.call(frontend,{kind:'message',sessionId:'session',areaGeneration:1,message:area});
 NetworkFrontend.prototype.receive.call(frontend,{kind:'message',sessionId:'session',message:{kind:'object-updates',records:[{action:'create',id:0xffffffff,objectType:5,state:{position:[2,3,0]}}]}});
 await Promise.resolve();assert.deepEqual(events,[]);resources.resolve();await frontend.queue;
 assert.deepEqual(events,[['objects']]);assert.deepEqual(frontend.world.registry.get(0xffffffff).replicated.position,[2,3,0]);assert.equal(owner.graphicsPending,true);
 let disposed=false;retirement.retire(()=>disposed=true);assert.equal(disposed,false);graphics.resolve();await frontend.areaAdmissionWork;assert.equal(owner.graphicsPending,false);assert.equal(disposed,true);assert.deepEqual(errors,[]);assert.deepEqual(events.slice(-3),[['graphics'],['ended'],['ack','session',1]]);
});
test('superseded area retains polled resources but cannot publish into the new area',async()=>{
 const graphics=gate(),owner={},retirement=new RendererResourceRetirement(),events=[];let current=true;
 const work=startNetworkAreaGraphics(owner,{prepare:()=>graphics.promise,current:()=>current,complete:()=>events.push('complete'),failed:()=>events.push('failed'),retirement,ended:()=>events.push('ended')});await Promise.resolve();
 owner.closed=true;current=false;owner.cancelGraphics();retirement.retire(()=>events.push('dispose'));assert.deepEqual(events,['ended']);assert.equal(retirement.holds,1);graphics.resolve();await work;assert.deepEqual(events,['ended','dispose']);assert.equal(retirement.holds,0);
});
test('graphics rejection diagnoses the current owner and always releases its rendering gate',async()=>{
 const owner={},retirement=new RendererResourceRetirement(),events=[];
 await startNetworkAreaGraphics(owner,{prepare:async()=>{throw Error('link failed');},current:()=>true,complete:()=>events.push('complete'),failed:e=>events.push(e.message),retirement,ended:()=>events.push('ended')});assert.deepEqual(events,['link failed','ended']);assert.equal(owner.graphicsPending,false);assert.equal(retirement.holds,0);
});
test('already superseded owners start no compiler and cleanup rejection still releases retention',async()=>{
 const retirement=new RendererResourceRetirement();let prepared=0,ended=0;
 await startNetworkAreaGraphics({closed:true},{prepare:()=>prepared++,current:()=>true,complete:()=>{},failed:()=>{},retirement,ended:()=>ended++});assert.equal(prepared,0);assert.equal(ended,1);
 await assert.rejects(startNetworkAreaGraphics({},{prepare:async()=>{throw Error('link');},current:()=>true,complete:()=>{},failed:async()=>{throw Error('cleanup');},retirement,ended:()=>ended++}),/cleanup/);assert.equal(retirement.holds,0);assert.equal(ended,2);
});

test('frontend never acknowledges failed, cancelled or superseded graphics',async()=>{
 for(const outcome of ['false','reject','new-area','new-session']){
  const graphics=gate(),events=[],errors=[];
  const frontend={id:'session',phase:'area-loading',queue:Promise.resolve(),world:new NetworkWorld(),
   bridge:{areaReady:async(...args)=>events.push(args)},onArea:async()=>({graphics:graphics.promise}),showError:e=>errors.push(e.message)};
  NetworkFrontend.prototype.receive.call(frontend,{kind:'message',sessionId:'session',areaGeneration:1,message:area});
  await frontend.queue;
  if(outcome==='new-area'){frontend.areaGeneration=2;frontend.world.areaId=area.area.id+1;}
  if(outcome==='new-session')frontend.id='replacement-session';
  if(outcome==='reject')graphics.reject(Error('link failed'));else graphics.resolve(outcome!=='false');
  await frontend.areaAdmissionWork;
  assert.deepEqual(events,[],outcome);assert.deepEqual(errors,outcome==='reject'?['link failed']:[],outcome);
 }
});
