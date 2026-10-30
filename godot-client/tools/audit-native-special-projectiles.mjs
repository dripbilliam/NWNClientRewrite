// Read-only scoped evidence audit. Never launches a game or joins a server.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const home=fileURLToPath(new URL('../',import.meta.url)),evidence=[];
const output=process.argv.find(v=>v.startsWith('--report='))?.slice(9)??'native-special-projectiles-final-audit-v1.json';
assert.match(output,/^native-special-projectiles-[a-z0-9-]+\.json$/);
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
async function read(file){const bytes=await fs.readFile(path.join(home,file));evidence.push({file,bytes:bytes.length,sha256:hash(bytes)});return JSON.parse(bytes);}
async function current(proof,files){for(const file of files){assert.ok(proof.sourceSha256[file],file+' not pinned');assert.equal(hash(await fs.readFile(path.join(home,file))),proof.sourceSha256[file],file+' changed since evidence');}}
async function kernel(name,count,files){
 const r=await read('reports/'+name+'.json'),p=await read('reports/'+name+'.debugger.json');
 assert.equal(r.success,true,name);assert.equal(r.checks,count,name);assert.deepEqual(r.failures,[]);
 for(const key of ['success','normalHeap','armed','sourceUnchanged'])assert.equal(p[key],true,name+'/'+key);
 for(const key of ['exception','engineOrLifetimeError'])assert.equal(p[key],false,name+'/'+key);
 assert.equal(p.debuggerExit,0);assert.equal(p.publicConnections,0);await current(p,files);
 return {report:name,checks:r.checks,graphical:p.graphical,...(r.oracleSha256?{oracleSha256:r.oracleSha256}:{})};
}
async function live(name,count){
 const r=await read('reports/'+name+'.json');assert.equal(r.success,true,name);
 if(count!==null){assert.equal(r.actions.checks.length,count,name);assert.ok(r.actions.checks.every(c=>c.passed));}
 for(const key of ['sourceUnchanged','debuggerArmed'])assert.equal(r[key],true,name+'/'+key);
 assert.equal(r.nativeExit,0);assert.equal(r.nativeException,false);assert.equal(r.native.workersRemaining,0);
 assert.equal(r.publicConnections,0);assert.equal(r.renderingPrepared,false);
 assert.ok(!r.loadedProtocolModules.some(f=>/three|client_projectile_presentation|network_projectile_presentation|export-native-animation/.test(f)));
 return r;
}
const kernels={};
kernels.bounce=await kernel('native-special-bounce-final-v1',1501,['systems/native_data/projectile_bounce.gd','systems/native_data/projectile_orientation.gd','tests/native_projectile_bounce_test.gd']);
kernels.polygon=await kernel('native-special-polygon-final-v1',2133,['systems/native_data/polygon_hit.gd','tests/native_polygon_hit_test.gd']);
kernels.scene=await kernel('native-special-scene-broadphase-v1',80,['systems/native_render/projectile_scene.gd','systems/native_render/scene_geometry.gd','systems/native_render/terrain_surface.gd','systems/native_render/model_template.gd','systems/native_render/resource_pool.gd','systems/native_data/tile_surface.gd','systems/native_data/binary_model.gd','tests/native_projectile_scene_test.gd']);
kernels.state=await kernel('native-special-state-regression-v1',20903,['systems/native_data/projectile_state.gd','tests/native_projectile_state_test.gd']);
kernels.impact=await kernel('native-special-impact-regression-v1',2604,['systems/native_data/projectile_impact.gd','systems/native_data/projectile_orientation.gd','systems/native_data/projectile_atan_table.gd','tests/native_projectile_impact_test.gd']);
kernels.receiver=await kernel('native-special-ranged-receiver-regression-v1',527,['systems/native_data/projectile_ranged.gd','systems/native_data/model_random_part.gd','tests/native_ranged_receiver_test.gd']);
kernels.surface=await kernel('native-special-surface-regression-v1',33081,['systems/native_data/tile_surface.gd','systems/native_render/terrain_surface.gd','systems/native_data/asset_service.gd','tests/native_surface_test.gd']);
kernels.template=await kernel('native-special-template-regression-v1',16,['systems/native_render/model_template.gd','tests/native_template_cache_test.gd']);
kernels.specialLifetime=await kernel('native-special-lifetime-headless-v2',16,['systems/native_render/projectile_world.gd','tests/native_projectile_special_lifetime_test.gd','tests/native_projectile_lifetime_test.gd']);
kernels.rangedLifetime=await kernel('native-special-ranged-lifetime-headless-v2',11,['systems/native_render/projectile_world.gd','systems/native_render/client_dummies.gd','tests/native_ranged_lifetime_test.gd','tests/native_projectile_lifetime_test.gd']);
kernels.spellLifetime=await kernel('native-special-spell-lifetime-headless-v2',11,['systems/native_render/projectile_world.gd','tests/native_projectile_lifetime_test.gd']);
kernels.area=await kernel('native-special-area-regression-v2',74,['systems/native_data/binary_model.gd','systems/native_render/model_template.gd','tests/native_ranged_area_test.gd']);
const original=await read('reports/native-projectile-bounce-original-v1.json');
assert.equal(evidence.at(-1).sha256,kernels.bounce.oracleSha256);
assert.equal(original.targetSha256??original.binarySha256??original.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
await read('reports/native-scene-face-oracle-v1.json');assert.equal(evidence.at(-1).sha256,kernels.scene.oracleSha256);
const bow=await live('native-special-bow-final-v2',21),sling=await live('native-special-sling-final-v2',22),miss=await live('native-special-miss-final-v2',22),deflection=await live('native-special-deflection-final-v2',24),effects=await live('native-special-effects-regression-v2',31),actions=await live('native-special-actions-regression-v2',62),lifecycle=await live('native-special-lifecycle-v1',null);
const critical=Object.keys(bow.sourceSha256).filter(f=>f.startsWith('systems/native_data/')||f.startsWith('systems/native_render/')||['systems/model_native_pose.gd','systems/model_rigs.gd','systems/camera_controller.gd','tests/native_live_actions_probe.gd','tools/native-actions-fixture.mjs','tools/native-ranged-fixture.mjs','tools/raw-visual-events.cjs','tools/raw-combat-events.cjs'].includes(f));
for(const r of [bow,sling,miss,deflection,effects,actions,lifecycle])await current(r,critical);
const summary=[];
for(const [name,r,base,mode,result] of [['bow',bow,8,2,null],['sling',sling,61,11,1],['miss',miss,61,12,4],['deflection',deflection,8,13,2]]){
 assert.ok(r.actionProtocol.some(m=>m.kind==='safe-projectile'&&m.header.baseItem===base&&m.header.appearance===0&&(result===null||m.header.result===result)&&(mode!==13||m.header.path===13)),name+' actual original packet');
 const owner=r.native.world.effects.projectiles,ready=owner.events.find(e=>e.kind==='ready'&&e.path===mode);
 assert.ok(ready,name+' native path');assert.equal(owner.stats.failed,0);assert.equal(owner.stats.retired,owner.stats.spawned);assert.equal(owner.active,0);assert.equal(owner.pending,0);assert.deepEqual(owner.tracking,{});
 const pixel=r.actions.checks.find(c=>c.label==='Actual original ammunition model changes native viewport pixels');assert.equal(pixel.passed,true);assert.ok(pixel.details.changed_pixels>2);
 if(mode>=11){assert.ok(owner.stats.scene_queries>=1);assert.equal(owner.stats.scene_hits,owner.stats.scene_queries);}
 summary.push({name,checks:r.actions.checks.length,ready,pixel,stats:owner.stats});
}
assert.ok(effects.actionProtocol.some(m=>m.kind==='safe-projectile'&&m.header.spellId===58));
assert.equal(lifecycle.localCycles.length,2);assert.equal(lifecycle.localAbortedCycles.length,1);assert.equal(lifecycle.cancelCheck.peerClosed,true);
const startup=await read('reports/native-secondary-startup-v3.json'),startupNative=await read('reports/native-secondary-startup-v3.native.json');
assert.equal(startup.success,true);assert.equal(startup.sourceUnchanged,true);assert.equal(startup.publicConnections,0);assert.equal(startup.nativeExit,0);assert.equal(startup.nativeException,false);assert.equal(startup.debuggerArmed,true);
await current(startup,['project.godot','join-native.ps1','tools/native-window-screen.ps1','tools/native-session-host.cjs','native_live_world.gd','native_session_world.gd']);
assert.equal(startupNative.final_window.focused,false);assert.equal(startupNative.final_window.unfocusable,true);assert.equal(startupNative.final_window.mouse_mode,0);assert.notEqual(startupNative.final_window.screen,startupNative.final_window.primary);
const checkpointFile='backups/native-special-projectiles-direct-after-v1.zip',checkpoint=await read(checkpointFile+'.verified.json');assert.equal(checkpoint.verified,true);assert.equal(hash(await fs.readFile(path.join(home,checkpointFile))),checkpoint.sha256);
const result={success:true,goalComplete:false,fullProjectileParity:false,mixedClientAccepted:false,performanceAccepted:false,publicConnections:0,kernels,realServer:summary,regression:{effects:31,gameplay:62,preludeCycles:2,streamAbort:1,cancelMs:lifecycle.cancelCheck.elapsedMs},startup:startupNative.final_window,checkpoint:{file:checkpointFile,sha256:checkpoint.sha256,files:checkpoint.files},evidence,scope:'Original path 11/12/13 construction and polygon cases; adapter static scene/WOK membership with bounded indexing; real localhost outcomes/pixel deltas and cleanup. Startup-only monitor/focus changes postdate live combat proofs and have separate current-source menu evidence. Headless owner tests prove model/node ownership, not GPU retirement. Full BSP, shield/impact/release paths, terrain black wedges visible in captures, general performance and paired original-client acceptance remain open.'};
await fs.writeFile(path.join(home,'reports',output),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,goalComplete:false,report:'reports/'+output,checkpoint:result.checkpoint}));
