import test from 'node:test';import assert from 'node:assert/strict';import {ShaderChunk,EventDispatcher} from 'three';import {conservativePointLightWork,RendererZeroLightWork} from '../src/renderer_zero_light_work.js';
function fixture(){
 const calls=[],program={},other={},gl={CURRENT_PROGRAM:1,current:null,lost:false,isContextLost(){return this.lost;},getParameter(){return this.current;},isProgram:p=>p===program||p===other};
 const uniforms={map:{nwnSkipZeroLightWork:{}},setValue:(_gl,name,value)=>calls.push([name,value])},compiled={program,getUniforms:()=>uniforms},renderer={state:{useProgram:p=>{gl.current=p;return true;}},info:{programs:[compiled]},getContext:()=>gl,domElement:new EventDispatcher()},chunks={lights_fragment_begin:ShaderChunk.lights_fragment_begin,lights_pars_begin:ShaderChunk.lights_pars_begin};
 const before={fragment:chunks.lights_fragment_begin,pars:chunks.lights_pars_begin,use:renderer.state.useProgram},owner=new RendererZeroLightWork(renderer,chunks);return {calls,program,other,gl,uniforms,compiled,renderer,chunks,before,owner};
}
test('zero-work guard retains point shading and constant shadow sampler indices',()=>{const original=ShaderChunk.lights_fragment_begin,result=conservativePointLightWork(original);assert.ok(result.fragment.includes('if(nwnPointHasWork(pointLight,geometryPosition))'));assert.ok(result.fragment.includes('getPointShadow( pointShadowMap[ i ]'));assert.ok(result.fragment.includes('RE_Direct( directLight'));assert.ok(result.helper.includes('light.distance*1.0001+0.0001'));assert.ok(result.helper.includes('isnan'));assert.throws(()=>conservativePointLightWork('changed'),/changed/);});
test('program flags upload once per change and disposal returns compiled shaders to ordinary math',()=>{
 const f=fixture();f.renderer.state.useProgram(f.program);f.renderer.state.useProgram(f.program);f.owner.enabled=true;f.renderer.state.useProgram(f.program);assert.deepEqual(f.calls,[['nwnSkipZeroLightWork',0],['nwnSkipZeroLightWork',1]]);
 f.renderer.state.useProgram(f.other);f.owner.dispose();assert.deepEqual(f.calls.at(-1),['nwnSkipZeroLightWork',0]);assert.equal(f.gl.current,f.other);assert.equal(f.chunks.lights_fragment_begin,f.before.fragment);assert.equal(f.chunks.lights_pars_begin,f.before.pars);assert.equal(f.renderer.state.useProgram,f.before.use);assert.equal(f.owner.programs.size,0);
});
test('ordinary programs are cached without uniform writes and retired handles are dropped',()=>{
 const f=fixture();f.renderer.info.programs.push({program:f.other,getUniforms:()=>({map:{},setValue:()=>assert.fail('ordinary program changed')})});f.renderer.state.useProgram(f.other);f.renderer.state.useProgram(f.other);assert.deepEqual(f.calls,[]);f.renderer.info.programs=[];assert.equal(f.owner.snapshot().programs,0);f.owner.dispose();
});
test('context loss forgets stale handles and disposal avoids invalid GL access',()=>{
 const f=fixture();f.owner.enabled=true;f.renderer.state.useProgram(f.program);f.gl.lost=true;f.renderer.domElement.dispatchEvent({type:'webglcontextlost'});assert.equal(f.owner.programs.size,0);f.gl.getParameter=()=>assert.fail('lost context queried');f.owner.dispose();assert.equal(f.chunks.lights_fragment_begin,f.before.fragment);
});
test('later program hooks and chunk replacements remain owned by their producers',()=>{
 const f=fixture(),later=()=>{};f.renderer.state.useProgram=later;f.chunks.lights_fragment_begin='later';f.chunks.lights_pars_begin='later pars';f.owner.dispose();assert.equal(f.renderer.state.useProgram,later);assert.equal(f.chunks.lights_fragment_begin,'later');assert.equal(f.chunks.lights_pars_begin,'later pars');
});
test('nested installations reject before changing shader chunks',()=>{
 const f=fixture(),fragment=f.chunks.lights_fragment_begin;assert.throws(()=>new RendererZeroLightWork(f.renderer,f.chunks),/already installed/);assert.equal(f.chunks.lights_fragment_begin,fragment);f.owner.dispose();
});
test('restored contexts bind the replacement state owner and dispose idempotently',()=>{
 const f=fixture();f.owner.enabled=true;f.renderer.state.useProgram(f.program);f.renderer.domElement.dispatchEvent({type:'webglcontextlost'});assert.equal(f.renderer.state.useProgram,f.before.use);let uses=0;const replacement=p=>{uses++;f.gl.current=p;return true;};f.renderer.state={useProgram:replacement};f.renderer.domElement.dispatchEvent({type:'webglcontextrestored'});f.renderer.state.useProgram(f.program);assert.equal(uses,1);assert.deepEqual(f.calls.at(-1),['nwnSkipZeroLightWork',1]);f.owner.dispose();assert.equal(f.renderer.state.useProgram,replacement);const count=f.calls.length;f.owner.dispose();assert.equal(f.calls.length,count);
});
