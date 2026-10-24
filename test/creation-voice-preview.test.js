import test from 'node:test';
import assert from 'node:assert/strict';
import {CreationVoicePreview} from '../src/creation_voice_preview.js';
function ssf(){const b=new ArrayBuffer(40+49*24),v=new DataView(b),u=new Uint8Array(b);u.set(new TextEncoder().encode('SSF V1.0'));v.setUint32(8,49,true);v.setUint32(12,40,true);for(let i=0;i<49;i++){const p=40+49*4+i*20;v.setUint32(40+i*4,p,true);u.set(new TextEncoder().encode('sample'+i),p);}return b;}
test('creation samples cycle native codes0..48 and reset for a different soundset',async()=>{
 const events=[],audio={unlock(){},async play(e){events.push(e);},dispose(){this.disposed=true;}},res={getResource:async()=>ssf()},p=new CreationVoicePreview(res,{audioFactory:()=>audio});
 for(let i=0;i<51;i++)await p.play(7,'set');assert.deepEqual(events.map(e=>e.resRef),Array.from({length:51},(_,i)=>'sample'+i%49));await p.play(9,'other');assert.equal(events.at(-1).resRef,'sample0');assert.equal(events.at(-1).nativeSource.positional,false);p.dispose();assert.equal(audio.disposed,true);assert.equal(await p.play(9,'other'),false);
});
test('closing during SSF IO cannot start a stale preview',async()=>{
 let resolve,played=0;const p=new CreationVoicePreview({getResource:()=>new Promise(r=>resolve=r)},{audioFactory:()=>({unlock(){},async play(){played++;},dispose(){}})});const pending=p.play(0,'set');p.dispose();resolve(ssf());assert.equal(await pending,false);assert.equal(played,0);
});
