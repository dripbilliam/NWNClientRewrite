const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const helper=require('../tools/native-production-selection.cjs'),root=path.resolve(__dirname,'../.cache/native-presentation-parity/continuous-streaming-agent/production-selection-v2'),seeds=JSON.parse(fs.readFileSync(path.join(root,'preference-seeds-b.json'),'utf8')),hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
test('explicit immutable fixture has common reviewed values and no implicit live source',()=>{const r=helper.preferenceSeeds(seeds);assert.equal(r.expected.gamma,1.2);assert.equal(r.expected.particles,true);assert.equal(r.rows.render.sha256,'86b14987edc38ab177436df5c159cb9c68402b8ea72d0defbafc88b08fd87c9f');assert.equal(r.rows.layout.sha256,'4c696a5b4ae9a152790b9cc383e790f1a18c9a15924a2f64ac70b4f65de1f491');});
for(const input of [null,{}, {...seeds,expected:{particles:true}}, {...seeds,expected:{gamma:NaN,particles:true}}, {...seeds,expected:{gamma:-1,particles:true}}, {...seeds,expected:{gamma:1.2,particles:'true'}}])test('unavailable/malformed fixture values reject',()=>assert.throws(()=>helper.preferenceSeeds(input),/Explicit/));
test('changed seed rejects by exact SHA',()=>{const bad=structuredClone(seeds);bad.render.sha256='0'.repeat(64);assert.throws(()=>helper.preferenceSeeds(bad),/changed/);});
test('V1 is retained as historical read format, but cannot start uncontrolled replay',()=>assert.throws(()=>helper.validateProductionReplayOptions({version:1},()=>undefined),/V3/));
test('working files are detached and immutable seeds remain fenced',()=>{
 const dir=path.join(root,'unit-'+Date.now());fs.mkdirSync(path.join(dir,'project'),{recursive:true});fs.mkdirSync(path.join(dir,'preference-seeds'));
 const prefs={version:1,expected:structuredClone(seeds.expected)};
 for(const name of ['render','layout']){const bytes=fs.readFileSync(seeds[name].file),relative='preference-seeds/'+name+'.cfg';fs.writeFileSync(path.join(dir,relative),bytes);prefs[name]={relative,sha256:hash(bytes),bytes:bytes.length};}
 const selection={version:2,sourceProject:path.join(dir,'project'),preferences:prefs};helper.validatePreferencePins(selection);
 const working=helper.createPreferenceWorkingCopies(selection,path.join(dir,'owned-userdata'));assert.equal(working.render.initialSha256,prefs.render.sha256);assert.equal(working.layout.initialSha256,prefs.layout.sha256);assert.notEqual(working.render.file,path.join(dir,prefs.render.relative));
 fs.appendFileSync(working.render.file,'\n# owned runtime save\n');helper.validatePreferencePins(selection);assert.notEqual(hash(fs.readFileSync(working.render.file)),prefs.render.sha256);
 assert.throws(()=>helper.createPreferenceWorkingCopies(selection,working.directory),/Fresh/);
 const layout=path.join(dir,prefs.layout.relative),before=fs.readFileSync(layout);fs.appendFileSync(layout,'# changed immutable seed\n');assert.throws(()=>helper.validatePreferencePins(selection),/changed/);fs.writeFileSync(layout,before);helper.validatePreferencePins(selection);
});
test('actual paths/gamma/particle owner/viewport are required, not file readback',()=>{
 const selection={renderConfiguration:{},preferences:{expected:{gamma:1.2,particles:true}}},working={render:{file:'C:/owned/render.cfg'},layout:{file:'C:/owned/layout.cfg'}};
 const presentation={settings:{preference_path:working.render.file,menu_layout_path:working.layout.file,gamma:1.2,particles_enabled:true},gamma:{gamma:1.2},particle_visibility:{enabled:false,collision_enabled:true},viewport:[3440,1369]};
 const expected={viewport:[3440,1369],particles:false,particleCollision:true};
 assert.equal(helper.verifyPreferenceObservation(selection,working,presentation,expected).status,'observed');
 for(const field of ['settings','particle_visibility','viewport']){const missing=structuredClone(presentation);delete missing[field];assert.equal(helper.verifyPreferenceObservation(selection,working,missing,expected).status,'rejected');}
 const live=structuredClone(presentation);live.settings.preference_path='user://native-options.cfg';assert.equal(helper.verifyPreferenceObservation(selection,working,live,expected).status,'rejected');
 const gamma=structuredClone(presentation);gamma.gamma.gamma=2.2;assert.equal(helper.verifyPreferenceObservation(selection,working,gamma,expected).status,'rejected');
 const missingEffect=structuredClone(presentation);delete missingEffect.gamma;assert.equal(helper.verifyPreferenceObservation(selection,working,missingEffect,expected).status,'rejected');assert.equal(helper.verifyPreferenceObservation(selection,working,missingEffect,{...expected,headless:true}).status,'observed');
});
