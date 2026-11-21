import test from 'node:test';import assert from 'node:assert/strict';import {auditReplayDrawGPU} from '../performance-candidates/replay-draw-gpu-audit.mjs';
function fixture(){
 const queries=new Set(),timer={TIME_ELAPSED_EXT:1,GPU_DISJOINT_EXT:2};let current=null,target=null,draws=0;
 const gl={NO_ERROR:0,CURRENT_QUERY:3,QUERY_RESULT_AVAILABLE:4,QUERY_RESULT:5,getExtension:name=>name==='EXT_disjoint_timer_query_webgl2'?timer:null,getError:()=>0,getQuery:()=>current,getParameter:()=>false,createQuery(){const q={};queries.add(q);return q;},deleteQuery:q=>queries.delete(q),beginQuery(_t,q){assert.equal(current,null);current=q;},endQuery(){assert.ok(current);current=null;},getQueryParameter:(_q,key)=>key===4?true:250000,drawArrays(){draws++;},drawElements(){draws++;}},renderer={getContext:()=>gl,getRenderTarget:()=>target};
 const draw=()=>{target={};gl.drawElements();target=null;gl.drawArrays();};return{gl,renderer,draw,queries,get draws(){return draws;}};
}
test('raw draw windows exclude intervening CPU time and retain separate main/offscreen counts',async()=>{const f=fixture(),before=f.gl.drawArrays,r=await auditReplayDrawGPU(f);assert.equal(r.queries,2);assert.equal(r.sumDrawWindowsMs,.5);assert.equal(r.groups['main:drawArrays'].calls,1);assert.equal(r.groups['offscreen:drawElements'].calls,1);assert.equal(f.draws,4);assert.equal(f.gl.drawArrays,before);assert.equal(f.queries.size,0);});
test('draw failures, allocation overflow and timeout always retire queries and restore hooks',async()=>{
 for(const mode of ['draw','capacity','deadline']){const f=fixture(),before=f.gl.drawArrays;let calls=0;if(mode==='draw'){const draw=f.draw;f.draw=()=>{draw();if(++calls===2)throw Error('source failure');};}if(mode==='capacity')f.maxQueries=1;if(mode==='deadline'){f.gl.getQueryParameter=()=>false;let t=0;f.now=()=>t++;f.deadlineMs=0;}
  await assert.rejects(auditReplayDrawGPU(f));assert.equal(f.gl.drawArrays,before);assert.equal(f.queries.size,0);
 }
});
test('disjoint and unavailable timers never manufacture a GPU duration',async()=>{const f=fixture();f.gl.getParameter=()=>true;const r=await auditReplayDrawGPU(f);assert.equal(r.sumDrawWindowsMs,null);assert.equal(r.groups['main:drawArrays'].ms,null);f.gl.getExtension=()=>null;assert.deepEqual(await auditReplayDrawGPU(f),{available:false});});
