import test from 'node:test';
import assert from 'node:assert/strict';
import {DataTexture} from 'three';
import {FrameWorkBudget} from '../src/frame_work_budget.js';
import {RendererTexturePreparation} from '../src/renderer_texture_preparation.js';
const texture=()=>{const t=new DataTexture(new Uint8Array([1,2,3,255]),1,1);t.needsUpdate=true;return t;};
function fixture(){let callback;const calls=[],work=new FrameWorkBudget({clock:()=>0,schedule:fn=>(callback=fn,1),cancel:()=>{callback=null;}}),owner=new RendererTexturePreparation({initTexture:t=>calls.push(t)},work);return{owner,work,calls,frame:()=>{const fn=callback;callback=null;fn();}};}

test('equal textures coalesce, completed versions reuse, and source changes upload again without changing source ownership',async()=>{
 const f=fixture(),t=texture(),data=t.image.data,first=f.owner.prepare([t,t]),second=f.owner.prepare([t]);f.frame();await Promise.all([first,second]);assert.equal(f.calls.length,1);await f.owner.prepare([t]);assert.equal(f.calls.length,1);t.image.data[0]=7;t.needsUpdate=true;const update=f.owner.prepare([t]);await update;assert.equal(f.calls.length,2);assert.equal(t.image.data,data);assert.equal(t.image.data[0],7);assert.equal(f.owner.snapshot().uploaded,2);
});

test('texture callbacks and render targets keep ordinary first-draw initialization, including changes while queued',async()=>{
 const f=fixture(),t=texture();t.onUpdate=()=>{};await f.owner.prepare([t]);assert.equal(f.calls.length,0);t.onUpdate=null;const queued=f.owner.prepare([t]);t.onUpdate=()=>{};f.frame();await queued;assert.equal(f.calls.length,0);t.onUpdate=null;const next=f.owner.prepare([t]);await next;assert.equal(f.calls.length,1);
});

test('cancelled areas never upload queued textures or dispose images belonging to producers',async()=>{
 const f=fixture(),t=texture();let disposals=0;t.addEventListener('dispose',()=>disposals++);const pending=f.owner.prepare([t]),handled=assert.rejects(pending,{code:'FRAME_WORK_CLOSED'});f.work.dispose();await handled;assert.equal(f.calls.length,0);assert.equal(disposals,0);assert.equal(f.work.snapshot().queued,0);
});
