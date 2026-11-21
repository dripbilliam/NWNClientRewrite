'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../../../..'),source=path.join(__dirname,'../light-dictionary-read'),target=path.join(__dirname,'../light-pgo-regressions-a'),sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');if(fs.existsSync(target))throw Error('Fresh immutable PGO runner directory required');fs.mkdirSync(target);
const pins=[],copies=[];for(const name of ['fixture.gd','typed-error.gd','run-fixture.cjs','run-typed-error.cjs','run-regressions.cjs']){
 const file=path.join(source,name),bytes=fs.readFileSync(file);pins.push({file,sha256:sha(bytes)});let after=bytes;
 if(name.endsWith('.cjs')){
  let text=bytes.toString().replaceAll('build-1794150996725','build-1794159304324').replaceAll('6a9cedaf6bc3c00cd61cbdafff22aecebc4709f9a1eeae577e6314705dff4d07','30a114cadd5c431e4e3357295cba7147c5ffd066cf2d53d84a5c95385026a9ae');
  if(name==='run-fixture.cjs')text=text.replace("??'light-dictionary-functional-a'","??'light-pgo-dictionary-functional-a'");
  if(name==='run-typed-error.cjs')text=text.replace("scene/light-dictionary-typed-error-a'","scene/light-pgo-dictionary-typed-error-a'");
  if(name==='run-regressions.cjs')text=text.replace("scene/light-dictionary-regressions-a'","scene/light-pgo-dictionary-regressions-a'");
  assert(!text.includes('build-1794150996725'));after=Buffer.from(text);
 }
 const output=path.join(target,name);fs.writeFileSync(output,after,{flag:'wx'});copies.push({file:output,sha256:sha(after),original:file,originalSha256:sha(bytes)});
}
const manifest={version:1,created:new Date().toISOString(),kind:'immutable-pgo-light-regression-runner-copies',sourcePins:pins,copies,engineRelative:'.cache/native-render-gap/engine/build-1794159304324/godot.windows.template_release.x86_64.exe',engineSha256:'30a114cadd5c431e4e3357295cba7147c5ffd066cf2d53d84a5c95385026a9ae',commands:copies.filter(row=>row.file.endsWith('.cjs')).map(row=>['node',row.file]),expectedExecutions:1046,scope:'Source-only preparation. Original used D runners and frozen projects remain untouched. Same actual Dictionary/typed-error/canonical/segment/legacy tests, changed only pinned engine identity and fresh output labels.'};fs.writeFileSync(path.join(target,'manifest.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({target,copies:copies.length,expectedExecutions:1046,sourceOnly:true}));
