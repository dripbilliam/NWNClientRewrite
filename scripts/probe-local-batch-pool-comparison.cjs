// Production client, authored native-server fixture, loopback endpoint fixed.
// Credentials remain in main memory and are wiped immediately after login.
const {app,BrowserWindow,ipcMain,session:electronSession,safeStorage}=require('electron');
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');app.setName('nwn-model-viewer-research');
const version=process.argv.find(a=>a.startsWith('--version='))?.slice(10)??'v1';if(!/^[a-z0-9-]+$/.test(version))throw Error('Invalid version');
const build=path.join(root,'dist'),savedUserData=app.getPath('userData');
const background=process.argv.includes('--background');
app.whenReady().then(async()=>{
 const output=path.join(root,`backups/animations/dense-local-${version}.json`),report={scope:'Authored native multiplayer dense fixture on loopback only',endpoint:'127.0.0.1:5123',states:[],diagnostics:[],rendererErrors:[],areas:[],samples:[],profiles:[]},start=performance.now(),at=()=>performance.now()-start;
 let win,controller,network,profiler,profileName,credentials;
 const profileStart=async name=>{profileName=name;await profiler.sendCommand('Profiler.start');};
 const profileStop=async()=>{if(!profileName)return;const {profile}=await profiler.sendCommand('Profiler.stop'),file=`dense-local-${version}-${profileName}.cpuprofile`;await fs.writeFile(path.join(path.dirname(output),file),JSON.stringify(profile)+'\n');report.profiles.push({name:profileName,file,samples:profile.samples?.length??0});profileName=null;};
 try{
  // Reject every non-loopback web request; native protocol endpoint is fixed too.
  const fixtureSession=electronSession.fromPartition('dense-client-'+version);fixtureSession.webRequest.onBeforeRequest((details,done)=>done({cancel:/^https?:/.test(details.url)&&!/^https?:\/\/127\.0\.0\.1(?::|\/)/.test(details.url)}));
  const {ClientSettings}=await import('../electron/client_settings.mjs'),settings=new ClientSettings({directory:savedUserData,encryption:safeStorage});credentials={cdKey:await settings.cdKey(),password:''};
  if(!credentials.cdKey)throw Error('Protected local test login unavailable');
  report.bundle=(await fs.readFile(path.join(build,'index.html'),'utf8')).match(/src="\.\/assets\/([^"\s]+\.js)"/)?.[1];
  report.bundleSha256=crypto.createHash('sha256').update(await fs.readFile(path.join(build,'assets',report.bundle))).digest('hex');
  report.fixture=JSON.parse(await fs.readFile(path.join(root,'backups/animations/dense-server-fixture-v1.json'),'utf8'));
  report.sourceHashes={};for(const file of ['electron/network_ipc.cjs','src/main.js','src/renderer_light_uniforms.js','src/renderer_material_reuse.js','src/renderer_light_slots.js','src/renderer_native_shadows.js','src/renderer_shadow_budget.js','src/network_scene.js','src/walkable_height_index.js','src/walkmesh.js','src/managed_local_matrix.js','src/model_hierarchy.js','src/model_animation.js','src/model_native_pose.js','src/visual_scene_pose.js','src/renderer_model_preparation.js','src/renderer_program_cache.js','src/resource_worker_pool.js','src/resource_worker.js','src/resource_worker_tasks.js','src/cached_root_matrix.js','src/frame_work_budget.js','src/renderer_texture_preparation.js','src/renderer_model_geometry.js','src/renderer_main_batches.js','src/renderer_palette_arrays.js','src/renderer_local_hooks.js','src/target_preview_shader.js','src/model_particles.js','src/camera_keyhole_shader.js','src/renderer_point_shadow_cache.js','src/renderer_shadow_traversal.js','src/renderer_shadow_instances.js','scripts/probe-dense-local-performance.cjs'])report.sourceHashes[file]=crypto.createHash('sha256').update(await fs.readFile(path.join(root,file))).digest('hex');
  const {createInstalledNetworkSession}=await import('../electron/installed_network_session.mjs');
  controller=require('../electron/network_ipc.cjs').registerNetworkIpc(ipcMain,{defaultInstall:path.resolve(root,'../FullDecomp/NwnRootInstall'),userDirectory:null,chooseInstall:async()=>null,createSession:async args=>{if(args.host!=='127.0.0.1'||args.port!==5123)throw Error('Loopback fixture only');const result=await createInstalledNetworkSession(args);network=result.session;return result;}});
  report.runtimeLog=require('../electron/runtime_log.cjs').registerRuntimeLog(ipcMain,path.join(root,'runtime-logs')).path;
  const debug=require('../electron/debug_window.cjs').registerDebugWindows({ipcMain,BrowserWindow,root});
  win=new BrowserWindow({show:!background,width:1440,height:960,webPreferences:{session:fixtureSession,offscreen:background,preload:path.join(root,'electron/preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true,backgroundThrottling:false}});controller.attach(win);debug.attach(win);win.setMenuBarVisibility(false);
  const send=win.webContents.send.bind(win.webContents);win.webContents.send=(channel,event)=>{if(channel==='network:event'){if(event.kind==='state'&&report.states.at(-1)?.phase!==event.state.phase)report.states.push({at:at(),phase:event.state.phase});if(event.kind==='diagnostic')report.diagnostics.push(event.diagnostic);}return send(channel,event);};
  win.webContents.on('console-message',(_e,level,message)=>{if(level>=3)report.rendererErrors.push(message);});
  const js=code=>win.webContents.executeJavaScript(code),pause=ms=>new Promise(r=>setTimeout(r,ms));
  await win.loadFile(path.join(build,'index.html'));if(!background){win.show();win.focus();}
  profiler=win.webContents.debugger;profiler.attach('1.3');await profiler.sendCommand('Profiler.enable');await profiler.sendCommand('Profiler.setSamplingInterval',{interval:1000});await profileStart('initial');
  const log=await fs.readFile(path.join(root,'runtime-logs/dense-performance-server/logs/nwengineLog.txt'),'utf8'),pin=log.match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];if(!pin)throw Error('Dense local identity unavailable');
  const character=await fs.readFile(path.resolve(root,'../FullDecomp/NwnRootInstall/data/lcv/wizard.bic'));report.connectAt=at();
  try{await controller.connect(win.webContents,{host:'127.0.0.1',port:5123,name:'DenseReplacementTest',serverPublicKey:pin,character,credentials});}finally{character.fill(0);for(const key of Object.keys(credentials))credentials[key]='';}
  const sample=()=>js(`(()=>{const c=document.querySelector('#model-canvas'),s=JSON.parse(c.dataset.networkScene??'null'),p=JSON.parse(document.querySelector('#performance-debug').dataset.state??'null');return{scene:s?{areaId:s.areaId,resRef:s.resRef,tiles:s.tiles,attached:s.attached,graphicsPending:s.graphicsPending,objects:s.objects.length,groundHeightIndex:s.groundHeightIndex,creatures:s.objects.filter(o=>o.objectType===5).map(o=>({id:o.id,position:o.position,animation:o.animation,clip:o.clip})),failed:s.failedObjects,controlled:s.controlled}:null,performance:p,frame:JSON.parse(c.dataset.frameTimings??'null'),workers:JSON.parse(c.dataset.resourceWorkers??'null'),prefetch:JSON.parse(c.dataset.resourcePrefetch??'null'),models:JSON.parse(c.dataset.rendererModelPreparation??'null'),frameWork:s?.frameWork??null,particleWorkers:JSON.parse(c.dataset.particleVertexWorkers??'null'),shadowBudget:JSON.parse(c.dataset.rendererShadowBudget??'null'),lightUniforms:JSON.parse(c.dataset.rendererLightUniforms??'null'),materialReuse:JSON.parse(c.dataset.rendererMaterialReuse??'null'),matrixSubtrees:JSON.parse(c.dataset.matrixSubtrees??'null'),cursor:JSON.parse(c.dataset.gameCursor??'null'),highlights:JSON.parse(c.dataset.worldHighlights??'null'),camera:JSON.parse(c.dataset.networkCamera??'null')};})()`);
  let resized=false,lastArea=null;
  for(let pass=0;pass<1;pass++){
   const requestedAt=pass?report.areas.at(-1).transitionAt:report.connectAt,deadline=at()+90000;let ready;
   while(at()<deadline){const value=await sample();report.samples.push({at:at(),phase:'load',pass,...value});if(value.scene?.controlled?.rendered&&value.scene.attached&&!value.scene.graphicsPending&&value.scene.areaId!==lastArea&&!value.performance?.preparing&&!value.performance?.pendingAssets&&!value.performance?.pendingShaders&&value.scene.objects>=100){ready=value;break;}await pause(250);}
   if(!ready)throw Error(`Dense area ${pass} failed to become ready`);await profileStop();
   const area={pass,id:ready.scene.areaId,resRef:ready.scene.resRef,readyAt:at(),loadMs:at()-requestedAt,samples:[]};report.areas.push(area);lastArea=area.id;
   if(!resized){const old=await js(`(()=>{const c=document.querySelector('#model-canvas');return{width:c.width,height:c.height};})()`),size=win.getContentSize();win.setContentSize(size[0]+3440-old.width,size[1]+1369-old.height);resized=true;}
   win.webContents.sendInputEvent({type:'mouseMove',x:1100,y:500});await pause(18000);const before=new Map();let changes=new Set(),clips=new Set();
   report.batchPoolAudit=await js('window.batchPoolAuditForTest()');
   report.batchPoolComparison=[];
   if(!await js('typeof window.setBatchPoolForTest==="function"'))throw Error('Comparison-only build required');
   for(let round=0;round<4;round++)for(const reuse of round%2?[true,false]:[false,true]){
    await js('window.setBatchPoolForTest('+reuse+')');
    await pause(3000);const activationFrames=await js('window.batchPoolFrameSamplesForTest()');await js('window.setBatchPoolForTest('+reuse+')');await profileStart('batch-'+round+'-'+(reuse?'reuse':'ordinary'));
    const phase={round,reuse,activationFrames,samples:[]},began=at();
    while(at()-began<9000){const value=await sample();for(const actor of value.scene?.creatures??[]){const pose=actor.position.join(','),old=before.get(actor.id);if(old&&old!==pose)changes.add(actor.id);before.set(actor.id,pose);if(actor.clip)clips.add(actor.clip);}phase.samples.push({at:at(),...value});area.samples.push({at:at(),...value});await pause(250);}
    await profileStop();phase.frames=await js('window.batchPoolFrameSamplesForTest()');report.batchPoolComparison.push(phase);
   }
   win.webContents.sendInputEvent({type:'keyUp',keyCode:'Home'});await profileStop();area.movingActors=changes.size;area.clips=[...clips];
   if(area.movingActors<10)throw Error('Fixture did not exercise moving crowd');
   area.geometry=await js(`JSON.parse(document.querySelector('#model-canvas').dataset.rendererModelGeometry??'null')`);
   area.batches=await js(`JSON.parse(document.querySelector('#model-canvas').dataset.rendererMainBatches??'null')`);
   const final=area.samples.at(-1);if(final.frame?.viewport?.bufferWidth!==3440||final.frame?.viewport?.bufferHeight!==1369)throw Error('Dense render dimensions did not match');if(final.scene.failed.length)throw Error('Dense models failed');
   if(pass===0){const image=await win.webContents.capturePage();await fs.writeFile(path.join(path.dirname(output),`dense-local-${version}.png`),image.toPNG());}
   if(false){await profileStart(`transition-${pass}`);area.transitionAt=at();await network.chat({areaId:network.world.areaId,areaGeneration:network.areaGeneration,actorId:network.world.localObjectId,channel:1,text:pass===0?'-stress-b':'-stress-a'});}
  }
  report.success=!report.rendererErrors.length;await controller.disconnect(win.webContents,{saveCharacter:false});await network.delivery;
  // Main-process disconnect completes before the renderer's asynchronous area
  // disposal. Wait for that owner too, rather than killing its pending workers.
  const closeDeadline=at()+10000;while(at()<closeDeadline){if(await js(`(()=>{const d=document.querySelector('#model-canvas').dataset,s=JSON.parse(d.shadowInstances??'null');return d.networkScene===undefined&&d.resourceWorkers===undefined&&(!s||s.cachedGroups===0&&s.geometryKeys===0&&s.alphaKeys===0&&s.currentMembers===0);})()`)){report.rendererClosedAt=at();break;}await pause(50);}
  if(!report.rendererClosedAt)throw Error('Renderer area ownership did not retire after disconnect');
  report.postCloseModels=await js(`JSON.parse(document.querySelector('#model-canvas').dataset.rendererModelPreparation??'null')`);if(!report.postCloseModels||report.postCloseModels.activeTemplates||report.postCloseModels.activeAreas||report.postCloseModels.pending||report.postCloseModels.templates!==report.postCloseModels.destroyed)throw Error('GPU preparation owners did not retire after disconnect');
  report.postCloseShadows=await js(`JSON.parse(document.querySelector('#model-canvas').dataset.shadowInstances??'null')`);
  report.postCloseGeometry=await js(`JSON.parse(document.querySelector('#model-canvas').dataset.rendererModelGeometry??'null')`);if(!report.postCloseGeometry||report.postCloseGeometry.active||report.postCloseGeometry.owners||report.postCloseGeometry.created!==report.postCloseGeometry.retired)throw Error('Shared rigid geometry owners did not retire');
  report.postCloseMaterialReuse=await js("JSON.parse(document.querySelector('#model-canvas').dataset.rendererMaterialReuse??'null')");if(report.postCloseMaterialReuse?.materialsHeld!==0)throw Error('Material reuse frame edits retained');
  report.postCloseLightUniforms=await js("JSON.parse(document.querySelector('#model-canvas').dataset.rendererLightUniforms??'null')");if(report.postCloseLightUniforms?.materials!==0)throw Error('Light uniform owners did not retire');
  report.postCloseBatches=await js(`JSON.parse(document.querySelector('#model-canvas').dataset.rendererMainBatches??'null')`);if(!report.postCloseBatches||report.postCloseBatches.cachedBatches||report.postCloseBatches.arrays||report.postCloseBatches.bytes||report.postCloseBatches.disabled)throw Error('Main batch owners did not retire cleanly');
  await pause(100);const rows=(await fs.readFile(report.runtimeLog,'utf8')).trim().split('\n').map(line=>JSON.parse(line));report.retiredWorkers=rows.filter(row=>row.code==='renderer.resource-workers-retired').map(row=>row.context);if(report.retiredWorkers.length!==1||report.retiredWorkers.some(row=>!row.closed||row.pending||row.queued||row.workers||!row.vertexWorkers.closed||row.vertexWorkers.pending||row.vertexWorkers.queued||row.vertexWorkers.workers))throw Error('Area workers did not fully retire');
  if(report.postCloseModels.programCache&&['materials','programs','references','bytes'].some(key=>report.postCloseModels.programCache[key]))throw Error('Program leases survived disconnect');
  for(const retired of report.retiredWorkers){if(retired.frameWork&&(!retired.frameWork.closed||retired.frameWork.queued||retired.frameWork.active||retired.frameWork.scheduled||retired.frameWork.failed))throw Error('Frame work did not retire');if(retired.texturePreparation?.failed)throw Error('Texture preparation failed');}
  await pause(400);report.postCloseMatrixSubtrees=await js("JSON.parse(document.querySelector('#model-canvas').dataset.matrixSubtrees??'null')");if(report.postCloseMatrixSubtrees?.owners||report.postCloseMatrixSubtrees?.nodes)throw Error('Matrix subtree owners did not retire');
  report.finishedAt=at();await profiler.sendCommand('Profiler.disable');profiler.detach();await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({success:report.success,output,areas:report.areas.map(a=>({resRef:a.resRef,loadMs:a.loadMs,movingActors:a.movingActors,clips:a.clips})),rendererErrors:report.rendererErrors}));app.exit(report.success?0:1);
 }catch(error){report.success=false;report.failure=error.stack;await profileStop().catch(()=>{});if(win&&!win.isDestroyed())win.webContents.sendInputEvent({type:'keyUp',keyCode:'Home'});await controller?.disconnect(win?.webContents,{saveCharacter:false}).catch(()=>{});if(credentials)for(const key of Object.keys(credentials))credentials[key]='';await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({failure:report.failure,output}));app.exit(1);}
});
