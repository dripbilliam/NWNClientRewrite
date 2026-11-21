// Assert the actual local controlled poses; preserve residual pauses as data.
import fs from 'node:fs/promises';import assert from 'node:assert/strict';
const root=new URL('../backups/animations/',import.meta.url),capture=name=>{if(!/^creation-performance-[a-z0-9-]+\.json$/.test(name))throw Error('Invalid local contact report name');return new URL(name,root);},report=JSON.parse(await fs.readFile(capture(process.argv[2]??'creation-performance-drive-slide-live-v2.json'),'utf8'));
assert.equal(report.failure,undefined);assert.deepEqual(report.rendererErrors,[]);assert.ok(report.states.some(s=>s.phase==='playing'));
assert.equal(report.diagnostics.some(d=>/drive-preview|drive-animation|scene-facing|game-message-invalid/.test(d.code)),false);
assert.deepEqual(report.samples.at(-1).failed,[]);assert.equal(report.samples.at(-1).controlled.rendered,true);
const contact=report.contact,data=contact.keyboard,distance=(a,b)=>Math.hypot(...a.map((v,i)=>v-b[i]));
assert.ok(distance(contact.before.position,contact.target)<.05);
const sections=data.sections.map(section=>{
 const frames=data.frames.filter(f=>f.at>=section.start+350&&f.at<section.end),expected=section.code==='KeyQ'?78:79;assert.ok(frames.length>100);
 const facingDelta=Math.max(...frames.map(f=>distance(f.orientation,frames[0].orientation)));assert.ok(facingDelta<1e-5);assert.ok(distance(frames[0].position,frames.at(-1).position)>1);
 const movingWithIdle=frames.filter(f=>f.active&&f.held&&f.preview&&f.visualAnimation!==expected);assert.equal(movingWithIdle.length,0);
 const heldIdle=frames.filter(f=>f.held&&f.preview&&f.visualAnimation!==expected);
 const pauses=[];let pause=null;
 for(let i=1;i<frames.length;i++){
  if(distance(frames[i].position,frames[i-1].position)<=1e-5){pause??={start:frames[i-1].at,end:frames[i].at,frames:0};pause.end=frames[i].at;pause.frames++;}
  else if(pause){pauses.push(pause);pause=null;}
 }if(pause)pauses.push(pause);
 return{...section,facingDelta,movingWithIdle:0,heldIdleFrames:heldIdle.length,heldIdleClips:[...new Set(heldIdle.map(f=>f.clip))],start:frames[0].position,end:frames.at(-1).position,pauses,largestPauseMs:Math.max(0,...pauses.map(p=>p.end-p.start))};
});
const partial=data.previews.filter(p=>p.path?.resendFraction!==undefined),slides=data.previews.filter(p=>p.path?.factor<1);assert.ok(partial.length>=4);assert.ok(slides.length>=2);
const final=data.frames.at(-1),canonical=data.server.at(-1);assert.ok(distance(final.position,canonical.position)<.05);
const proof={scope:contact.scope,endpoint:'127.0.0.1:5121',module:'Prelude',target:contact.target,heading:contact.heading,before:contact.before,sections,continuousHeldAnimation:sections.every(s=>s.heldIdleFrames===0),partialRefreshes:partial,slidePaths:slides,final:{rendered:final.position,canonical:canonical.position},rendererErrors:0,
 limits:'Normal walk/turn plus renderer keyboard events on the owned vanilla server. The test proves the fallback and adjusted timer execute, facing stays fixed and active paths restore walking playback. Remaining short partial-replan pauses are explicitly recorded; no flawless-motion or complete native collision/ghost/bump parity claim. The earlier strict failed keyboard run remains rejected.'};
await fs.writeFile(capture(process.argv[3]??'creation-performance-drive-contact-proof-v1.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({sections:sections.map(s=>({code:s.code,frames:s.frames,stationary:s.stationarySteps,heldIdleFrames:s.heldIdleFrames,largestPauseMs:s.largestPauseMs})),continuousHeldAnimation:proof.continuousHeldAnimation,partialRefreshes:partial.length,slides:slides.length,errors:0}));
