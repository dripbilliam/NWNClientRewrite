const fs=require('node:fs'),assert=require('node:assert/strict'),path=require('node:path');
const root=path.resolve(__dirname,'..'),capture=path.join(root,'backups/animations')+path.sep;
const localPath=(value,fallback)=>{const target=path.resolve(root,value??fallback);if(!target.toLowerCase().startsWith(capture.toLowerCase())||!target.endsWith('.json'))throw Error('Keyboard proof must remain in the capture directory');return target;};
const report=JSON.parse(fs.readFileSync(localPath(process.argv[2],'backups/animations/creation-experience-local-keyboard-live-v2.json'))),data=report.keyboardSmooth;
assert.equal(report.failure,undefined);assert.deepEqual(report.rendererErrors,[]);assert.ok(report.states.some(s=>s.phase==='playing'));
assert.equal(report.diagnostics.some(d=>/drive-preview|drive-animation|scene-facing|game-message-invalid/.test(d.code)),false);
const animations={KeyW:4,KeyS:3,KeyQ:78,KeyE:79};
const sections=data.sections.map(section=>{
 const frames=data.frames.filter(f=>f.at>=section.start+350&&f.at<section.end);assert.ok(frames.length>20);
 if(animations[section.code]!==undefined){assert.equal(section.stationarySteps,0);assert.equal(section.previewFrames,section.frames);assert.ok(frames.every(f=>f.animation===animations[section.code]));assert.ok(frames.every(f=>Math.hypot(...f.orientation.map((v,i)=>v-frames[0].orientation[i]))<1e-5));}
 else{assert.equal(section.movingSteps,0);assert.ok(Math.hypot(...frames[0].orientation.map((v,i)=>v-frames.at(-1).orientation[i]))>.2);}
 return{...section,animations:[...new Set(frames.map(f=>f.animation))]};
});
const proof={scope:report.scope,startedAt:report.startedAt,endpoint:'127.0.0.1:5121',module:'Prelude',sections,rendererErrors:0,movementDiagnostics:0,otherDiagnostics:report.diagnostics.map(d=>({code:d.code,major:d.major,minor:d.minor})),limits:'Finite renderer key events and controlled poses; does not establish full wall-sliding/ghosting/bump parity or a physical-key original-client comparison.'};
fs.writeFileSync(localPath(process.argv[3],'backups/animations/creation-experience-local-keyboard-proof-v1.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({ok:true,sections:sections.length,movingFrames:sections.filter(s=>animations[s.code]!==undefined).reduce((n,s)=>n+s.frames,0),stationaryTranslationSteps:0}));
