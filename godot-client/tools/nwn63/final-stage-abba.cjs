'use strict';
// Coordinator-only final graphical ABBA. verify-only never starts a client.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),cp=require('node:child_process'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const {verifyStage}=require('./final-stage-pair.cjs');
const order=[['control','a'],['candidate','a'],['candidate','b'],['control','b']];
const expectedViewport=[3440,1369],expectedSettings={fovDegrees:45,gamma:1.2,particlesEnabled:true,particleCollisionEnabled:false,compactSceneryEnabled:true,maximumFps:0,vsync:0};
function view(p){if(!p)return null;const s=p.settings??{};return {viewport:p.viewport,settings:{fovDegrees:s.fov_degrees,gamma:s.gamma,particlesEnabled:s.particles_enabled,particleCollisionEnabled:s.particle_collision_enabled,compactSceneryEnabled:s.compact_scenery_enabled,maximumFps:p.maximum_fps,vsync:p.vsync}};}
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
function plan(receiptFile,tag){
 assert.match(tag,/^[a-z0-9][a-z0-9-]{0,39}$/);
 const receipt=JSON.parse(fs.readFileSync(receiptFile));assert.equal(receipt.issue,'NWN-63');
 const scope=path.dirname(receiptFile),runs=order.map(([leg,suffix])=>({leg,suffix,run:`nwn63-final-${receipt.label}-${tag}-${leg}-${suffix}`}));
 assert(!fs.existsSync(path.join(scope,`abba-${tag}-summary.json`)),'Fresh ABBA tag required');
 for(const row of runs){
  assert(!fs.existsSync(path.join(root,'reports',row.run+'.json')),'Fresh report label required: '+row.run);
  for(const extension of ['invocation.json','result.json','stdout.log','stderr.log'])assert(!fs.existsSync(path.join(scope,row.run+'.'+extension)),'Fresh evidence label required');
 }
 return {receipt,scope,runs,tag};
}
function scenePinned(receipt){
 const capture=receipt.scene.capture,recording=path.join(capture,'recording.json'),timeline=path.join(capture,'timeline.jsonl');
 assert.equal(hash(recording),receipt.scene.recordingSha256,'Recording changed');
 assert.equal(hash(timeline),receipt.scene.timelineSha256,'Scene timeline changed');
 const metadata=JSON.parse(fs.readFileSync(recording));
 assert.equal(metadata.complete,true);assert.equal(metadata.timelineSha256,receipt.scene.timelineSha256);
}
async function main(){
 const [mode,...args]=process.argv.slice(2),arg=name=>args.find(x=>x.startsWith('--'+name+'='))?.slice(name.length+3);
 assert(args.every(x=>x.startsWith('--receipt=')||x.startsWith('--tag=')),'Unexpected argument');
 assert(['verify-only','run'].includes(mode),'Use verify-only or run');
 const receiptFile=path.resolve(arg('receipt')??''),tag=arg('tag');assert(tag,'Fresh ABBA tag required');
 const prepared=plan(receiptFile,tag),verified=await verifyStage(receiptFile);
 scenePinned(prepared.receipt);
 assert.equal(hash(prepared.receipt.driver.file),prepared.receipt.driver.sha256);
 const publicPlan={status:'ready',noClientStarts:true,receipt:receiptFile,tag,order:prepared.runs.map(x=>({leg:x.leg,run:x.run})),sourceDifferences:verified.sourceDifferences,engineSha256:verified.engineSha256,recordingSha256:prepared.receipt.scene.recordingSha256,timelineSha256:prepared.receipt.scene.timelineSha256};
 if(mode==='verify-only'){console.log(JSON.stringify(publicPlan));return;}
 assert.equal(process.env.NWN63_FPS_LEASE,'root-exclusive','Coordinator exclusive FPS lease missing');
 assert.equal(process.env.NWN63_FINAL_RUN,'coordinator','Coordinator run gate missing');
 const summaries=[];let firstView=null;
 for(const row of prepared.runs){
  // Recheck immutable inputs at each leg; a partially completed ABBA is kept.
  await verifyStage(receiptFile);scenePinned(prepared.receipt);
  const selection=prepared.receipt.selections[row.leg];
  const args=[prepared.receipt.driver.file,'--capture='+prepared.receipt.scene.capture,'--generation=2','--movement-timing','--paced','--steady-ms=10000','--production-selection='+selection.file,'--production-selection-sha256='+selection.sha256,'--run='+row.run];
  const invocation={version:1,issue:'NWN-63',leg:row.leg,run:row.run,selection,receipt:receiptFile,receiptSha256:hash(receiptFile),driverSha256:prepared.receipt.driver.sha256,capture:prepared.receipt.scene,scope:'Exclusive normal-Core-E graphical generation-2 recorded-area movement ABBA; keyboard input is not injected'};
  fs.writeFileSync(path.join(prepared.scope,row.run+'.invocation.json'),JSON.stringify(invocation,null,2)+'\n',{flag:'wx'});
  const result=cp.spawnSync(process.execPath,args,{cwd:root,env:process.env,encoding:'utf8',timeout:240000,maxBuffer:4*1024*1024,windowsHide:true});
  fs.writeFileSync(path.join(prepared.scope,row.run+'.stdout.log'),result.stdout??'',{flag:'wx'});
  fs.writeFileSync(path.join(prepared.scope,row.run+'.stderr.log'),result.stderr??'',{flag:'wx'});
  const reportFile=path.join(root,'reports',row.run+'.json');
  const report=fs.existsSync(reportFile)?JSON.parse(fs.readFileSync(reportFile)):null,keyboard=report?.native?.keyboard,scene=report?.native?.native_scene_output,intervals=report?.native?.frame_intervals,world=report?.native?.world,base=world?.base_scenery,steady=report?.native?.performance_window,index=world?.drive_collision?.static_group_index;
  const beginView=view(steady?.view_begin),endView=view(steady?.view_end),observedView=beginView;
  const summary={run:row.run,leg:row.leg,exit:result.status,error:result.error?.message??null,report:reportFile,reportSha256:report?hash(reportFile):null,success:report?.success,recordedInputs:report?.movementReplay?.inputs,recordedAccepted:report?.movementReplay?.accepted,camera:report?.productionCameraVerification?.status,preferenceVerification:report?.productionPreferences?.verification?.status,worldReady:world?.admission_ready,areaId:world?.area_id,entities:world?.entities,base:{expected:base?.expected,resolved:base?.resolved,pending:base?.pending,failed:base?.failed,knownComplete:base?.known_base_complete},objectVisualsComplete:world?.object_visuals_complete,worldErrors:world?.errors,objectErrors:world?.object_errors,failedObjects:world?.failed_objects,collisionIndex:index??null,playable:report?.native?.playable,sceneConfigured:scene?.configured,sceneFailed:scene?.failed,keyboard:keyboard?{drive:keyboard.drive,stop:keyboard.stop,previews:keyboard.previews,admissionEvents:keyboard.admission_events,coalescedEvents:keyboard.admission_coalesced_events}:null,frameIntervals:intervals?.count,medianMs:intervals?.median_ms,p95Ms:intervals?.p95_ms,steady:{accepted:steady?.steady,elapsedMs:steady?.elapsed_ms,areaId:steady?.areaId,entities:steady?.entities},view:observedView,viewBegin:beginView,viewEnd:endView};
  const observedSettings=report?.productionPreferences?.verification?.actual?.settings;
  const viewExpected=observedView&&same(observedView.viewport,expectedViewport)&&same(report?.native?.presentation_state?.viewport,expectedViewport)&&same(observedView.settings,expectedSettings)&&same(observedView,endView)&&observedSettings&&observedSettings.fov_degrees===45&&observedSettings.gamma===1.2&&observedSettings.particles_enabled===true&&observedSettings.particle_collision_enabled===false&&observedSettings.compact_scenery_enabled===true&&(!firstView||same(observedView,firstView));
  const indexExpected=row.leg==='candidate'?summary.collisionIndex?.ready===true&&summary.collisionIndex.entries>0&&summary.collisionIndex.build_steps>0&&summary.collisionIndex.unsafe_groups===0&&Number.isInteger(summary.collisionIndex.last_query?.visited_nodes)&&summary.collisionIndex.last_query.visited_nodes>0&&Number.isInteger(summary.collisionIndex.last_query.tested_leaves)&&summary.collisionIndex.last_query.tested_leaves>=0:summary.collisionIndex===null;
  summary.accepted=result.status===0&&summary.success===true&&summary.recordedInputs===360&&summary.recordedAccepted===360&&summary.camera==='observed'&&summary.preferenceVerification==='observed'&&summary.worldReady===true&&summary.areaId===2147618622&&summary.entities===1918&&summary.base.expected===1784&&summary.base.resolved===1784&&summary.base.pending===0&&summary.base.failed===0&&summary.base.knownComplete===true&&summary.objectVisualsComplete===true&&same(summary.worldErrors,[])&&same(summary.objectErrors,[])&&same(summary.failedObjects,{})&&summary.playable===true&&summary.sceneConfigured===true&&summary.sceneFailed===false&&Number.isInteger(summary.keyboard?.drive)&&Number.isInteger(summary.keyboard?.admissionEvents)&&summary.frameIntervals>=60&&summary.steady.accepted===true&&summary.steady.elapsedMs>=10000&&summary.steady.areaId===2147618622&&summary.steady.entities===1918&&viewExpected&&indexExpected;
  if(summary.accepted&&firstView===null)firstView=observedView;
  fs.writeFileSync(path.join(prepared.scope,row.run+'.result.json'),JSON.stringify(summary,null,2)+'\n',{flag:'wx'});
  summaries.push(summary);console.log(JSON.stringify(summary));
  if(!summary.accepted)break;
 }
 const finished={version:1,issue:'NWN-63',tag,receipt:receiptFile,order:prepared.runs.map(x=>x.run),completed:summaries.length,accepted:summaries.length===4&&summaries.every(x=>x.accepted),summaries,scope:'Recorded graphical movement ABBA without OS keyboard injection; prior E burst and live Arelith keyboard/click acceptance are separate'};
 fs.writeFileSync(path.join(prepared.scope,`abba-${tag}-summary.json`),JSON.stringify(finished,null,2)+'\n',{flag:'wx'});
 if(!finished.accepted)process.exitCode=1;
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
