import test from 'node:test';
import assert from 'node:assert/strict';
import {verifyProductionReplayWindow} from '../tools/native_parity/performance/replay_display.mjs';
const selection={screen:2,primary:0};
const view={screen:2,primary_screen:0,unfocusable:true,focused:false,mouse_mode:0};
const fixture=()=>({startup_window:{screen:2,primary:0,non_activating:true},performance_window:{view_begin:{...view},view_end:{...view}}});
test('production requires actual matching begin and end display/focus/cursor observations',()=>{
 assert.equal(verifyProductionReplayWindow(fixture(),selection).status,'observed');
 for(const field of ['view_begin','view_end'])for(const [key,value] of [['screen',0],['primary_screen',2],['unfocusable',false],['focused',true],['mouse_mode',2]]){
  const native=fixture();native.performance_window[field][key]=value;
  assert.equal(verifyProductionReplayWindow(native,selection).status,'rejected',field+'.'+key);
 }
});
test('missing production evidence cannot be supplied by legacy perf140 or final settings',()=>{
 for(const field of ['view_begin','view_end']){const native=fixture();delete native.performance_window[field];native.perf140_view_end={...view};native.runtime_features={presentation:{...view}};assert.equal(verifyProductionReplayWindow(native,selection).status,'rejected');}
 assert.equal(verifyProductionReplayWindow(fixture(),null).status,'rejected');
 const native=fixture();native.startup_window.non_activating=false;assert.equal(verifyProductionReplayWindow(native,selection).status,'rejected');
});
