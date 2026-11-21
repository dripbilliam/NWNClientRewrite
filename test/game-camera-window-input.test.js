import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {GameCameraInput,cameraPointerDelta} from '../src/game_camera_input.js';

// Execute the production main.js gate: importing main itself requires the full
// renderer and installed game. This catches reintroducing viewer/menu gating.
const main=fs.readFileSync(new URL('../src/main.js',import.meta.url),'utf8');
const expression=main.match(/const gameplayCameraInputEnabled=(.*);/)[1];
function fixture(){
 const context={characterFrontend:{active:false},gameUi:{blocksWorldInput:false},moduleSession:null,moduleLoadBusy:false,rendererWarmupCount:0,networkPresentation:{closed:false,graphicsPending:false},networkFrontend:{phase:'playing'},controls:{enabled:false},networkInventory:{active:true},networkDialog:{active:true},networkPanels:{active:true},radialMenu:{active:false}};
 const enabled=vm.runInNewContext(expression,context),canvas=new EventTarget(),window=new EventTarget(),inputs=[],captures=[];
 canvas.getBoundingClientRect=()=>({width:1920});canvas.setPointerCapture=id=>captures.push(id);
 const descriptor=Object.getOwnPropertyDescriptor(globalThis,'window');Object.defineProperty(globalThis,'window',{configurable:true,value:window});
 const input=new GameCameraInput(canvas,{active:()=>true,enabled,controller:()=>({input:value=>inputs.push(value)})});
 const send=(name,properties={})=>{const event=new Event(name,{cancelable:true});Object.assign(event,{pointerId:7,button:1,clientX:100,clientY:100,...properties});canvas.dispatchEvent(event);return event;};
 return{context,enabled,input,inputs,captures,send,restore:()=>{if(descriptor)Object.defineProperty(globalThis,'window',descriptor);else delete globalThis.window;}};
}

test('middle drag rotates over the canvas with multiple windows open and viewer orbit disabled',()=>{
 const f=fixture();try{
  assert.equal(f.enabled(),true);assert.equal(f.send('pointerdown').defaultPrevented,true);assert.deepEqual(f.captures,[7]);
  f.send('pointermove',{clientX:140,clientY:120});assert.deepEqual(f.inputs,[cameraPointerDelta(40,20,1920)]);
  f.send('pointerup');f.send('pointermove',{clientX:160});assert.equal(f.inputs.length,1);
 }finally{f.restore();}
});

test('opening a floating window during a middle drag does not interrupt camera rotation',()=>{
 const f=fixture();try{
  f.context.controls.enabled=true;f.context.networkInventory.active=false;f.send('pointerdown');
  f.context.controls.enabled=false;f.context.networkInventory.active=true;f.input.update();f.send('pointermove',{clientX:130});assert.equal(f.inputs.length,1);
 }finally{f.restore();}
});

test('creation, loading, transition, cutscene and disconnected world states still block camera input',()=>{
 const states=[{characterFrontend:{active:true}},{gameUi:{blocksWorldInput:true}},{moduleSession:{player:{cutscene:{enabled:true}}}},{moduleSession:{transitioning:true}},{moduleLoadBusy:true},{rendererWarmupCount:1},{networkPresentation:{closed:true}},{networkPresentation:{graphicsPending:true}},{networkFrontend:{phase:'connecting'}}];
 for(const state of states){const f=fixture();try{Object.assign(f.context,state);assert.equal(f.enabled(),false,JSON.stringify(state));f.send('pointerdown');f.send('pointermove',{clientX:130});assert.equal(f.input.drag,null);assert.equal(f.inputs.length,0);}finally{f.restore();}}
});

test('left and right mouse buttons do not start camera rotation',()=>{
 const f=fixture();try{for(const button of [0,2]){f.send('pointerdown',{button});f.send('pointermove',{clientX:130});assert.equal(f.input.drag,null);}assert.equal(f.inputs.length,0);}finally{f.restore();}
});
