import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{
 runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize(['m0q1a','m0q1d'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
const player=s.player,ids=[...s.module.nativeAreaIds50.view()],maps=player.nativeAutoMapBuffers6d8.slice(),start=runtimeDiagnostics.records.length,steps=[];
assert.deepEqual([...player.nativeAutoMapAreaIds6c8.view()],ids);assert.ok(maps.every(b=>b.length===128&&b.every(v=>v===0)));
assert.ok([...s.registry.objects.values()].filter(o=>o.objectType===5&&o.id!==player.id&&o.nativeField89c===0).every(o=>o.nativeAutoMapBuffers6d8===null));
const bits=b=>[...b].reduce((total,v)=>total+v.toString(2).replace(/0/g,'').length,0),hash=b=>createHash('sha256').update(b).digest('hex');
for(const resRef of ['m0q1a','m0q1d','m0q1a']){
 const area=s.areas.get(resRef),spawn=resRef==='m0q1a'?[24,0,-14]:[...[...s.registry.objects.values()].find(o=>o.objectType===5&&o.areaId===area.id&&!s.isDead(o)).position];
 await s.enterArea(resRef,spawn);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();
 const before=maps.map(hash);for(let tick=0;tick<2;tick++){s.scheduler.advance(250);s.worldTimer.snapshot();await s.combat.updateSpawnHeartbeat(player,1);}
 const index=player.nativeAutoMapAreaIds6c8.indexOf(area.id),x=Math.trunc(spawn[0]/10),y=Math.trunc(-spawn[2]/10);
 assert.equal(await s.automap.explored(player,area.id,x,y),1);assert.equal(player.nativeAutoMapArea6e8,area.id);assert.ok(bits(maps[index])>0);
 for(let i=0;i<maps.length;i++)if(i!==index)assert.equal(hash(maps[i]),before[i],'Exploration must not modify another area buffer');
 steps.push({resRef,areaId:area.id,flags:area.flags,dimensions:[area.width,area.height],mapBytes:area.nativeMapByteCount348,position:spawn,cache:[player.nativeAutoMapTileX6e4,player.nativeAutoMapTileY6e5,player.nativeAutoMapArea6e8],explored:maps.map(bits),hashes:maps.map(hash)});
}
// Real local module-ID storage reorder: existing buffers move by ID, never
// acquire a second per-area owner. The isolated session is restored afterwards.
s.module.nativeAreaIds50.ids.set(ids.slice().reverse());await s.automap.reconcile(player);assert.deepEqual([...player.nativeAutoMapAreaIds6c8.view()],ids.slice().reverse());assert.equal(player.nativeAutoMapBuffers6d8[0],maps.at(-1));
s.module.nativeAreaIds50.ids.set(ids);await s.automap.reconcile(player);for(let i=0;i<maps.length;i++)assert.equal(player.nativeAutoMapBuffers6d8[i],maps[i]);
await s.automap.reveal(player,s.currentArea.id,1);assert.ok(player.nativeAutoMapBuffers6d8[0].subarray(0,s.currentArea.nativeMapByteCount348).every(v=>v===255));
await s.automap.reveal(player,s.currentArea.id,0);assert.equal(await s.automap.explored(player,s.currentArea.id,2,1),1);assert.ok(bits(player.nativeAutoMapBuffers6d8[0])<=s.currentArea.width*s.currentArea.height);
const scriptCalls=[],call=async(name,args)=>{const value=await s.commands[name](args,{self:player.id});scriptCalls.push({name,args,result:value??null});return value;},a=s.currentArea.id;
assert.equal(await call('GetTileExplored',[player.id,a,2,1]),1);
assert.equal(await call('SetTileExplored',[player.id,a,2,1,0]),1);assert.equal(await call('GetTileExplored',[player.id,a,2,1]),0);
assert.equal(await call('SetTileExplored',[player.id,a,2,1,-2]),0);assert.equal(await call('GetTileExplored',[player.id,a,-1,1]),-1);
assert.equal(await call('SetCreatureExploresMinimap',[player.id,2]),1);assert.equal(await call('GetCreatureExploresMinimap',[player.id]),2);
assert.equal(await call('SetCreatureExploresMinimap',[player.id,0]),2);await call('SetTileExplored',[player.id,a,2,1,0]);await s.automap.update(player);assert.equal(await call('GetTileExplored',[player.id,a,2,1]),0);
assert.equal(await call('SetCreatureExploresMinimap',[player.id,1]),0);await call('ExploreAreaForPlayer',[a,player.id,0]);assert.equal(await call('GetTileExplored',[player.id,a,2,1]),1);
const diagnostics=runtimeDiagnostics.records.slice(start),report={steps,reorderedBuffersPreserved:true,clearReappliesLocalExploration:true,scriptCalls,diagnostics,limits:'Installed Prelude PC PostProcess maps, real heartbeat/geometry/door traversal, local area adapter out/back, ordered module-area reconciliation, reveal/clear and five decoded script APIs. Startup/general world AI isolated. No native PC load handshake, map fog presentation, save transport or campaign-completion claim.'};
await fs.writeFile('backups/animations/live-automap.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
assert.equal(diagnostics.filter(d=>/automap-unimplemented/.test(d.code??'')).length,0);
assert.ok(diagnostics.filter(d=>d.severity==='error').every(d=>d.context.operation==='native-placeable-pwk-missing-empty-mesh'),'New automap errors must remain failures');
