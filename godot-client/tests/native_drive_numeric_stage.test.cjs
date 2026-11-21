'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'..');
const {readPrivateStage}=require('../tools/native-drive-numeric/prepare-private-stage.cjs');
const {sourceIdentity}=require('../tools/native-feature-manifest.cjs');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function fixture(sidecar=false){
 const parent=path.join(project,'.cache/native-drive-numeric/stage-verifier-tests');fs.mkdirSync(parent,{recursive:true});
 const dir=fs.mkdtempSync(path.join(parent,'case-')),sourceProject=path.join(dir,'project');fs.mkdirSync(sourceProject);
 const value={version:1,kind:'private-drive-numeric-stage',production:false,complete:true,sourceProject,originalProject:project,sidecar,expectedModule:null,pins:[]};
 const baseBytes=Buffer.from('{}');fs.writeFileSync(path.join(dir,'base-selection-before-overlay.json'),baseBytes);value.baseSelectionSha256=hash(baseBytes);
 const put=(relative,bytes)=>{const file=path.join(sourceProject,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);value.pins=value.pins.filter(row=>row.relative!==relative);value.pins.push({relative,sha256:hash(bytes)});};
 put('project.godot','; synthetic verifier fixture, never launched\n');
 const extensions=['res://native/particle_kernel.gdextension','res://native/resource_index.gdextension'];
 if(sidecar){put('native/drive_numeric/private.gdextension','; synthetic descriptor, never loaded');put('native/drive_numeric/nwn-drive-numeric.dll','synthetic non-executable fixture');extensions.push('res://native/drive_numeric/private.gdextension');value.expectedModule={file:path.join(sourceProject,'native/drive_numeric/nwn-drive-numeric.dll'),sha256:value.pins.at(-1).sha256,descriptor:extensions.at(-1)};}
 put('.godot/extension_list.cfg',extensions.join('\n')+'\n');
 const executable=path.join(dir,'synthetic-engine.bin');fs.writeFileSync(executable,'non-executable pin fixture');value.engine={executable,executableSha256:hash(fs.readFileSync(executable))};
 value.stagedSource=sourceIdentity(sourceProject).sha256;
 const file=path.join(dir,'private-stage.json');
 const read=()=>{fs.writeFileSync(file,JSON.stringify(value));return readPrivateStage(file,hash(fs.readFileSync(file)));};
 return {value,put,read,file};
}
test('private stage independently pins native module and complete source closure',()=>{
 for(const sidecar of [false,true]){const f=fixture(sidecar);assert.equal(f.read().sidecar,sidecar);}
});
test('changed source, native bytes and engine reject before launch',()=>{
 const f=fixture(true);f.read();fs.appendFileSync(path.join(f.value.sourceProject,'native/drive_numeric/nwn-drive-numeric.dll'),'changed');assert.throws(f.read,/Pin differs/);
 const source=fixture();source.put('project.godot','changed even with updated file pin');assert.throws(source.read,/staged source differs/);
 const engine=fixture();fs.appendFileSync(engine.value.engine.executable,'changed');assert.throws(engine.read,/Pin differs/);
});
test('unlisted or duplicate active extensions cannot hide behind a valid receipt pin',()=>{
 const f=fixture(true);f.put('.godot/extension_list.cfg','res://native/particle_kernel.gdextension\nres://native/resource_index.gdextension\nres://native/drive_numeric/private.gdextension\nres://unreviewed.gdextension\n');assert.throws(f.read,/active extension list differs/);
 const duplicate=fixture();duplicate.value.pins.push({...duplicate.value.pins[0]});assert.throws(duplicate.read,/Duplicate/);
});
test('module must reside at its pinned stage location and absent control contains no sidecar',()=>{
 const f=fixture(true);f.value.expectedModule.file=f.value.engine.executable;assert.throws(f.read,/module path differs/);
 const absent=fixture();absent.put('native/drive_numeric/nwn-drive-numeric.dll','unexpected');assert.throws(absent.read,/Absent-class control contains/);
});
test('missing module pins, path traversal and production claims reject',()=>{
 const missing=fixture(true);missing.value.pins=missing.value.pins.filter(row=>!row.relative.endsWith('.dll'));assert.throws(missing.read,/missing from complete pins/);
 const traversal=fixture();traversal.value.pins.push({relative:'../outside',sha256:'0'.repeat(64)});assert.throws(traversal.read,/escapes owned root/);
 const production=fixture();production.value.production=true;assert.throws(production.read,/policy differs/);
});
test('receipt hash is mandatory and checked independently',()=>{
 const f=fixture();f.read();assert.throws(()=>readPrivateStage(f.file,'0'.repeat(64)),/Pin differs/);
});
