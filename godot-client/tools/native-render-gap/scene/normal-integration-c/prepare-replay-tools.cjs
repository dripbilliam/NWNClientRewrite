'use strict';
// Generates a new C version; frozen B replay tools are read-only inputs.
const fs=require('node:fs'),path=require('node:path'),base=path.join(__dirname,'../normal-integration');
function once(source,from,to){if(source.split(from).length!==2)throw Error('C replay tool seam changed '+from.slice(0,100));return source.replace(from,()=>to);}
function put(name,text){const file=path.join(__dirname,name),bytes=Buffer.isBuffer(text)?text:Buffer.from(text);if(fs.existsSync(file)){if(!fs.readFileSync(file).equals(bytes))throw Error('Existing C source tool differs '+name);return;}fs.writeFileSync(file,bytes,{flag:'wx'});}
for(const name of ['audit-case.cjs','audit-policy.cjs','watch-module-v4.ps1','parse-observer.ps1','run-replay.cjs'])put(name,fs.readFileSync(path.join(base,name)));
let text=fs.readFileSync(path.join(base,'prepare-replay.cjs'),'utf8');
text=once(text,"['baseline','candidate']","['control','candidate']");
text=once(text,"const manifestFile=path.join(project,'.cache/native-render-gap/scene/normal-integration-b/manifest.json')","const integrationLabel=route==='control'?'normal-integration-b':'normal-integration-c';\nconst manifestFile=path.join(project,'.cache/native-render-gap/scene',integrationLabel,'manifest.json')");
text=once(text,"const acceptanceFile=path.join(project,'.cache/native-render-gap/scene/normal-integration-b/checks-d/acceptance.json')","const acceptanceFile=path.join(project,'.cache/native-render-gap/scene',integrationLabel,route==='control'?'checks-d/acceptance.json':'functional-acceptance.json')");
text=once(text,"pins=candidate?m.pins:baseline.pins,origin=candidate?m.candidate:baseline.sourceProject","pins=m.pins,origin=m.candidate");text=once(text,' if(candidate){',' {');
text=text.replaceAll('private-normal-gameplay-replay','private-normal-full-bundle-replay');
text=text.replace('Private replay of exact normal resolver','Private replay of exact normal resolver');put('prepare-replay.cjs',text);
text=fs.readFileSync(path.join(base,'replay-adapter.cjs'),'utf8').replaceAll('private-normal-gameplay-replay','private-normal-full-bundle-replay');
text=once(text,"['baseline','candidate']","['control','candidate']");text=once(text,'const expectedPins=candidate?m.pins:base.pins;','const expectedPins=m.pins;');text=once(text,' if(candidate){\n  for(const p of m.overlays)',' {\n  for(const p of m.overlays)');
const begin=text.indexOf(' if(candidate){\n  if(c.performance.runtime'),end=text.indexOf(' if(s.particleLoop',begin);if(begin<0||end<0)throw Error('C bundle configuration seam absent');
text=text.slice(0,begin)+" if(c.performance.runtime!=='verified-native'||c.performance.renderThread!=='separate'||c.performance.requested['light-input-registry'].value!=='builtin'||c.renderCore?.typed!==true)throw Error('Normal selected route differs from accepted defaults');\n same(c.renderCore.flags,m.normal.renderCore.flags,'exact accepted functional bundle');\n"+text.slice(end);
text=once(text,"base.pins.find(p=>p.relative==='.cache/native-kernel/nwn-particle-kernel.dll')?.sha256","(m.nativeKernel?.sha256??base.pins.find(p=>p.relative==='.cache/native-kernel/nwn-particle-kernel.dll')?.sha256)");
const branch=text.indexOf(" if(s.normalIntegration.route==='candidate'){"),tail=text.indexOf(" return {status:errors.length?",branch);if(branch<0||tail<0)throw Error('C actual-use seam absent');
const oldBranch=text.slice(branch,tail);const body=oldBranch.slice(oldBranch.indexOf('{')+1,oldBranch.lastIndexOf('}'));
text=text.slice(0,branch)+" if(s.normalIntegration.route==='candidate'){\n  const bundle=helper.verifyAcceptedBundleUse(s.performanceOptions.renderCore,n?.accepted_render_bundle,{requireBusyUse:true});Object.assign(features,bundle.features);errors.push(...bundle.errors);\n }else{"+body+" }\n"+text.slice(tail);put('replay-adapter.cjs',text);
text=fs.readFileSync(path.join(base,'check-replays.cjs'),'utf8');
const missing="  if(selection.normalIntegration.route==='candidate')for(const name of ['typed','pairReuse','lightFilter']){assert.equal(missing.features[name],false);checks.push('Missing actual accepted use rejects '+name);}";
text=once(text,missing,"  if(selection.normalIntegration.route==='candidate'){assert(missing.errors.some(message=>message.includes('bundle evidence is missing')));checks.push('Missing full12-route cold evidence rejects');}");put('check-replays.cjs',text);
console.log(JSON.stringify({generated:8,scope:'Fresh C replay tools only; no B/main edits or game launch'}));
