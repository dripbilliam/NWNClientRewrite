const {test}=require('node:test');
const assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const {resolveNativeRenderConfiguration:resolve}=require('./native-render-configuration.cjs');
const select=(args={},env={},isolated=false)=>resolve({arg:name=>args[name],env,isolated});
test('Normal gameplay keeps the user-validated lighting chain and shared particles together',()=>{
 const config=select();
 assert.deepEqual(config.arguments,['--native-lighting=enhanced','--native-light-history','--native-max-lights=32','--native-surface-output=true','--native-postprocess-mask=28','--native-postprocess-midpoint=0.4','--native-postprocess-intensity=0.15','--native-postprocess-vibrance=0.7']);
 assert.deepEqual(config.environment,{NWN_PARTICLE_PRESENTATION:'shared',NWN_PARTICLE_LIGHTING:'pooled'});
 assert.equal(config.summary.profile,'gameplay');assert.equal(config.summary.selection,'normal gameplay');
 assert.equal(config.summary.engine,'godot-forward-plus');
});
test('An explicit shared-particle inspection no longer loses normal lighting',()=>{
 const config=select({'particle-presentation':'shared','particle-lighting':'pooled'});
 assert.deepEqual(config.arguments,select().arguments);assert.equal(config.summary.profile,'gameplay');
});
test('Isolated historical checks retain their declared baseline; this is not gameplay acceptance',()=>{
 const config=select({}, {}, true);
 assert.deepEqual(config.arguments,[]);assert.equal(config.summary.profile,'legacy');assert.equal(config.summary.selection,'isolated check');
 assert.deepEqual(config.environment,{NWN_PARTICLE_PRESENTATION:'individual',NWN_PARTICLE_LIGHTING:'scene'});
});
test('Explicit gameplay also works for a local/headless check',()=>{
 assert.deepEqual(select({'render-profile':'gameplay'}, {}, true).arguments,select().arguments);
 assert.equal(select({'render-profile':'gameplay'}, {}, true).summary.selection,'explicit');
});
test('Explicit rollback is complete even when its parent uses shared particles',()=>{
 const parent={NWN_PARTICLE_PRESENTATION:'shared',NWN_PARTICLE_LIGHTING:'pooled'};
 const config=select({'render-profile':'legacy'},parent);
 const child=spawnSync(process.execPath,['-e','process.stdout.write(JSON.stringify([process.env.NWN_PARTICLE_PRESENTATION,process.env.NWN_PARTICLE_LIGHTING,process.argv.slice(1)]))',...config.arguments],{env:{...process.env,...parent,...config.environment},encoding:'utf8',windowsHide:true});
 assert.equal(child.status,0,child.stderr);assert.deepEqual(JSON.parse(child.stdout),['individual','scene',[]]);
});
test('An explicit gameplay profile overrides stale inherited legacy lighting flags',()=>{
 const config=select({'render-profile':'gameplay'}, {NWN_NATIVE_LIGHTING:'godot',NWN_NATIVE_LIGHT_HISTORY:'0',NWN_NATIVE_SURFACE_OUTPUT:'false',NWN_PARTICLE_PRESENTATION:'individual',NWN_PARTICLE_LIGHTING:'scene'});
 assert.deepEqual(config.arguments,select().arguments);assert.deepEqual(config.environment,select().environment);assert.equal(config.summary.profile,'gameplay');
});
test('Normal child process receives all three lighting arguments and both particle choices',()=>{
 const config=select();
 const child=spawnSync(process.execPath,['-e','process.stdout.write(JSON.stringify([process.argv.slice(1),process.env.NWN_PARTICLE_PRESENTATION,process.env.NWN_PARTICLE_LIGHTING]))','--',...config.arguments],{env:{...process.env,...config.environment},encoding:'utf8',windowsHide:true});
 assert.equal(child.status,0,child.stderr);assert.deepEqual(JSON.parse(child.stdout),[config.arguments,'shared','pooled']);
});
test('Previous explicit enhanced-only research is preserved and labelled custom',()=>{
 const config=select({'native-lighting':'enhanced'});
 assert.deepEqual(config.arguments,['--native-lighting=enhanced']);assert.equal(config.summary.profile,'custom');
 assert.equal(config.summary.surface_output,false);assert.equal(config.summary.selection,'lighting overrides');
});
test('Historical full-scene research keeps its original gamma-only tonal inputs',()=>{
 const config=select({}, {NWN_NATIVE_LIGHTING:'enhanced',NWN_NATIVE_LIGHT_HISTORY:'1',NWN_NATIVE_SURFACE_OUTPUT:'true',NWN_PARTICLE_PRESENTATION:'shared',NWN_PARTICLE_LIGHTING:'pooled'});
 assert.deepEqual(config.arguments,['--native-lighting=enhanced','--native-light-history','--native-max-lights=32','--native-surface-output=true']);assert.deepEqual(config.environment,select().environment);assert.equal(config.summary.postprocess.mask,16);
});
test('Explicit command arguments keep precedence over historical environment flags',()=>{
 const config=select({'native-lighting':'enhanced','native-light-history':'1','native-surface-output':'true'}, {NWN_NATIVE_LIGHTING:'godot',NWN_NATIVE_LIGHT_HISTORY:'0',NWN_NATIVE_SURFACE_OUTPUT:'false'});
 assert.deepEqual(config.arguments,['--native-lighting=enhanced','--native-light-history','--native-max-lights=32','--native-surface-output=true']);assert.equal(config.summary.light_history,true);assert.equal(config.summary.surface_output,true);
});
test('Tonal options and gamma are forwarded without inventing a brightness override',()=>{
 assert.equal(select().summary.gamma,undefined);
 const config=select({'render-profile':'gameplay','native-postprocess-mask':'28','native-postprocess-intensity':'.35','native-gamma':'2.4'}, {NWN_NATIVE_POSTPROCESS_MIDPOINT:'.4',NWN_NATIVE_POSTPROCESS_VIBRANCE:'.7'});
 for(const arg of ['--native-postprocess-mask=28','--native-postprocess-midpoint=0.4','--native-postprocess-intensity=0.35','--native-postprocess-vibrance=0.7','--native-gamma=2.4'])assert.ok(config.arguments.includes(arg));
 assert.equal(config.summary.gamma,2.4);
 assert.deepEqual(select().summary.postprocess,{mask:28,midpoint:.4,intensity:.15,vibrance:.7});
});
test('Incompatible lighting combinations fail explicitly instead of quietly selecting a dark fallback',()=>{
 for(const args of [{'render-profile':'gameplay','native-lighting':'godot'},{'native-light-history':'1'},{'native-lighting':'enhanced','native-surface-output':'true'}])assert.throws(()=>select(args),/requires enhanced lighting/);
});
test('Invalid profiles, particle modes and gamma are rejected before spawning an engine',()=>{
 assert.throws(()=>select({'render-profile':'typo'}),/Invalid native render profile/);
 for(const [name,value] of [['NWN_PARTICLE_PRESENTATION','typo'],['NWN_PARTICLE_LIGHTING','typo'],['NWN_NATIVE_LIGHTING','typo'],['NWN_NATIVE_LIGHT_HISTORY','true'],['NWN_NATIVE_SURFACE_OUTPUT','1']])assert.throws(()=>select({}, {[name]:value}),/Invalid native/);
 for(const gamma of ['', 'NaN','Infinity','-1','1001'])assert.throws(()=>select({'native-gamma':gamma}),/Invalid native gamma/);
});
test('Unsupported tonal stages and invalid color values cannot reach the native renderer',()=>{
 for(const value of ['1','32','-1','1.5','NaN'])assert.throws(()=>select({'native-postprocess-mask':value}),/Invalid native postprocess mask/);
 for(const field of ['midpoint','intensity','vibrance'])for(const value of ['','NaN','Infinity','1e100'])assert.throws(()=>select({['native-postprocess-'+field]:value}),/Invalid native postprocess/);
});
test('Diagnostic configuration excludes unrelated environment and account values',()=>{
 const config=select({}, {PRIVATE_LOGIN_VALUE:'private-sentinel',NWN_PLAYER_NAME:'player-sentinel'});
 assert.ok(!JSON.stringify(config).includes('sentinel'));assert.equal(config.summary.profile,'gameplay');
});
test('Actual child receives the original32-light default; explicit diagnostic limits remain available',()=>{
 const normal=select();assert.equal(normal.summary.maximum_lights,32);
 const custom=select({'native-max-lights':'128'});assert.equal(custom.summary.maximum_lights,128);assert.equal(custom.summary.profile,'custom');
 const child=spawnSync(process.execPath,['-e','process.stdout.write(JSON.stringify(process.argv.slice(1)))','--',...custom.arguments],{encoding:'utf8',windowsHide:true});
 assert.equal(child.status,0,child.stderr);assert.ok(JSON.parse(child.stdout).includes('--native-max-lights=128'));
 assert.equal(select({'render-profile':'gameplay'},{NWN_NATIVE_MAX_LIGHTS:'128'}).summary.maximum_lights,32);
 for(const value of ['', 'NaN','-1','129','1.5'])assert.throws(()=>select({'native-max-lights':value}),/Invalid native maximum lights/);
 assert.throws(()=>select({'render-profile':'legacy','native-max-lights':'32'}),/requires native light history/);
});
test('Three point shadows is an explicit comparison and is never silently promoted',()=>{
 const normal=select();assert.equal(normal.summary.point_shadow_lights,1);assert.ok(!normal.arguments.some(value=>value.startsWith('--native-shadow-lights=')));
 const comparison=select({'native-shadow-lights':'3'});assert.equal(comparison.summary.profile,'custom');assert.equal(comparison.summary.point_shadow_lights,3);assert.ok(comparison.arguments.includes('--native-shadow-lights=3'));
 const child=spawnSync(process.execPath,['-e','process.stdout.write(JSON.stringify(process.argv.slice(1)))','--',...comparison.arguments],{encoding:'utf8',windowsHide:true});
 assert.equal(child.status,0,child.stderr);assert.ok(JSON.parse(child.stdout).includes('--native-shadow-lights=3'));
 assert.equal(select({'render-profile':'gameplay'},{NWN_NATIVE_SHADOW_LIGHTS:'3'}).summary.point_shadow_lights,1);
 for(const value of ['', 'NaN','-1','5','1.5'])assert.throws(()=>select({'native-shadow-lights':value}),/Invalid native point-shadow limit/);
});
