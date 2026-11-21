// Native client host. Extra servers require an explicit per-process allowlist.
// CD key stays inside the existing protected settings/session owners.
const {app,BrowserWindow,ipcMain,safeStorage,session:browserSession}=require('electron');
const {isDeepStrictEqual}=require('node:util');
const fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os'),net=require('node:net'),crypto=require('node:crypto'),{spawn}=require('node:child_process'),{pathToFileURL}=require('node:url');
const {JsonLines,validateCommand}=require('./local-protocol.cjs');
const {ContentTracker}=require('./content-tracker.cjs');
const {particleInputScope}=require('./particle-input-scope.cjs');
const {WorldTransfer}=require('./world-transfer.cjs');
const liveDiagnostics=new (require('./live-diagnostics.cjs').LiveDiagnostics)();
const {integrationComplete,nuiIntegrationComplete,buffIntegrationComplete,partyIntegrationComplete,frontendExitComplete,feedbackIntegrationComplete,cameraIntegrationComplete,cameraCommandIntegrationComplete,nwsyncIntegrationComplete}=require('./integration-evidence.cjs');
const {portalRegionIntegrationComplete}=require('./portal-region-evidence.cjs');
const {nativeShutdownComplete}=require('./shutdown-evidence.cjs');
const {worldAudioIntegrationComplete}=require('./world-audio-evidence.cjs');
const {handoffIntegrationComplete}=require('./handoff-evidence.cjs');
const content=new ContentTracker();
const worldTransfer=new WorldTransfer();
const project=path.resolve(__dirname,'..'),root=path.dirname(project);
app.setName('nwn-model-viewer-research');
const buffSmoke=process.argv.includes('--buff-smoke'),buffPreview=process.argv.includes('--buff-preview');
const partySmoke=process.argv.includes('--party-smoke');
const feedbackSmoke=process.argv.includes('--feedback-smoke');
const cameraSmoke=process.argv.includes('--camera-smoke');
const cameraCommandSmoke=process.argv.includes('--camera-command-smoke');
const weatherSmoke=process.argv.includes('--weather-smoke');
const {weatherIntegrationComplete,weatherRenderIntegrationComplete}=require('./weather-evidence.cjs');
const nwsyncSmoke=process.argv.includes('--nwsync-smoke');
const nwsyncCancel=process.argv.includes('--nwsync-cancel');
const portalRegionSmoke=process.argv.includes('--portal-region-smoke');let portalRegionGeneration=-1;
const portalHandoffSmoke=process.argv.includes('--portal-handoff-smoke');
const originGc=process.argv.includes('--native-origin-gc'),retiredOrigins=[];
if(originGc&&!portalHandoffSmoke)throw Error('Origin GC checks require the owned handoff harness');
const portalSyncFile=process.argv.find(v=>v.startsWith('--portal-sync-fixture='))?.slice(22);let portalSyncFixture;
const portalSyncRecovery=process.argv.find(v=>v.startsWith('--portal-sync-recovery='))?.slice(23)??null;
if(portalSyncRecovery&&(!portalSyncFile||!['cancel','failure'].includes(portalSyncRecovery)))throw Error('Invalid owned content recovery mode');
const portalNuiSmoke=process.argv.includes('--portal-nui-smoke')||Boolean(portalSyncFile);
if(portalNuiSmoke&&!portalHandoffSmoke)throw Error('NUI transfer check requires owned handoff mode');
const portalVaultName=process.argv.find(v=>v.startsWith('--portal-vault-fixture='))?.slice(23);let portalVaultFixture;
if(portalVaultName&&(!portalHandoffSmoke||portalNuiSmoke||!/^vault-handoff-fixtures-v[0-9]+\.json$/.test(portalVaultName)))throw Error('Invalid owned vault handoff fixture');
const portalRecoveryMode=process.argv.find(v=>v.startsWith('--portal-recovery='))?.slice(18)??null;
if(portalRecoveryMode&&(!portalHandoffSmoke||!['cancel','failure'].includes(portalRecoveryMode)))throw Error('Invalid local portal recovery mode');
let portalRecoveryRelease=null,portalAdoptionWork=null;
let syncFixture;
const shortcutReconnectSmoke=process.argv.includes('--shortcut-reconnect-smoke');
const {shortcutReconnectComplete,shortcutPhaseComplete}=require('./shortcut-reconnect-evidence.cjs');
const settingsSmoke=process.argv.includes('--settings-smoke');
const menuExitSmoke=process.argv.includes('--menu-exit-smoke');
const creationSmoke=process.argv.includes('--creation-smoke');
const {creationIntegrationComplete}=require('./creation-evidence.cjs');
let creationExpected;
const worldAudioSmoke=process.argv.includes('--world-audio-smoke');
const pointVisualSmoke=process.argv.includes('--point-visual-smoke')||worldAudioSmoke;
const nuiPopupSmoke=process.argv.includes('--nui-popup-smoke'),nuiSkinSmoke=process.argv.includes('--nui-skin-smoke')||nuiPopupSmoke,nuiReconnectSmoke=process.argv.includes('--nui-reconnect-smoke')||nuiSkinSmoke,nuiActionSmoke=process.argv.includes('--nui-action-smoke')||nuiReconnectSmoke,nuiSmoke=process.argv.includes('--nui-smoke')||nuiActionSmoke,recordsSmoke=process.argv.includes('--records-smoke'),visualSmoke=process.argv.includes('--visual-smoke')||pointVisualSmoke,levelSmoke=process.argv.includes('--level-smoke'),characterSmoke=process.argv.includes('--character-smoke'),storeSmoke=process.argv.includes('--store-smoke'),containerSmoke=process.argv.includes('--container-smoke'),inventorySmoke=process.argv.includes('--inventory-smoke')||containerSmoke||storeSmoke||characterSmoke||levelSmoke||recordsSmoke||nuiSmoke||buffSmoke||partySmoke||shortcutReconnectSmoke;
const visualDefinitionSmoke=process.argv.includes('--visual-definition-smoke'),visualModelSmoke=process.argv.includes('--visual-model-smoke')||visualDefinitionSmoke,particleSmoke=process.argv.includes('--particle-smoke'),combatSmoke=process.argv.includes('--combat-smoke'),bookSmoke=process.argv.includes('--book-smoke')||combatSmoke,radialSmoke=process.argv.includes('--radial-smoke')||bookSmoke,textSmoke=portalHandoffSmoke||process.argv.includes('--text-smoke')||radialSmoke||particleSmoke||visualModelSmoke||visualSmoke||inventorySmoke||feedbackSmoke||cameraSmoke||cameraCommandSmoke||weatherSmoke||nwsyncSmoke,movementSmoke=process.argv.includes('--movement-smoke'),transitionSmoke=process.argv.includes('--transition-smoke'),contentSmoke=process.argv.includes('--content-smoke')||transitionSmoke,lifecycle=process.argv.includes('--lifecycle-smoke')||nuiReconnectSmoke||buffSmoke||partySmoke||shortcutReconnectSmoke,smoke=process.argv.includes('--smoke')||portalRegionSmoke||lifecycle||contentSmoke||movementSmoke||textSmoke,headless=process.argv.includes('--native-headless');
if(lifecycle&&contentSmoke)throw Error('Use separate character and world lifecycle checks');
const testMode=creationSmoke?'creation':settingsSmoke?'settings':particleSmoke?'particles':combatSmoke?'combat':bookSmoke?'book':radialSmoke?'radial':textSmoke?'text':movementSmoke?'movement':transitionSmoke?'transition':contentSmoke?'content':lifecycle?'lifecycle':smoke?'smoke':'normal';
const autoPlay=process.argv.includes('--auto-play')||portalRegionSmoke||portalHandoffSmoke;
let win,controller,network,server,wire,native,nativeClosed,temp,timer,busy=false,stopping=false,loaded=null;
const report={scope:'Godot live owned local server integration; not animation or full gameplay parity',endpoint:'127.0.0.1:5121',states:[],areas:[],diagnostics:[],rendererErrors:[],commands:[],nativeLoaded:[],success:false};
const reportName=process.argv.find(a=>a.startsWith('--report='))?.slice(9)??`local-join-${Date.now()}.json`;
if(!/^[a-z0-9-]+\.json$/.test(reportName))throw Error('Invalid report name');
const output=path.join(project,'reports',reportName),pause=ms=>new Promise(r=>setTimeout(r,ms));
let currentArea=null,auth=false,token,booted=false,origin=null,smokeAt=0,poseFrames=0,chatSeen=false;
let contentWork=null,lastPoseAt=0;
let textTestStarted=false;
let driveQueue=Promise.resolve(),movementRevision=0;
const movementRecords=new Map();
report.driveCommands=[];report.drivePreviews=[];report.pathAdmissions=[];
report.poseDelivery={intervalCount:0,totalIntervalMs:0,maxIntervalMs:0};
let textResolver,textDelivery;
let combatFeedback={enabled:true,total:false};
let actions,worldCursorId,networkSpellUsesLeft,nativeFloatEntry;
let spellbook,bookRefresh=null,lastBookAt=0;
let shortcutChoices;
let inventory,inventoryRefresh=null,lastInventoryAt=0;
let characterSheet,sheetRefresh=null,lastSheetAt=0;
let levelup,levelRefresh=null,lastLevelAt=0;
let creation;
let areaMap,journal,recordsRefresh=null,lastRecordsAt=0;
let nui,nuiRefresh=null;
let buffs;
let party,players,partyAt=0,playersRefresh=null;
let setupService,lastDebugAt=0;
let serverBrowser;
let startupServer,endpointOptions,liveStatusAt=0;
let setupFixture;
let combatDelivery,combatWork=null,lastCombatAt=0;
let particleDelivery,ParticleDelivery,particleEpoch=0;
let visualDelivery;
let environmentDelivery;
let worldAudio;
let nativeBinding=null;
report.buffReconnectRequired=buffSmoke;report.nuiPopupRequired=nuiPopupSmoke;report.nuiSkinRequired=nuiSkinSmoke;report.nuiActionRequired=nuiActionSmoke;report.nuiReconnectRequired=nuiReconnectSmoke;
report.shortcutReconnectRequired=shortcutReconnectSmoke;
report.visuals={};
report.particles={epochs:[]};
function flushCombat(){
 if(combatWork||!booted||!loaded||!combatDelivery||current()?.areaId!==loaded.areaId||current()?.generation!==loaded.generation||!worldTransfer.matches(worldTransfer.scope,current()))return;
 const delivery=combatDelivery;lastCombatAt=performance.now();let succeeded=false;
 const work=delivery.flush().then(()=>{succeeded=true;}).catch(error=>{if(network&&!network.closed)diagnose({code:'godot.combat-delivery-failed',reason:error.message});}).finally(()=>{if(combatWork===work){combatWork=null;if(succeeded&&combatDelivery===delivery&&delivery.pending.length)flushCombat();}});combatWork=work;
}
let lobby,loginConnection=0;
let lifecycleStage='first',exportedKey=null;
let contentStage='movement',probeId=null,contentDeadline=0,contentMark=0,spawnResources=null,equippedResources=null;
report.characterSaves=[];report.characterReads=[];report.presentations=[];
report.contentUpdates=[];report.contentApplied=[];
report.bridgeWork={};report.contentSmoke=[];
report.gameplayText={};
report.actionRequests=[];report.spellConsumptions=[];report.preparationRequests=[];report.preparationObservations=[];
function movementReady(){return report.movementDistance>0.25&&(movementSmoke?report.driveCommands.some(c=>c.operation==='drive'&&c.transmit):report.commands.some(c=>c.kind==='walk'&&c.areaId===loaded?.areaId&&c.generation===loaded?.generation))&&chatSeen&&report.nativePresentation?.cameraFollow&&require('./presentation-evidence.cjs').presentationAnimationComplete(report.nativePresentation,report.nativeLoaded.find(v=>v.connection===lobby.connection&&v.areaId===loaded?.areaId&&v.generation===loaded?.generation));}
async function measure(name,work){const began=performance.now();try{return await work();}finally{const duration=performance.now()-began,row=report.bridgeWork[name]??={count:0,totalMs:0,maxMs:0};row.count++;row.totalMs+=duration;row.maxMs=Math.max(row.maxMs,duration);}}
async function fixtureCommand(stage,command){contentStage=stage;contentDeadline=Date.now()+30000;contentMark=content.sequence;report.contentSmoke.push({stage,command});await network.chat({areaId:loaded.areaId,areaGeneration:loaded.generation,actorId:network.world.localObjectId,channel:1,text:command});}
async function contentSmokeTick(){
 if(contentStage==='movement')return;
 if(contentStage==='to-b'||contentStage==='to-a'){
  const wanted=contentStage==='to-b'?'dense_b':'dense_a',latest=report.nativeLoaded.at(-1);
  if(loaded.area===wanted&&movementReady()){
   if(report.nativePresentation?.cleanup?.alive!==0)throw Error('Retired native area owners remain alive');
   if(wanted==='dense_b'){
    if(latest.entityIds.includes(probeId))throw Error('Previous-area creature leaked into new native registry');
    await fixtureCommand('to-a','-native-a');
   }else{
    const resources=report.areas.at(-1).inventory.find(row=>row.id===probeId)?.resources;
    if(!latest.entityIds.includes(probeId)||JSON.stringify(resources)!==JSON.stringify(report.pendingContentRace.resources)||!report.pendingContentRace.discarded)throw Error('Returned area did not recover the authoritative shape');
    await fixtureCommand('return-restore','-native-restore');
   }
  }
  if(Date.now()>contentDeadline)await stop(1,'Native transition deadline at '+contentStage);
  return;
 }
 const object=[...network.world.registry.objects.values()].find(o=>o.areaId===loaded.areaId&&o.objectType===5&&o.id!==network.world.localObjectId&&!o.replicationRemoved);
 if(probeId===null&&object)probeId=object.id;
 const update=report.contentUpdates.findLast(row=>row.connection===lobby.connection&&row.areaId===loaded.areaId&&row.generation===loaded.generation&&row.sequence>contentMark&&(contentStage==='despawn'?row.remove.includes(probeId):row.upserts.some(r=>r.id===probeId)));
 const applied=update&&report.contentApplied.find(row=>row.connection===update.connection&&row.areaId===update.areaId&&row.generation===update.generation&&row.sequence===update.sequence);
 if(applied?.screenshot){
  const resources=update.resources?.find(row=>row.id===probeId)?.resources;
  if(contentStage==='spawn'){spawnResources=resources;await fixtureCommand('shape','-native-shape');}
  else if(contentStage==='shape'&&JSON.stringify(resources)!==JSON.stringify(spawnResources))await fixtureCommand('restore','-native-restore');
  else if(contentStage==='restore'&&JSON.stringify(resources)===JSON.stringify(spawnResources))await fixtureCommand('equip','-native-equip');
  else if(contentStage==='equip'&&JSON.stringify(resources)!==JSON.stringify(spawnResources)){
   equippedResources=resources;await fixtureCommand(transitionSmoke?'pending-transition':'despawn',transitionSmoke?'-native-shape':'-native-despawn');
  }
  else if(contentStage==='return-restore'&&JSON.stringify(resources)===JSON.stringify(equippedResources))await fixtureCommand('despawn','-native-despawn');
  else if(contentStage==='despawn'){report.contentSmokeComplete=true;report.success=integrationComplete(testMode,report);await stop(report.success?0:1,report.success?null:'World lifecycle evidence is incomplete');}
 }
 if(Date.now()>contentDeadline)await stop(1,'Native content lifecycle deadline at '+contentStage);
}
const diagnose=d=>{if(report.diagnostics.length<200)report.diagnostics.push({code:d.code,reason:d.reason,...(d.code==='network.server-disconnected'?{strRef:d.strRef,text:d.text}:{})});liveDiagnostics.record(d);};
function send(value){if(auth)wire?.send({connection:lobby?.connection??0,...value});}
function current(){return network?{connection:lobby.connection,areaId:network.world.areaId,generation:network.areaGeneration}:null;}
let nativePose;
const movementKeys=['position','orientation','animation','path','walkRate','runRate','field8F4','field8EC','actionFlag'];
function publishMovement(session,events){
 if(!booted||!loaded||session!==network||loaded.areaId!==session.world.areaId||loaded.generation!==session.areaGeneration)return;
 const records=[];
 for(const event of events){
  if(event.action!=='movement')continue;
  const object=session.world.registry.get(event.id);if(!object||object.objectType!==5||object.areaId!==loaded.areaId||object.replicationRemoved)continue;
  const initial=Object.fromEntries(movementKeys.filter(key=>object.replicated[key]!==undefined).map(key=>[key,structuredClone(object.replicated[key])]));
  const row={id:event.id,revision:++movementRevision,created:Boolean(event.created),changes:structuredClone(event.changes),initial};movementRecords.set(event.id,row);records.push(row);
 }
 if(records.length)send({kind:'movement',areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId,records});
}
async function stop(code=0,reason=null){
 if(stopping)return;stopping=true;clearInterval(timer);if(reason)report.failure=reason;
 report.settingsCleanup=await setupService?.retire();
 report.creationCleanup=await creation?.retire();
 report.browserCleanup=await serverBrowser?.retire();
 if(creationSmoke&&serverBrowser){const {ServerBrowserStore}=await import('./server-browser-store.mjs');const saved=await new ServerBrowserStore(serverBrowser.store.file).load();report.browserPersistence={isolated:true,history:saved.history.map(({host,port})=>({host,port})),favorites:saved.favorites.map(({host,port})=>({host,port})),last:saved.last};}
 try{await controller?.disconnect(win?.webContents,{saveCharacter:false});await network?.delivery;}catch{}
 await visualDelivery?.close();
 await worldAudio?.close();
 await environmentDelivery?.close();
 report.inventoryCleanup=await inventory?.retire();
 report.characterSheetCleanup=await characterSheet?.retire();
 report.mapCleanup=await areaMap?.retire();journal?.reset();
 report.nuiCleanup=await nui?.retire();
 report.buffCleanup=await buffs?.retire();
 report.partyCleanup=await party?.retire();players?.reset();
 levelup?.reset();
 await particleDelivery?.close();
 try{
  report.nativeShutdown={requestedAt:Date.now(),connection:lobby?.connection??0,forced:false};
  send({kind:'quit',diagnoseOrphans:process.argv.includes('--native-verbose')});
  if(nativeClosed)await Promise.race([nativeClosed,pause(5000)]);
  wire?.socket.destroy();server?.close();if(native&&native.exitCode===null){report.nativeShutdown.forced=true;native.kill();}win?.destroy();if(temp)await fs.rm(path.join(temp,'ticket.json'),{force:true});
 }catch{}
 report.disconnected=!network||Boolean(network.closed);report.poseFrames=poseFrames;
 if(report.success&&native&&!nativeShutdownComplete(report)){report.success=false;code=1;report.failure??='Native world/UI retirement or graceful shutdown is incomplete';}
 if(report.success&&worldAudioSmoke&&!worldAudioIntegrationComplete(report)){report.success=false;code=1;report.failure??='Native world audio admission/playback or cleanup evidence is incomplete';}
 if(nuiSmoke&&!nuiIntegrationComplete(report)){report.success=false;code=1;report.failure??='Native NUI acceptance is incomplete';}
 if(report.success&&portalRegionSmoke&&!portalRegionIntegrationComplete(report)){report.success=false;code=1;report.failure??='Native portal-region shutdown evidence is incomplete';}
 if(report.success&&portalHandoffSmoke&&!(portalRecoveryMode?require('./handoff-recovery-evidence.cjs').recoveryIntegrationComplete(report):portalSyncRecovery?require('./sync-handoff-recovery-evidence.cjs').syncHandoffRecoveryComplete(report):portalSyncFixture?require('./sync-handoff-evidence.cjs').syncHandoffIntegrationComplete(report):portalNuiSmoke?require('./nui-handoff-evidence.cjs').nuiHandoffIntegrationComplete(report):portalVaultFixture?require('./vault-handoff-evidence.cjs').vaultHandoffIntegrationComplete(report):handoffIntegrationComplete(report))){report.success=false;code=1;report.failure??='Native handoff shutdown evidence is incomplete';}
 if(report.success&&!(report.frontendExitOnly?frontendExitComplete(report):weatherSmoke?weatherRenderIntegrationComplete(report):nwsyncSmoke?nwsyncIntegrationComplete(report):cameraCommandSmoke?cameraCommandIntegrationComplete(report):cameraSmoke?cameraIntegrationComplete(report):feedbackSmoke?feedbackIntegrationComplete(report):shortcutReconnectSmoke?shortcutReconnectComplete(report):partySmoke?partyIntegrationComplete(report):integrationComplete(testMode,report))){report.success=false;code=1;report.failure??='Native shutdown diagnostics invalidated integration evidence';}
 await fs.mkdir(path.dirname(output),{recursive:true});await fs.writeFile(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({success:report.success,failure:report.failure,output,nativeLoaded:report.nativeLoaded,disconnected:report.disconnected,poseFrames}));app.exit(code);
}
async function advanceHandoff(){
 await network.exportCharacter();
 if(originGc&&report.nativeLoaded.length===3){if(typeof global.gc!=='function'){await stop(1,'Explicit native origin GC is unavailable');return;}let samples=[];for(let i=0;i<30;i++){global.gc();await pause(50);samples=retiredOrigins.map(v=>({connection:v.connection,sessionAlive:Boolean(v.session.deref()),worldAlive:Boolean(v.world.deref())}));if(samples.every(v=>!v.sessionAlive&&!v.worldAlive))break;await pause(0);}report.originGc={explicit:true,samples,passed:samples.length===2&&samples.every(v=>!v.sessionAlive&&!v.worldAlive)};if(!report.originGc.passed){await stop(1,'Retired backend source sessions remain reachable');return;}}
 if(portalSyncRecovery&&report.nativeLoaded.length===2){report.success=require('./sync-handoff-recovery-evidence.cjs').syncHandoffRecoveryComplete(report,{beforeShutdown:true});await stop(report.success?0:1,report.success?null:'Native content recovery evidence is incomplete');return;}
 if(report.nativeLoaded.length<3){report.handoffRequests??=[];report.handoffRequests.push({connection:lobby.connection,endpoint:report.endpoint});await network.chat({areaId:loaded.areaId,areaGeneration:loaded.generation,actorId:network.world.localObjectId,channel:1,text:'-native-portal'});}
 else{report.success=portalSyncFixture?require('./sync-handoff-evidence.cjs').syncHandoffIntegrationComplete(report,{beforeShutdown:true}):portalNuiSmoke?require('./nui-handoff-evidence.cjs').nuiHandoffIntegrationComplete(report,{beforeShutdown:true}):portalVaultFixture?require('./vault-handoff-evidence.cjs').vaultHandoffIntegrationComplete(report,{beforeShutdown:true}):handoffIntegrationComplete(report,{beforeShutdown:true});await stop(report.success?0:1,report.success?null:'Native handoff arrival/gameplay/persistence evidence is incomplete');}
}
async function command(m){
 if(m.kind==='sync-handoff-recovery-tested'&&auth&&portalSyncRecovery&&m.connection===lobby.connection){report.syncRecoveryNative=m.result;if(!m.result.completed)await stop(1,'Native destination content recovery controls failed');return;}
 if(m.kind==='nui-handoff-tested'&&portalNuiSmoke&&m.connection===lobby.connection&&loaded){
  const windows=[...network.world.nui.windows.values()],root=windows.find(v=>v.id==='root'),child=windows.find(v=>v.id==='child'),label=lobby.connection===2?'B':'A';
  const canonical=root?.bindings.get('echo')==='Edited on '+label&&child?.bindings.get('caption')==='Acknowledged by server '+label;
  report.nuiHandoffPhases??=[];report.nuiHandoffPhases.push({connection:lobby.connection,canonical,rootToken:root?.token,childToken:child?.token,result:m.result});
  if(!canonical||!m.result.completed||m.result.checks.length<(lobby.connection===1?14:17)||m.result.checks.some(v=>!v.passed)){await stop(1,'Native NUI handoff phase is incomplete');return;}
  await advanceHandoff();return;
 }
 if(m.kind==='hello'){
  if(auth||m.token!==token){wire.socket.destroy();return;}auth=true;token=null;await fs.rm(path.join(temp,'ticket.json'),{force:true});if(portalSyncFixture)send({kind:'sync-handoff-watch',screenshot:output.replace(/\.json$/,'-sync'),mode:portalSyncRecovery});if(portalVaultFixture)send({kind:'vault-handoff-selection',key:'server:'+portalVaultFixture.source+':'+portalVaultFixture.reference});send({kind:'status',text:'Local multiplayer · choose a character after connecting'});lobby.emit();
  if(startupServer){
   send({kind:'status',text:'Connecting to '+startupServer.host+':'+startupServer.port});
   await serverBrowser.command({kind:'browser-input',connection:lobby.connection,operation:'open'});
   await serverBrowser.command({kind:'browser-input',connection:lobby.connection,viewId:serverBrowser.view.id,operation:'join',direct:true,values:{...startupServer,name:endpointOptions.name,password:'',cdKey:''}});
  }
  else if(endpointOptions.publicServers)await serverBrowser.command({kind:'browser-input',connection:lobby.connection,operation:'open'});
  if(settingsSmoke)send({kind:'setup-live-test',mods:setupFixture.mods,other:setupFixture.other,screenshot:reportName.replace(/\.json$/,'-settings.png'),debugScreenshot:reportName.replace(/\.json$/,'-debug.png')});
  if(nwsyncSmoke)send({kind:'nwsync-test-begin',cancel:nwsyncCancel,screenshot:reportName.replace(/\.json$/,'-download.png')});
  if(menuExitSmoke)send({kind:'menu-exit-test'});if(creationSmoke)send({kind:'creator-live-test',firstName:'Native'+crypto.createHash('sha256').update(reportName).digest('hex').slice(0,6),lastName:'Ui'+crypto.createHash('sha256').update(reportName).digest('hex').slice(6,12),portraits:reportName.replace(/\.json$/,'-portraits.png'),review:reportName.replace(/\.json$/,'-review.png')});return;
 }
 if(!auth){wire.socket.destroy();return;}
 if(m.kind==='shutdown-observed'){
  if(stopping&&m.connection===lobby.connection&&m.connection===report.nativeShutdown?.connection)report.nativeShutdown.observed=m;
  return;
 }
 if(m.kind==='portal-recovery-tested'&&portalRecoveryMode&&m.connection===lobby.connection){
  report.portalRecoveryNative=m.result;portalRecoveryRelease?.();portalRecoveryRelease=null;
  await portalAdoptionWork?.catch(()=>{});
  if(!m.result.completed){await stop(1,'Native portal recovery controls failed');return;}
  send({kind:'portal-recovery-retry'});return;
 }
 if(m.kind==='portal-recovery-retry-clicked'&&portalRecoveryMode){report.portalRecoveryRetry=m.result;if(!m.result.completed)await stop(1,'Native portal retry pointer failed');return;}
 if(m.kind==='portal-region-tested'&&portalRegionSmoke){
  validateCommand({...m,kind:'walk',position:[0,0,0]},current());report.portalRegionPhases??=[];report.portalRegionPhases.push({area:loaded.area,areaId:m.areaId,generation:m.generation,at:Date.now(),...m.result});
  if(!m.result.completed){await stop(1,'Native portal region check failed');return;}
  if(m.result.final){report.success=portalRegionIntegrationComplete(report);await stop(report.success?0:1,report.success?null:'Native A-B-A portal evidence incomplete');}return;
 }

 if(m.kind==='nwsync-cancel-tested'&&nwsyncSmoke&&nwsyncCancel&&m.connection===lobby.connection){report.nwsyncCancelRequired=true;report.nwsyncCancelTest=m.result;report.success=nwsyncIntegrationComplete(report);await stop(report.success?0:1,report.success?null:'Native NWSync cancellation incomplete');return;}
 if(m.kind==='creator-tested'&&creationSmoke){report.creationTest=m.result;if(!m.result?.completed){await stop(1,'Native character creation probe failed before completed reconnect');return;}await network?.exportCharacter();report.success=creationIntegrationComplete(report);await stop(report.success?0:1,report.success?null:'Native character creation/admission/reconnect evidence is incomplete');return;}
 if(m.kind==='setup-tested'&&settingsSmoke&&m.connection===lobby.connection){report.settingsTest=m.result;report.settingsPersistence=await setupFixture.finish();report.settingsNoNetwork=!network&&report.nativeLoaded.length===0;report.success=integrationComplete('settings',report);await stop(report.success?0:1,report.success?null:'Native settings or Windows-protection evidence is incomplete');return;}
 if(m.kind==='creation-audio-observed'){validateCommand(m,{connection:lobby.connection});report.creationVoiceNative??=[];if(report.creationVoiceNative.length<128){const {owner,sequence,state,code,voiceId,codec,bytes,sha256,duration,driver,reason}=m;report.creationVoiceNative.push({connection:lobby.connection,owner,sequence,state,code,voiceId,codec,bytes,sha256,duration,driver,reason});}return;}
 if(m.kind==='browser-input'){try{validateCommand(m,{connection:lobby.connection});await serverBrowser.command(m);}finally{if(m.values){m.values.password='';m.values.cdKey='';}}return;}
 if(m.kind==='client-feedback-options'){
  validateCommand(m,{connection:lobby.connection});combatFeedback={enabled:m.values.floatingFeedback,total:m.values.damageTotalsOnly};report.feedbackPreferences??=[];if(report.feedbackPreferences.length<100)report.feedbackPreferences.push({connection:lobby.connection,...combatFeedback});send({kind:'feedback-options',values:m.values});return;
 }
 if(m.kind==='client-settings'){try{validateCommand(m,{connection:lobby.connection});await setupService.command(m);}finally{if(typeof m.values?.cdKey==='string')m.values.cdKey='';}return;}
 if(m.kind==='particles-start'||m.kind==='particle-frame'){
  const scope={...current(),transferId:loaded?.transferId},admission=particleInputScope(m,scope,particleDelivery?.data.epoch,report.particles.epochs);
  if(admission==='retired'){report.retiredParticleInputs??=[];if(report.retiredParticleInputs.length<64)report.retiredParticleInputs.push({kind:m.kind,connection:m.connection,areaId:m.areaId,generation:m.generation,epoch:m.epoch,sequence:m.sequence});return;}
  validateCommand(m,current());if(admission!=='current')throw Error('Unknown native particle epoch or transfer');if(!booted||!loaded)return;
  if(m.kind==='particles-start')await particleDelivery?.start(m.layout);else await particleDelivery?.frame(m);return;
 }
 if(m.connection!==lobby.connection)throw Error('Native input belongs to an old connection');
 if(m.kind==='client-debug-request'){
  validateCommand(m,{connection:lobby.connection});if(performance.now()-lastDebugAt<400)return;lastDebugAt=performance.now();
  send({kind:'client-debug',snapshot:{gameplay:{phase:network?.phase??'menu',connected:Boolean(network&&!network.closed),endpoint:report.endpoint,area:loaded?.area??null,poseFrames},diagnostics:liveDiagnostics.snapshot(),resources:{nativeAreaAdmissions:report.nativeLoaded.length,pendingVisualModels:visualDelivery?.modelJobs.size??0,pendingVisualDefinitions:visualDelivery?.jobs.size??0,liveVisualEffects:visualDelivery?.entries.size??0,partyJobs:party?.tasks.size??0,bufferedContentUpdates:report.contentUpdates.length}}});return;
 }
 if(m.kind==='nui-input'){validateCommand(m,{connection:lobby.connection});await nui.command(m);return;}
 if(m.kind==='creation-input'){validateCommand(m,{connection:lobby.connection});if(!creation)throw Error('Connect to the local server before creating a character');await creation.command(m);return;}
 if(m.kind==='lobby-cancel-join'){await lobby.cancelJoin(m);report.commands.push({kind:m.kind,connection:m.connection});return;}
 if(m.kind==='lobby-join'){await lobby.join(m);report.commands.push({kind:m.kind,connection:m.connection});return;}
 if(m.kind==='lobby-choose'){await lobby.choose(m);report.commands.push({kind:m.kind,connection:m.connection,...(creationSmoke||portalVaultFixture?{key:m.key}:{})});return;}
 if(m.kind==='lobby-play'){await lobby.play(m);report.commands.push({kind:m.kind,connection:m.connection,...(creationSmoke||portalVaultFixture?{key:m.key}:{})});return;}
 if(m.kind==='lobby-disconnect'){
  await lobby.leave(m);report.commands.push({kind:m.kind,connection:m.connection,saveCharacter:m.saveCharacter});
  if(lifecycle&&lifecycleStage==='export'&&exportedKey){lifecycleStage='rejoin';send({kind:'lifecycle-rejoin',key:exportedKey});}return;
 }
 if(m.kind==='lobby-export'){await lobby.export(m);report.commands.push({kind:m.kind,connection:m.connection});return;}
 if(m.kind==='lobby-quit'){
  if(!smoke&&!settingsSmoke&&!network){report.frontendExitOnly=true;report.explicitMenuQuit=true;report.settingsNoNetwork=true;report.scope='Native Main Menu exit before admission; not gameplay evidence';report.success=frontendExitComplete(report);await stop(report.success?0:1);return;}
  if(network&&!network.closed&&['playing','area-loading'].includes(network.phase))await lobby.leave(m);
  const savedRead=report.characterReads.some(row=>row.connection===3&&row.source==='vault'&&row.key===exportedKey&&row.sha256===report.characterSaves[1]?.sha256);
  report.success=integrationComplete(testMode,report)&&(!lifecycle||lifecycleStage==='closing'&&savedRead);await stop(report.success?0:1,report.success?null:'Native integration flow did not complete');return;
 }
 if(m.kind==='loaded'){
  if(!loaded||!worldTransfer.matches(worldTransfer.scope,current())||m.transferId!==loaded.transferId||!worldTransfer.acknowledge(m)){diagnose({code:'godot.stale-area-ack',reason:'A retired native area acknowledgement was ignored'});return;}
  report.nativeLoaded.push({connection:m.connection,areaId:m.areaId,generation:m.generation,transferId:m.transferId,entityIds:m.entityIds,meshes:m.meshes,sha256:m.sha256,rigs:m.rigs??null,nativeLoadMs:m.nativeLoadMs});booted=true;send({kind:'status',text:`LOCAL SERVER · ${loaded.area} · ${report.endpoint}\nClick ground: move · Click object: interact · Enter: chat · Middle drag: camera\nNative models and live particles · remaining UI migration in progress`});
  if(portalHandoffSmoke){report.handoffArrivals??=[];report.handoffArrivals.push({connection:m.connection,area:loaded.area,endpoint:report.endpoint,position:network.world.registry.get(network.world.localObjectId)?.replicated?.position,confirmed:network.characterConfirmed,phase:network.phase,waypointRequests:network.loginWaypointRequests,waypointRemaining:network.loginWaypoint});}
  if(portalVaultFixture){const selected=network.selectedServerCharacter;report.vaultAdmissions??=[];report.vaultAdmissions.push({connection:m.connection,localAllowed:network.localVaultAllowed,uploaded:Boolean(network.characterUploaded),submitted:Boolean(network.characterSubmitted),confirmed:network.characterConfirmed,source:selected?.source,resref:selected?.resref});}
  if(inventory)inventory.signature=null;
  environmentDelivery?.flush();
  if(characterSheet)characterSheet.signature=null;
  publishMovement(network,[...network.world.registry.objects.values()].filter(o=>o.objectType===5&&o.replicated).map(o=>({action:'movement',id:o.id,changes:Object.fromEntries(movementKeys.filter(k=>o.replicated[k]!==undefined).map(k=>[k,o.replicated[k]]))})));
  if(smoke||creationSmoke){origin=nativePose(network.world.registry.get(network.world.localObjectId))?.position;smokeAt=Date.now();send({kind:'smoke',mode:movementSmoke?'keyboard':'click',areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId,position:origin,offset:report.nativeLoaded.length===1?1.5:-1.5,screenshot:reportName.replace(/\.json$/,`-c${lobby.connection}-a${loaded.transferId}.png`)});}return;
 }
 if(m.kind==='environment-observed'){
  if(loaded&&m.connection===lobby.connection&&m.areaId===loaded.areaId&&m.generation===loaded.generation&&m.transferId===loaded.transferId){report.environments??=[];if(report.environments.length<128)report.environments.push(m);}return;
 }
 if(m.kind==='sky-observed'){
  if(loaded&&m.connection===lobby.connection&&m.areaId===loaded.areaId&&m.generation===loaded.generation&&m.transferId===loaded.transferId){report.skies??=[];if(report.skies.length<128)report.skies.push(m);}return;
 }
 if(m.kind==='weather-observed'){
  if(loaded&&m.connection===lobby.connection&&m.areaId===loaded.areaId&&m.generation===loaded.generation&&m.transferId===loaded.transferId){report.weatherObserved??=[];if(report.weatherObserved.length<128)report.weatherObserved.push(m);}return;
 }
 if(m.kind==='weather-resource-observed'){
  if(loaded&&m.connection===lobby.connection&&m.areaId===loaded.areaId&&m.generation===loaded.generation&&m.transferId===loaded.transferId){report.weatherResourcesObserved??=[];report.weatherResourcesObserved.push(m);}return;
 }
 if(m.kind==='content-applied'){
  if(m.areaId===loaded?.areaId&&m.generation===loaded?.generation)report.contentApplied.push({connection:m.connection,areaId:m.areaId,generation:m.generation,sequence:m.sequence,entities:m.entities,removed:m.removed,meshes:m.meshes,rigs:m.rigs,importMs:m.importMs,screenshot:m.screenshot??null});
  return;
 }
 if(m.kind==='presented'){
  if((smoke||creationSmoke)&&m.areaId===loaded?.areaId&&m.generation===loaded?.generation&&m.distance>0.25&&m.screenshot){report.nativePresentation={connection:m.connection,areaId:m.areaId,generation:m.generation,distance:m.distance,cameraFollow:m.cameraFollow,screenshot:m.screenshot,animation:m.animation??null,controlledAnimation:m.controlledAnimation??null,controlledId:m.controlledId??null,cleanup:m.cleanup};report.presentations.push(report.nativePresentation);}return;
 }
 if(m.kind==='movement-tested'){
  if(movementSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.movementTest=m.result;report.movementDistance=Math.hypot(...nativePose(network.world.registry.get(network.world.localObjectId)).position.map((v,i)=>v-origin[i]));report.success=integrationComplete(testMode,report);await stop(report.success?0:1,report.success?null:'Native keyboard movement evidence did not complete');}return;
 }
 if(m.kind==='gameplay-tested'){
  if(portalHandoffSmoke&&loaded&&m.connection===lobby.connection&&m.areaId===loaded.areaId&&m.generation===loaded.generation){
   report.gameplayTest=m.result;report.handoffGameplay??=[];report.handoffGameplay.push({connection:lobby.connection,areaId:loaded.areaId,generation:loaded.generation,result:m.result});
   if(!integrationComplete(testMode,report)){await stop(1,'Native gameplay after handoff did not complete');return;}
   if(portalSyncFixture){
    const expected=portalSyncFixture.servers[lobby.connection===2?1:0],phase={connection:lobby.connection,label:expected.label,expectedHash:expected.hash,resources:[],absent:'gd_only_'+(expected.label==='A'?'b':'a'),unmounted:false};
    try{for(const e of expected.entries){const bytes=Buffer.from(await network.getResource(e.name,e.type)),hash=crypto.createHash('sha1').update(bytes).digest('hex');phase.resources.push({name:e.name,type:e.type,size:bytes.length,hash,expected:e.hash,match:hash===e.hash&&bytes.length===e.size});}try{await network.getResource(phase.absent,2017);}catch(error){if(error.code==='RESOURCE_NOT_FOUND')phase.unmounted=true;else throw error;}phase.readyAt=Date.now();report.syncHandoffPhases??=[];report.syncHandoffPhases.push(phase);}catch(error){await stop(1,error.message);return;}
   }
   if(portalNuiSmoke){const previous=report.nuiHandoffPhases?.at(-1);send({kind:'nui-handoff-test',label:lobby.connection===2?'B':'A',screenshot:output.replace(/\.json$/,'-c'+lobby.connection+'-nui.png'),...(portalSyncFixture?{pixel:portalSyncFixture.servers[lobby.connection===2?1:0].pixel}:{}),...(previous?{retiredConnection:previous.connection,retiredWindowId:previous.result.rootWindowId}:{})});return;}
   if(portalRecoveryMode&&report.portalRecoveryNative){await network.exportCharacter();report.success=require('./handoff-recovery-evidence.cjs').recoveryIntegrationComplete(report,{beforeShutdown:true});await stop(report.success?0:1,report.success?null:'Native retry gameplay/save evidence is incomplete');return;}
   // Recovery checks above export explicitly; ordinary round trips export here.
   await advanceHandoff();return;
  }
  if(partySmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.gameplayTest=m.result;if(integrationComplete(testMode,report))send({kind:'roster-live-test',retired:Boolean(report.partyPhases?.length),areaId:loaded.areaId,generation:loaded.generation,screenshot:reportName.replace(/\.json$/,'-c'+lobby.connection+'-party.png')});else await stop(1,'Gameplay check before native party HUD failed');return;}
  if(buffSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.gameplayTest=m.result;if(integrationComplete(testMode,report))send({kind:'status-live-test',retired:Boolean(report.buffPhases?.length),areaId:loaded.areaId,generation:loaded.generation,screenshot:reportName.replace(/\.json$/,'-c'+lobby.connection+'-buffs.png')});else await stop(1,'Gameplay check before native status HUD failed');return;}
  if(nuiSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.gameplayTest=m.result;report.success=integrationComplete(testMode,report);if(report.success){send({kind:'interface-live-test',actions:nuiActionSmoke,skin:nuiSkinSmoke,popup:nuiPopupSmoke,...(nuiReconnectSmoke&&report.nuiPhases?.length?{retiredConnection:report.nuiPhases[0].connection,retiredWindowId:report.nuiPhases[0].windowId}:{}),areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId,screenshot:reportName.replace(/\.json$/,nuiReconnectSmoke?'-c'+lobby.connection+'-nui.png':'-nui.png')});return;}}
  if(recordsSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.gameplayTest=m.result;report.success=integrationComplete(testMode,report);if(report.success){send({kind:'records-live-test',areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId,screenshot:reportName.replace(/\.json$/,'-records.png')});return;}}
  if(levelSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.gameplayTest=m.result;report.success=integrationComplete(testMode,report);if(report.success){send({kind:'level-live-test',areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId,screenshot:reportName.replace(/\.json$/,'-level.png')});return;}}
  if(characterSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.gameplayTest=m.result;report.success=integrationComplete(testMode,report);if(report.success){send({kind:'sheet-live-test',areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId,screenshot:reportName.replace(/\.json$/,'-sheet.png')});return;}}
  if(storeSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.gameplayTest=m.result;report.success=integrationComplete(testMode,report);if(report.success){send({kind:'store-live-test',areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId,screenshot:reportName.replace(/\.json$/,'-store.png')});return;}}
  if(containerSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.gameplayTest=m.result;report.success=integrationComplete(testMode,report);if(report.success){send({kind:'container-live-test',areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId,screenshot:reportName.replace(/\.json$/,'-container.png')});return;}}
  if(shortcutReconnectSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){
   report.gameplayTest=m.result;if(!integrationComplete(testMode,report)){await stop(1,'Gameplay before shortcut reconnect failed');return;}
   const startLight=networkSpellUsesLeft(network.world.registry.get(network.world.localObjectId),actions.rules,100,0,0,0);report.shortcutStarts??=[];report.shortcutStarts.push({connection:lobby.connection,lightUses:startLight});
   send({kind:'shortcut-reconnect-test',serverLightUses:startLight,restored:Boolean(report.shortcutPhases?.length),expected:report.shortcutPhases?.[0]?.test.rows??[],areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId,screenshot:reportName.replace(/\.json$/,'-c'+lobby.connection+'-shortcuts.png')});return;
  }
  if(cameraSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.gameplayTest=m.result;if(!integrationComplete(testMode,report)){await stop(1,'Gameplay before camera mode check failed');return;}send({kind:'camera-live-test',areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId,screenshot:reportName.replace(/\.json$/,'-camera.png')});return;}
  if(cameraCommandSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.gameplayTest=m.result;if(!integrationComplete(testMode,report)){await stop(1,'Gameplay before scripted camera failed');return;}send({kind:'camera-command-live-test',areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId,screenshot:reportName.replace(/\.json$/,'-script-camera.png')});return;}
  if(weatherSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.gameplayTest=m.result;if(!integrationComplete(testMode,report)){await stop(1,'Gameplay before weather state check failed');return;}send({kind:'weather-live-test',areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId,screenshot:output.replace(/\.json$/,'-weather.png')});return;}
  if(nwsyncSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){
   report.gameplayTest=m.result;if(!integrationComplete(testMode,report)){await stop(1,'Gameplay before NWSync verification failed');return;}
   report.nwsyncResources=[];let icon;
   try{for(const e of syncFixture.entries){report.nwsyncPendingResource=e.name;let timeout;const read=network.getResource(e.name,e.type),deadline=new Promise((_,reject)=>{timeout=setTimeout(()=>reject(Error('Timed out reading mounted NWSync resource '+e.name)),10000);});let bytes;try{bytes=Buffer.from(await Promise.race([read,deadline]));}finally{clearTimeout(timeout);}const hash=crypto.createHash('sha1').update(bytes).digest('hex');report.nwsyncResources.push({name:e.name,type:e.type,size:bytes.length,hash,expected:e.hash,match:hash===e.hash&&bytes.length===e.size,algorithm:e.algorithm});if(e.type===3)icon=bytes.toString('base64');}report.nwsyncPendingResource=null;}catch(error){await stop(1,error.message);return;}
   send({kind:'nwsync-live-test',areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId,icon,screenshot:reportName.replace(/\.json$/,'-nwsync.png')});return;
  }
  if(feedbackSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.gameplayTest=m.result;if(!integrationComplete(testMode,report)){await stop(1,'Gameplay before feedback options failed');return;}send({kind:'feedback-live-test',areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId,screenshot:reportName.replace(/\.json$/,'-feedback.png')});return;}
  if(inventorySmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){
   report.gameplayTest=m.result;report.success=integrationComplete(testMode,report);
   if(report.success){
    send({kind:'inventory-live-test',areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId,screenshot:reportName.replace(/\.json$/,'-inventory.png')});return;
   }
  }
  if(textSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.gameplayTest=m.result;report.success=integrationComplete(testMode,report);if(visualSmoke&&report.success){send({kind:'visual-live-test',points:pointVisualSmoke,audio:worldAudioSmoke,areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId,screenshot:reportName.replace(/\.json$/,'-visual.png')});return;}await stop(report.success?0:1,report.success?null:'Native gameplay-text check did not complete');}return;
 }
 if(m.kind==='visual-tested'&&visualSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.visualTest=m.result;report.success=integrationComplete(testMode,report)&&m.result.completed&&m.result.checks.length>=(pointVisualSmoke?18:9)&&m.result.checks.every(row=>row.passed)&&report.visuals.input.some(row=>row.kind==='loop'&&row.action==='A')&&report.visuals.input.some(row=>row.kind==='loop'&&row.action==='D')&&report.visuals.input.some(row=>row.kind==='instant')&&(!pointVisualSmoke||report.clientDummies.at(-1).status.some(row=>row.stage==='expired')&&report.clientDummies.at(-1).created>=2);await stop(report.success?0:1,report.success?null:'Native live visual-effect check did not complete');return;}
 if(m.kind==='shortcut-reconnect-tested'&&shortcutReconnectSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){
  const actor=network.world.registry.get(network.world.localObjectId),bindings=structuredClone(network.world.quickbar),items=bindings.map((b,index)=>b.type===1?{index,id:b.itemId,location:structuredClone(network.world.registry.get(b.itemId)?.inventoryLocation),stack:network.world.registry.get(b.itemId)?.item?.stackSize??network.world.registry.get(b.itemId)?.item?.field454}:null).filter(Boolean);
  const phase={connection:lobby.connection,actorId:actor.id,scope:{areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId},test:m.result,bindings,items,serverStartLight:report.shortcutStarts.find(v=>v.connection===lobby.connection).lightUses,lightUses:networkSpellUsesLeft(actor,actions.rules,100,0,0,0)};report.shortcutPhases??=[];report.shortcutPhases.push(phase);
  if(!shortcutPhaseComplete(report,phase)){await stop(1,'Native shortcut reconnect phase failed');return;}
  if(report.shortcutPhases.length===1){lifecycleStage='export';send({kind:'lifecycle-export'});return;}
  await network.exportCharacter();lifecycleStage='closing';report.success=shortcutReconnectComplete(report);await stop(report.success?0:1,report.success?null:'Shortcut persistence/export evidence incomplete');return;
 }
 if(m.kind==='camera-tested'&&cameraSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.cameraTest=m.result;report.success=cameraIntegrationComplete(report);await stop(report.success?0:1,report.success?null:'Native camera mode check failed');return;}
 if(m.kind==='camera-command-tested'&&cameraCommandSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.cameraCommandTest=m.result;report.success=cameraCommandIntegrationComplete(report);await stop(report.success?0:1,report.success?null:'Native scripted camera check failed');return;}
 if(m.kind==='weather-tested'&&weatherSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.weatherTest=m.result;report.success=weatherRenderIntegrationComplete(report);await stop(report.success?0:1,report.success?null:'Native weather state evidence incomplete');return;}
 if(m.kind==='nwsync-tested'&&nwsyncSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.nwsyncTest=m.result;report.success=nwsyncIntegrationComplete(report);await stop(report.success?0:1,report.success?null:'Native NWSync evidence incomplete');return;}
 if(m.kind==='feedback-tested'&&feedbackSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.feedbackTest=m.result;report.success=feedbackIntegrationComplete(report);await stop(report.success?0:1,report.success?null:'Native feedback options check failed');return;}
 if(m.kind==='inventory-tested'&&inventorySmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){
  report.inventoryTest=m.result;const before=report.inventoryPowerBefore,afterItem=before&&network.world.registry.get(before.itemId)?.item,after=afterItem?.stackSize??afterItem?.field454;
  report.inventoryPowerConsumption=before?{itemId:before.itemId,before:before.stack,after:after??null}:null;
  report.success=integrationComplete(testMode,report)&&m.result.completed&&m.result.checks.length>=45&&m.result.checks.every(row=>row.passed)&&report.inventoryShortcutAssignments?.some(row=>row.index===35&&row.button.type===1&&row.button.itemId===m.result.itemId)&&['equip','unequip'].every(operation=>report.inventoryResults?.some(row=>row.operation===operation&&row.success))&&before&&after===before.stack-1&&report.radialShortcutAssignments?.some(v=>v.index===34&&v.button.itemId===before.itemId)&&report.actionRequests.some(v=>v.operation==='useItem'&&v.itemId===before.itemId&&v.propertyIndex===0);
  const cast=report.actionRequests.find(v=>v.operation==='castSpell'&&v.spellId===100),afterUses=cast?networkSpellUsesLeft(network.world.registry.get(network.world.localObjectId),actions.rules,100,cast.classIndex??0,cast.domainLevel??0,cast.metamagic??0):null;
  report.shortcutMenuSpellConsumption=cast?{spellId:100,before:cast.beforeUses,after:afterUses}:null;
  report.success=Boolean(report.success&&cast&&cast.beforeUses===afterUses+1&&report.shortcutMenuAssignments?.some(v=>v.index===33&&v.button.type===2&&v.button.intParam===100)&&[32,33].every(index=>report.shortcutMenuAssignments?.some(v=>v.index===index&&v.button.type===0))&&report.shortcutActivations?.some(v=>v.index===32&&v.button.type===42&&v.button.intParam===22)&&!report.rejectedCommands?.length);
  report.success=Boolean(report.success&&[4,22].every(skillId=>report.actionRequests.some(v=>v.operation==='useSkill'&&v.packedSkill===skillId&&v.targetId===network.world.localObjectId))&&report.actionRequests.filter(v=>v.operation==='changeMode'&&v.modeId===2).length===2&&m.result.skill?.craft_dialog&&m.result.skill?.cursor?.valid&&m.result.skill.cursor.cursor===37&&['dialog-entry','dialog-replies'].every(kind=>report.skillDialogs?.some(v=>v.kind===kind))&&[29,30,31].every(index=>report.shortcutMenuAssignments?.some(v=>v.index===index&&v.button.type===0)));
  await stop(report.success?0:1,report.success?null:'Native inventory check did not complete');return;
 }
 if(m.kind==='container-tested'&&containerSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.containerTest=m.result;report.success=integrationComplete(testMode,report)&&m.result.completed&&m.result.checks.length>=12&&m.result.checks.every(row=>row.passed)&&report.inventoryResults?.filter(row=>row.operation==='move'&&row.success).length>=2&&report.containerStatuses?.some(row=>row.targetId===m.result.chestId&&row.primary);await stop(report.success?0:1,report.success?null:'Native container check did not complete');return;}
 if(m.kind==='store-tested'&&storeSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){report.storeTest=m.result;report.success=integrationComplete(testMode,report)&&m.result.completed&&m.result.checks.length>=18&&m.result.checks.every(row=>row.passed)&&['buy','sell','identify'].every(operation=>report.inventoryRequests?.some(row=>row.store&&row.operation===operation))&&report.storeMessages?.filter(row=>row.kind==='store-transaction').length>=2&&report.storeExaminations?.some(row=>row.targetId===m.result.identifiedId&&row.identified);await stop(report.success?0:1,report.success?null:'Native merchant check did not complete');return;}
 if(m.kind==='sheet-tested'&&characterSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){
  report.characterSheetTest=m.result;const r=m.result.record,s=report.characterSheetViews?.find(v=>v.id===r.viewId),skill=report.characterSheetViews?.find(v=>v.id===m.result.skill.viewId),feat=report.characterSheetViews?.find(v=>v.id===m.result.feat.viewId);
  report.characterSheetCanonicalMatch=Boolean(s&&JSON.stringify(r.abilities)===JSON.stringify(s.abilities)&&JSON.stringify(r.saves)===JSON.stringify(s.saves)&&r.ac===s.ac&&r.xp===s.xp&&r.hp===s.hp.current+(s.hp.fieldE8??0)&&r.maximumHP===s.hp.maximum&&skill?.skills.some(v=>v.index===m.result.skill.id&&v.value===m.result.skill.value&&v.flag)&&feat?.feats.includes(m.result.feat.id));
  report.success=integrationComplete(testMode,report)&&m.result.completed&&m.result.checks.length>=20&&m.result.checks.every(row=>row.passed)&&report.characterSheetCanonicalMatch;
  if(report.success){await network.exportCharacter();const saved=report.characterSheetSavedQuickbar??[];report.success=saved.some(v=>v.index===34&&v.type===3&&v.intParam===m.result.skill.id)&&saved.some(v=>v.index===35&&v.type===4&&v.intParam===m.result.feat.id)&&report.characterSheetExportSha256===report.characterSaves.at(-1)?.sha256;}
  await stop(report.success?0:1,report.success?null:'Native character sheet check did not complete');return;
 }
 if(m.kind==='level-tested'&&levelSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){
  report.levelTest=m.result;const proposals=(report.levelRequests??[]).filter(v=>v.operation==='submit').map(v=>v.proposal),before=report.levelRequests?.find(v=>v.operation==='begin')?.snapshot,actor=network.world.registry.get(network.world.localObjectId),total=(actor.replicated.stats.classes??[]).reduce((n,c)=>n+c.level,0);
  report.success=integrationComplete(testMode,report)&&m.result.completed&&m.result.checks.length>=28&&m.result.checks.every(v=>v.passed)&&proposals.length===2&&report.levelResults?.filter(v=>v.accepted).length===2&&total===report.levelFixture.expectedLevels;
  if(report.success){await network.exportCharacter();const saved=report.levelExport,skills=[...before.skills],abilities=[...report.levelFixture.abilities];for(const p of proposals){p.skills.forEach((v,i)=>skills[i]+=v);if(p.ability<6)abilities[p.ability]++;}report.levelExportMatches=Boolean(saved&&saved.classes.reduce((n,c)=>n+c.level,0)===total&&JSON.stringify(saved.skills)===JSON.stringify(skills)&&JSON.stringify(saved.abilities)===JSON.stringify(abilities)&&proposals.every(p=>p.feats.every(id=>saved.feats.includes(id))&&Object.values(p.known).flat().every(id=>saved.known[p.classId]?.includes(id)))&&saved.sha256===report.characterSaves.at(-1)?.sha256);report.success=report.levelExportMatches;}
  await stop(report.success?0:1,report.success?null:'Native level-up check did not complete');return;
 }
 if(m.kind==='records-tested'&&recordsSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){
  report.recordsTest=m.result;const s=network.world.registry.get(network.world.localObjectId).playerState.mapExploration[loaded.areaId],j=network.world.journal;
  report.recordsCanonicalMatch=m.result.explored===s.filter(v=>v===1).length&&m.result.cells===s.length&&m.result.pins.some(p=>p.rich.text==='Native server map pin'&&p.visible)&&m.result.journal.entries.every(e=>j.entries.has(e.tag));
  report.success=integrationComplete(testMode,report)&&m.result.completed&&m.result.checks.length>=20&&m.result.checks.every(v=>v.passed)&&report.recordsCanonicalMatch&&report.journalRequests?.some(v=>v.open===false);
  await stop(report.success?0:1,report.success?null:'Native map/journal check did not complete');return;
 }
 if(m.kind==='interface-spell-watch'&&nuiActionSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){await actions.tables();const actor=network.world.registry.get(network.world.localObjectId);report.nuiSpellBaseline={areaId:loaded.areaId,generation:loaded.generation,before:networkSpellUsesLeft(actor,actions.rules,100,0,0,0)};send({kind:'interface-spell-ready',areaId:loaded.areaId,generation:loaded.generation,before:report.nuiSpellBaseline.before});return;}
  if(m.kind==='interface-tested'&&nuiSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){
  report.nuiTest=m.result;const w=[...network.world.nui.windows.values()].find(v=>v.id==='root');report.nuiServerBuild=network.serverBuild;report.nuiResourceRequirements=network.resourceRequirements;report.nuiReceivedState=w?Object.fromEntries([...w.bindings].map(([k,v])=>[k,{type:Array.isArray(v)?'array':typeof v,length:v?.length,...(!Array.isArray(v)?{value:v}:{})}])):null;
  const expected={name:'Native watched edit',selected:true,check:true,choice:20,integer:7,fraction:.75,option:2,tab:2,color:{r:30,g:120,b:230,a:255},multi:'Native multiline\nSecond line'};
  report.nuiServerEchoes=Object.fromEntries(Object.keys(expected).map(k=>[k,w?.bindings.get('echo_'+k)]));
  report.nuiTargetAcknowledged=w?.bindings.get('target_ack')==='Native cast target accepted';
  report.nuiCanonicalMatch=Object.entries(expected).every(([k,v])=>isDeepStrictEqual(w?.bindings.get('echo_'+k),v))&&w?.bindings.get('echo_index')===1999&&w?.bindings.get('echo_array_after')?.length===2000&&w.bindings.get('echo_array_after').every((v,i)=>v===(i===1999));
  report.success=nuiIntegrationComplete({...report,nuiReconnectRequired:false});
  if(nuiReconnectSmoke){
   report.nuiPhases??=[];report.nuiPhases.push({connection:lobby.connection,windowId:m.result.observations.root_window_id,accepted:report.success,checks:m.result.checks,skin:m.result.skin,popup:m.result.popup,canonical:report.nuiCanonicalMatch,consumption:report.nuiSpellConsumption,retired:m.result.observations.retired??null});
   if(report.success&&report.nuiPhases.length===1){lifecycleStage='export';send({kind:'lifecycle-export'});return;}
   if(report.success&&report.nuiPhases.length===2){await network.exportCharacter();report.nuiReconnectVerified=report.characterSaves.length>=3&&new Set(report.characterSaves.map(v=>v.id)).size===1&&report.characterReads.some(v=>v.connection===lobby.connection&&v.source==='vault'&&v.sha256===report.characterSaves[1]?.sha256)&&report.nuiStaleInputs?.some(v=>v.connection===report.nuiPhases[0].connection&&v.current===lobby.connection)&&m.result.observations.retired?.windows===0&&m.result.observations.retired?.resources===0;lifecycleStage='closing';}
   report.success=nuiIntegrationComplete(report);
  }
  await stop(report.success?0:1,report.success?null:'Native NUI live check did not complete');return;
 }
 if(m.kind==='status-tested'&&buffSmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){
  report.buffTest=m.result;report.buffTestConnection=lobby.connection;const {networkEffectIcons}=await import('../../src/network_buff_bar.js'),actor=network.world.registry.get(network.world.localObjectId),canonical=networkEffectIcons(actor),nativeRows=Object.entries(m.result.rows).map(([id,row])=>({id:Number(id),state:row.state})).sort((a,b)=>a.id-b.id);
  report.buffCanonicalMatch=m.result.actorId===network.world.localObjectId&&isDeepStrictEqual(canonical,nativeRows);report.buffCanonical=canonical;
  report.success=buffIntegrationComplete({...report,buffReconnectRequired:false});report.buffPhases??=[];report.buffPhases.push({connection:lobby.connection,accepted:report.success,canonical:report.buffCanonicalMatch,checks:m.result.checks,observations:m.result.observations});
  if(report.success&&report.buffPhases.length===1){lifecycleStage='export';send({kind:'lifecycle-export'});return;}
  if(report.success&&report.buffPhases.length===2){await network.exportCharacter();report.buffReconnectVerified=report.characterSaves.length>=3&&new Set(report.characterSaves.map(v=>v.id)).size===1&&report.characterReads.some(v=>v.connection===lobby.connection&&v.source==='vault'&&v.sha256===report.characterSaves[1]?.sha256);lifecycleStage='closing';}
  report.success=buffIntegrationComplete(report);await stop(report.success?0:1,report.success?null:'Native status HUD integration did not complete');return;
 }
 if(m.kind==='roster-tested'&&partySmoke&&loaded&&m.areaId===loaded.areaId&&m.generation===loaded.generation){
  const {networkPartyRows}=await import('../../src/network_party_view.js'),rows=networkPartyRows(network.world).map(({id,self,available,health,canLevelUp})=>({id,self,available,health,canLevelUp})),nativeRows=m.result.rows.map(({id,self,available,health,canLevelUp})=>({id,self,available,health,canLevelUp}));
  report.partyTest=m.result;report.partyTestConnection=lobby.connection;report.partyCanonicalMatch=isDeepStrictEqual(rows,nativeRows)&&m.result.actorId===network.world.localObjectId;report.partyPhases??=[];
  const accepted=partyIntegrationComplete(report,false);
  report.partyPhases.push({connection:lobby.connection,accepted,canonical:report.partyCanonicalMatch,test:m.result});report.success=accepted;
  if(accepted&&report.partyPhases.length===1){lifecycleStage='export';send({kind:'lifecycle-export'});return;}
  if(accepted&&report.partyPhases.length===2){await network.exportCharacter();report.partyReconnectVerified=report.characterSaves.length>=3&&new Set(report.characterSaves.map(v=>v.id)).size===1&&report.characterReads.some(v=>v.connection===lobby.connection&&v.source==='vault'&&v.sha256===report.characterSaves[1]?.sha256);lifecycleStage='closing';}
  report.success=partyIntegrationComplete(report);
  await stop(report.success?0:1,report.success?null:'Native party HUD integration did not complete');return;
 }
 validateCommand(m,current());if(!booted||loaded?.generation!==m.generation)throw Error('Native area is not loaded');
 const base={areaId:m.areaId,areaGeneration:m.generation};
 if(['weather-create','weather-release'].includes(m.kind)){
  if(m.transferId!==loaded.transferId)throw Error('Stale native weather ticket');
  if(weatherSmoke){report.weatherModelCommands??=[];report.weatherModelCommands.push(structuredClone(m));}
  const owner=environmentDelivery?.weather?.models;if(!owner)throw Error('Native weather owner is unavailable');
  if(m.kind==='weather-create')await owner.activate(m);else await owner.release(m);
 }
 else if(m.kind==='world-audio-resource')await worldAudio?.request(m);
 else if(m.kind==='world-audio-observed')worldAudio?.observe(m);
 else if(m.kind==='client-dummy-probe'){
  if(!pointVisualSmoke||m.transferId!==loaded.transferId)throw Error('Private dummy probe requires owned local smoke mode');
  const actor=network.world.registry.get(network.world.localObjectId),pose=nativePose(actor);if(!pose)throw Error('Private dummy probe requires the admitted player');
  report.privateDummyProbe??=[];report.privateDummyProbe.push({scope:'Authored local adapter probe, not a server packet',connection:lobby.connection});
  await visualDelivery.instant({visualId:69,targetId:0x7f000000,position:[pose.position[0],-pose.position[2],pose.position[1]]});
 }
 else if(m.kind==='client-dummy-status')visualDelivery?.dummies?.status(m);
 else if(m.kind==='visual-status')visualDelivery?.status(m);
 else if(m.kind==='visual-diagnostic'){if(report.visuals.diagnostics?.length<128)report.visuals.diagnostics.push({code:m.code,detail:m.detail,effectId:m.effectId});}
 else if(m.kind==='visual-model-created')await visualDelivery?.modelCreated(m);
 else if(m.kind==='visual-model-release')await visualDelivery?.modelReleased(m);
 else if(m.kind==='spellbook-open')await spellbook.open();
 else if(m.kind==='inventory-open')await inventory.open();
 else if(m.kind==='inventory-close')await inventory.close();
 else if(m.kind==='inventory-page')await inventory.choose(m);
 else if(m.kind==='inventory-container')await inventory.container(m);
 else if(m.kind==='inventory-store')await inventory.store.command(m);
 else if(m.kind==='sheet-open')await characterSheet.open(m);
 else if(m.kind==='sheet-close')await characterSheet.close();
 else if(m.kind==='sheet-page')await characterSheet.choose(m);
 else if(m.kind==='sheet-assign')await characterSheet.assign(m);
 else if(m.kind==='map-open')await areaMap.open();
 else if(m.kind==='map-close')await areaMap.close();
 else if(m.kind==='journal-open')await journal.open();
 else if(m.kind==='journal-close')await journal.close();
 else if(m.kind==='journal-page')await journal.choose(m);
 else if(m.kind==='party-menu')await party.menu(m);
 else if(m.kind==='party-target')await party.target(m);
 else if(m.kind==='party-rest')await party.rest(m);
 else if(m.kind==='players-open')await players.open();
 else if(m.kind==='players-close')players.close();
 else if(m.kind==='players-attitude')await players.attitude(m);
 else if(m.kind==='level-open')await levelup.open();
 else if(m.kind==='level-page')await levelup.navigate(m);
 else if(m.kind==='level-control')await levelup.edit(m);
 else if(m.kind==='level-submit')await levelup.submit(m);
 else if(m.kind==='level-cancel')await levelup.cancel();
 else if(m.kind==='inventory-activate')await inventory.activate(m.viewId,m.entryId);
 else if(m.kind==='inventory-action')await inventory.action(m);
 else if(m.kind==='inventory-menu'){const selected=inventory.selected(m.viewId,m.entryId);await actions.open({requestId:m.requestId,targetId:selected.row.object.id,position:[0,0,0],inventory:true});}
 else if(m.kind==='spellbook-close')spellbook.close();
 else if(m.kind==='spellbook-query')await spellbook.query(m);
 else if(m.kind==='book-family')await spellbook.familyChoice(m);
 else if(m.kind==='book-family-back')await spellbook.familyBack(m);
 else if(m.kind==='book-inspect')await spellbook.inspect(m);
 else if(m.kind==='book-activate')await spellbook.activate(m);
 else if(m.kind==='book-prepare'||m.kind==='book-clear')await spellbook.prepare({...m,clear:m.kind==='book-clear'});
 else if(m.kind==='quickbar-assign')await spellbook.assign(m);
 else if(m.kind==='quickbar-menu')await shortcutChoices.open(m);
 else if(m.kind==='inventory-shortcut'){const button=await spellbook.assignInventory(m,inventory);(report.inventoryShortcutAssignments??=[]).push({connection:lobby.connection,index:m.index,button:structuredClone(button)});}
 else if(m.kind==='radial-shortcut'){
  if(inventorySmoke){const power=actions.currentMenu(m.menuId).target;report.inventoryPowerBefore={itemId:power.id,stack:power.item.stackSize??power.item.field454,properties:structuredClone(power.item.properties)};}
  const button=await spellbook.assignRadial(m);(report.radialShortcutAssignments??=[]).push({connection:lobby.connection,index:m.index,button:structuredClone(button)});
 }
 else if(m.kind==='quickbar-activate'){const button=structuredClone(spellbook.quickCurrent(m.quickbarId).buttons[m.index]);await spellbook.quickActivate(m);report.shortcutActivations??=[];report.shortcutActivations.push({connection:lobby.connection,index:m.index,button});}
 else if(m.kind==='quickbar-clear'||m.kind==='quickbar-move')await spellbook.quickEdit({...m,clear:m.kind==='quickbar-clear'});
 else if(m.kind==='radial-open')await actions.open(m);
 else if(m.kind==='radial-select')await actions.select(m);
 else if(m.kind==='radial-back')actions.back(m);
 else if(m.kind==='radial-cancel')actions.cancel(m);
 else if(m.kind==='target-hover')actions.hover(m);
 else if(m.kind==='target-select')await actions.selectTarget(m);
 else if(m.kind==='target-cancel')actions.cancelTarget(m);
 else if(m.kind==='cursor-request'){
  const owned=network,connection=lobby.connection;
  const image=await win.webContents.executeJavaScript(`window.godotLocalStaging.cursor(${m.cursorId})`);
  if(image&&network===owned&&current()?.connection===connection&&current()?.areaId===m.areaId&&current()?.generation===m.generation)send({kind:'cursor-image',areaId:m.areaId,generation:m.generation,cursorId:m.cursorId,image:image.url});
 }else if(m.kind==='drive'||m.kind==='drive-preview-request'){
  const session=network,connection=lobby.connection,area=loaded,owned=()=>session===network&&!session.closed&&lobby.connection===connection&&loaded===area&&current()?.generation===m.generation&&current()?.areaId===m.areaId;
  if(m.kind==='drive')driveQueue=driveQueue.then(async()=>{
   if(!owned())return;
   const result=await session.keyboardMove({...base,actorId:m.actorId,operation:m.operation,position:m.operation==='drive'?m.position.slice(0,2):m.position,heading:m.heading,flags:m.flags,transmit:m.transmit});
   if(!owned())return;
   send({kind:'drive-ack',areaId:m.areaId,generation:m.generation,transferId:area.transferId,actorId:m.actorId,requestId:m.requestId,lifetime:m.lifetime,...result});
   report.driveCommands.push({connection,areaId:m.areaId,generation:m.generation,operation:m.operation,flags:m.flags,transmit:result.sent,sequence:result.sequence});
  }).catch(error=>{if(owned())send({kind:'error',text:error.message});});
  if(m.operation==='drive'){
   const result=await measure('driveCollision',()=>win.webContents.executeJavaScript(`window.godotLocalStaging.drive.preview(${JSON.stringify(m)})`));
   if(owned()){send({kind:'drive-preview',areaId:m.areaId,generation:m.generation,transferId:area.transferId,actorId:m.actorId,requestId:m.requestId,lifetime:m.lifetime,result});report.drivePreviews.push({connection,requestId:m.requestId,actorId:m.actorId,blocked:result?.path===null,factor:result?.path?.factor,resendFraction:result?.path?.resendFraction});}
  }
 }else if(m.kind==='path'){
  const row=movementRecords.get(m.actorId),session=network,connection=lobby.connection,area=loaded;
  if(!row||row.revision!==m.revision)return;
  const owned=()=>network===session&&!session.closed&&lobby.connection===connection&&loaded===area&&movementRecords.get(m.actorId)===row;
  const request={...m,state:{...m.state,sequence:row.changes.actionFlag??0},path:row.changes.path,serverPosition:row.changes.position??row.initial.position};
  const result=await measure('serverPathAdmission',()=>win.webContents.executeJavaScript(`window.godotLocalStaging.drive.admit(${JSON.stringify(request)})`));
  if(owned()){send({kind:'path-result',areaId:m.areaId,generation:m.generation,transferId:area.transferId,actorId:m.actorId,requestId:m.requestId,revision:m.revision,result});report.pathAdmissions.push({connection,actorId:m.actorId,revision:m.revision,accepted:Boolean(result)});}
 }else if(m.kind==='walk')await network.walkTo({...base,position:[m.position[0],-m.position[2],m.position[1]],run:true});
 else if(m.kind==='chat')await network.chat({...base,actorId:network.world.localObjectId,channel:m.channel??1,text:m.text,...(m.channel===4?{recipient:m.recipient}:{})});
 else if(m.kind==='examine')await network.examine({...base,actorId:network.world.localObjectId,targetId:m.targetId});
 else if(m.kind==='reply')await network.replyDialog({...base,entryId:m.entryId,replyId:m.replyId,abort:m.abort});
 else await actions.defaultInteraction({targetId:m.targetId,position:[0,0,0],run:true});
 report.commands.push({kind:m.kind,areaId:m.areaId,generation:m.generation});
}
async function syncContent(session,connection,area){
 const scope=content.scope,active=()=>!stopping&&network===session&&lobby.connection===connection&&!session.closed&&loaded===area&&content.scope===scope&&session.areaGeneration===area.generation&&session.world.areaId===area.areaId;
 const snapshot=await measure('contentSnapshot',()=>win.webContents.executeJavaScript('window.godotLocalStaging.content.snapshot()'));
 if(!active()||snapshot.areaId!==area.areaId||snapshot.generation!==area.generation)return;
 const plan=content.plan(snapshot);
 if(!plan.remove.length&&!plan.upserts.length)return;
 let bundle=null,resources=[],particleAdd=[];
 if(plan.upserts.length){
  const exported=await measure('contentExport',()=>win.webContents.executeJavaScript(`window.godotLocalStaging.content.export(${JSON.stringify(plan.upserts)},${JSON.stringify('delta_'+(content.sequence+1)+'_')})`));
  if(!active()||!exported)return;
  if(transitionSmoke&&contentStage==='pending-transition'&&plan.upserts.some(row=>row.id===probeId)){
   report.pendingContentRace={connection,areaId:area.areaId,generation:area.generation,resources:exported.manifest.inventory.find(row=>row.id===probeId)?.resources,discarded:false};
   await fixtureCommand('to-b','-native-b');await pause(1500);
   if(!active()){report.pendingContentRace.discarded=true;return;}
   throw Error('Server did not transition during pending model preparation');
  }
  exported.manifest.live.connection=connection;resources=exported.manifest.inventory;
  particleAdd=exported.manifest.particles?.emitters??[];
  bundle=await measure('contentBundleWrite',()=>require('./external-bundle.cjs').writeExternalGodotBundle(exported,{registerLatest:false}));
 }
 if(!active())return;
 const after=await win.webContents.executeJavaScript('window.godotLocalStaging.content.snapshot()');
 if(!active()||after.areaId!==area.areaId||after.generation!==area.generation||!content.valid(plan,after))return;
 const sequence=content.commit(plan);
 await particleDelivery?.patch({removeObjects:[...plan.remove,...plan.upserts.map(row=>row.id)],add:particleAdd});
 if(!active())return;
 send({kind:'content',areaId:area.areaId,generation:area.generation,transferId:area.transferId,sequence,upserts:plan.upserts,remove:plan.remove,...(bundle?{scene:bundle.scene,sha256:bundle.sha256,metadataSha256:bundle.metadataSha256}:{}),...(contentSmoke?{screenshot:reportName.replace(/\.json$/,`-c${connection}-a${area.transferId}-content-${sequence}.png`)}:{})});
 report.contentUpdates.push({connection,areaId:area.areaId,generation:area.generation,sequence,upserts:plan.upserts,remove:plan.remove,meshes:bundle?.counts.meshes??0,resources});
}
async function tick(){
 if(stopping||busy||!network||!auth)return;busy=true;
 const session=network,connection=lobby.connection,active=()=>network===session&&lobby.connection===connection&&!session.closed;
 let workScope=null;
 try{
  if(network.closed){await particleDelivery?.close();particleDelivery=null;booted=false;if(loaded){send({kind:'loading',text:'Disconnected from local server'});loaded=null;currentArea=null;}return;}
  const live=current();
  if(['area-loading','playing'].includes(session.phase)&&Number.isInteger(live.areaId)&&live.areaId>=0){
   const followed=worldTransfer.follow(live),scope=followed.scope;
   workScope=scope;
   const scoped=()=>active()&&worldTransfer.matches(scope,current());
   if(followed.changed){
    await particleDelivery?.close();particleDelivery=null;
    actions?.reset();spellbook?.reset();inventory?.reset();characterSheet?.reset();levelup?.reset();areaMap?.reset();journal?.reset();players?.reset();
    booted=false;loaded=null;currentArea=null;origin=null;chatSeen=false;lastPoseAt=0;report.nativePresentation=null;
    movementRecords.clear();
    content.reset(scope.serial,[]);
    send({kind:'loading',...live,transferId:scope.serial,text:'Loading local server area…'});
    await win.webContents.executeJavaScript('window.godotLocalStaging.resume()');
    if(!scoped())return;
   }
   if(!worldTransfer.bundle){
   const snapshot=await win.webContents.executeJavaScript('window.godotLocalStaging.snapshot()');
   if(!scoped())return;
   const readiness=(await import('./staging-readiness.mjs')).stagingReadiness(snapshot,scope);
   const preparation={connection,...snapshot,ready:readiness.ready};
   if(JSON.stringify(preparation)!==JSON.stringify(report.sourcePreparation?.at(-1))){report.sourcePreparation??=[];if(report.sourcePreparation.length<256)report.sourcePreparation.push(preparation);if(!readiness.ready)send({kind:'status',text:readiness.reason});}
   if(readiness.ready){
    if(readiness.failedEntities.length)diagnose({code:'godot.optional-entity-preparation-failed',reason:`${readiness.failedEntities.length} entities could not be prepared; retaining the rest of the world`,entities:readiness.failedEntities});
    const generation=network.areaGeneration,areaId=network.world.areaId;
    send({kind:'status',text:'Preparing native Godot area…'});
    const exported=await win.webContents.executeJavaScript(`window.godotLocalStaging.export(${JSON.stringify({areaId:scope.areaId,generation:scope.generation})})`);
    if(!scoped()||!exported)return;
    // Assets are written outside the workspace and never embedded in reports.
    exported.manifest.live.connection=connection;exported.manifest.live.transferId=scope.serial;
    if(exported.manifest.particles)exported.manifest.particles.epoch=++particleEpoch;
    const {writeExternalGodotBundle}=require('./external-bundle.cjs');const bundle=await writeExternalGodotBundle(exported,{registerLatest:false,onProgress:progress=>{report.sourceBundleProgress??=[];report.sourceBundleProgress.push(progress);send({kind:'status',text:progress.stage==='writing-metadata'?'Writing area animation data…':progress.stage==='bundle-ready'?'Loading prepared area into Godot…':'Writing area geometry…'});}});
    if(!scoped())return;
    if(visualModelSmoke&&!report.visualResource){
     const visual=await win.webContents.executeJavaScript("window.godotLocalStaging.visualModel('c_golstone')");
     if(!scoped())return;if(!visual)throw Error('Installed visual model export was retired unexpectedly');
     const resource=await writeExternalGodotBundle(visual,{registerLatest:false});if(!scoped())return;
     report.visualResource={model:'c_golstone',...resource,scope:'Installed original model through private resource staging; native resource rendering checked separately'};
     if(visualDefinitionSmoke){
      const definition=await win.webContents.executeJavaScript(`window.godotLocalStaging.visualDefinition.probe(${JSON.stringify(network.world.localObjectId)})`);
      if(!scoped())return;if(!definition)throw Error('Installed visual definition was retired unexpectedly');
      const value=await require('./visual-definition-bundle.cjs').writeVisualDefinitionBundle(definition,{connection,areaId,generation,transferId:scope.serial});if(!scoped())return;
      report.visualDefinition={...value,live:{connection,areaId,generation,transferId:scope.serial},scope:'Installed active-table loader diagnostic only; not a server effect event or native effect roster'};
     }
    }
    const prepared={...exported.manifest.live,scene:bundle.scene,sha256:bundle.sha256,metadataSha256:bundle.metadataSha256};
    if(!worldTransfer.prepare(scope,prepared))return;
    loaded=prepared;currentArea=scope.serial;
    particleDelivery=new ParticleDelivery({scope:{connection,areaId,generation,transferId:scope.serial},data:exported.manifest.particles??{epoch:++particleEpoch,emitters:[]},wire,send,current:()=>scoped()&&loaded===prepared,diagnose:(code,reason,data)=>diagnose({code,reason,data}),report:report.particles});
    content.reset(scope.serial,exported.manifest.content);
    report.areas.push({connection,areaId,generation,transferId:scope.serial,area:loaded.area,meshes:bundle.counts.meshes,bytes:bundle.bytes,sha256:bundle.sha256,...(transitionSmoke?{inventory:exported.manifest.inventory}:{})});
    send({kind:'area',...loaded});console.log(`GODOT LOCAL AREA ${loaded.area} · ${bundle.counts.meshes} meshes`);
   }
   }
  }
  if(nui&&!nuiRefresh){nuiRefresh=nui.sync().catch(error=>{if(active())diagnose({code:'godot.nui-project-failed',reason:error.message});}).finally(()=>{nuiRefresh=null;});}
  if(booted&&loaded&&loaded.generation===network.areaGeneration){
   if(buffPreview&&!report.buffPreviewStarted){report.buffPreviewStarted=true;await session.chat({areaId:loaded.areaId,areaGeneration:loaded.generation,actorId:session.world.localObjectId,channel:1,text:'-native-buffs-start'});}
   buffs?.refresh();
   if(performance.now()-partyAt>200){partyAt=performance.now();party?.refresh();if(!playersRefresh&&players){const service=players;playersRefresh=service.refresh().catch(error=>{if(active())diagnose({code:'godot.player-list-unavailable',reason:error.message});}).finally(()=>{playersRefresh=null;});}}
   worldAudio?.follow();visualDelivery?.flush();
   if(performance.now()-lastCombatAt>100)flushCombat();
   if(!bookRefresh&&performance.now()-lastBookAt>250){lastBookAt=performance.now();const book=spellbook;bookRefresh=book.refresh().catch(error=>{if(active())send({kind:'book-notice',areaId:loaded?.areaId,generation:loaded?.generation,text:error.message});}).finally(()=>{bookRefresh=null;});}
   if(!inventoryRefresh&&inventory&&performance.now()-lastInventoryAt>150){lastInventoryAt=performance.now();const service=inventory;inventoryRefresh=service.refresh().catch(error=>{if(active())send({kind:'inventory-notice',areaId:loaded?.areaId,generation:loaded?.generation,text:error.message});}).finally(()=>{inventoryRefresh=null;});}
   if(!sheetRefresh&&characterSheet&&performance.now()-lastSheetAt>200){lastSheetAt=performance.now();const sheet=characterSheet;sheetRefresh=sheet.refresh().catch(error=>{if(active())send({kind:'sheet-notice',areaId:loaded?.areaId,generation:loaded?.generation,text:error.message});}).finally(()=>{sheetRefresh=null;});}
   if(!levelRefresh&&levelup&&performance.now()-lastLevelAt>200){lastLevelAt=performance.now();const service=levelup;levelRefresh=service.observe().catch(error=>{if(active())send({kind:'level-notice',areaId:loaded?.areaId,generation:loaded?.generation,text:error.message});}).finally(()=>{levelRefresh=null;});}
   if(!recordsRefresh&&areaMap&&journal&&performance.now()-lastRecordsAt>200){lastRecordsAt=performance.now();const map=areaMap,log=journal;recordsRefresh=Promise.all([map.refresh(),log.refresh()]).catch(error=>{if(active())diagnose({code:'godot.records-refresh-unavailable',reason:error.message});}).finally(()=>{recordsRefresh=null;});}
    const poses=[];for(const object of network.world.registry.objects.values()){if(object.areaId!==loaded.areaId)continue;const pose=nativePose(object);if(pose)poses.push({id:object.id,...pose,cameraHeight:object.objectType===5&&actions?.rules?.appearance&&Number.isInteger(object.appearance?.appearance)?nativeFloatEntry(actions.rules.appearance,object.appearance.appearance,'HEIGHT').value:1,objectType:object.objectType,cursor:worldCursorId(object,{playerId:network.world.localObjectId}),removed:Boolean(object.replicationRemoved),...(Number.isInteger(object.replicated?.animation)?{animation:object.replicated.animation,animationSpeed:object.replicated.animationSpeed??1}:{})});}
   send({kind:'poses',areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId,controlledId:network.world.localObjectId,poses});poseFrames++;
   if(radialSmoke||partySmoke){for(const [index,cast]of report.actionRequests.entries()){if(cast.connection!==lobby.connection||cast.operation!=='castSpell'||!bookSmoke&&cast.spellId!==100||cast.beforeUses<=0||report.spellConsumptions.some(row=>row.sequence===index+1))continue;const actor=network.world.registry.get(network.world.localObjectId),afterUses=networkSpellUsesLeft(actor,actions.rules,cast.spellId,cast.classIndex??0,cast.domainLevel??0,cast.metamagic??0);if(afterUses<cast.beforeUses){const observation={sequence:index+1,connection:cast.connection,spellId:cast.spellId,before:cast.beforeUses,after:afterUses};report.spellConsumptions.push(observation);report.spellConsumption??=observation;send({kind:'spell-observed',areaId:loaded.areaId,generation:loaded.generation,...observation});}}}
   if(nuiActionSmoke&&report.nuiSpellBaseline&&!report.nuiSpellConsumption&&report.nuiSpellBaseline.areaId===loaded.areaId&&report.nuiSpellBaseline.generation===loaded.generation){const actor=network.world.registry.get(network.world.localObjectId),after=networkSpellUsesLeft(actor,actions.rules,100,0,0,0);if(after<report.nuiSpellBaseline.before){report.nuiSpellConsumption={spellId:100,before:report.nuiSpellBaseline.before,after};send({kind:'interface-spell-observed',areaId:loaded.areaId,generation:loaded.generation,...report.nuiSpellConsumption});}}
   if(bookSmoke)for(const [index,p]of report.preparationRequests.entries()){if(report.preparationObservations.some(row=>row.sequence===index+1))continue;const actor=network.world.registry.get(p.actorId),slot=actor?.playerState?.spellbooks?.[p.classIndex]?.memorized?.[p.level]?.[p.slot]??null;if(JSON.stringify(slot)!==JSON.stringify(p.before))report.preparationObservations.push({sequence:index+1,...p,after:structuredClone(slot)});}
   const now=performance.now();if(lastPoseAt){const interval=now-lastPoseAt;report.poseDelivery.intervalCount++;report.poseDelivery.totalIntervalMs+=interval;report.poseDelivery.maxIntervalMs=Math.max(report.poseDelivery.maxIntervalMs,interval);}lastPoseAt=now;
   // Resource preparation must not gate the authoritative 20 Hz pose stream.
   if(!contentWork){const area=loaded,scope=worldTransfer.scope;const work=syncContent(session,connection,area).catch(error=>{if(active()&&loaded===area&&worldTransfer.matches(scope,current()))return stop(1,error.message);diagnose({code:'godot.retired-content-job',reason:'Retired model preparation ended after a world change'});}).finally(()=>{if(contentWork===work)contentWork=null;});contentWork=work;}
   if((smoke||portalRegionSmoke)&&origin){const p=nativePose(network.world.registry.get(network.world.localObjectId))?.position;report.movementDistance=p?Math.hypot(...p.map((v,i)=>v-origin[i])):0;
    if(movementReady()){
     if(portalRegionSmoke){if(portalRegionGeneration!==loaded.generation){portalRegionGeneration=loaded.generation;send({kind:'portal-region-live-test',areaId:loaded.areaId,generation:loaded.generation,final:report.nativeLoaded.length===3});}}
     else if(textSmoke){
      if(!textTestStarted){const target=[...network.world.registry.objects.values()].find(o=>o.objectType===5&&o.id!==network.world.localObjectId&&o.areaId===loaded.areaId&&!o.replicationRemoved);if(!target)throw Error('Authored gameplay speaker is absent');textTestStarted=true;send({kind:'gameplay-test-begin',areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId,targetId:target.id,radial:radialSmoke,book:bookSmoke,combat:combatSmoke,particles:particleSmoke,familyFixture:report.authoredFamilySpell??null,screenshot:reportName.replace(/\.json$/,(nuiReconnectSmoke||buffSmoke||partySmoke||shortcutReconnectSmoke||portalHandoffSmoke)?'-c'+lobby.connection+'-gameplay.png':'-gameplay.png')});}
     }else if(movementSmoke){} // Native scripted key phases finish this bounded check.
     else if(contentSmoke){if(contentStage==='movement')await fixtureCommand('spawn','-native-spawn');}
     else if(!lifecycle){report.success=integrationComplete(testMode,report);await stop(report.success?0:1,report.success?null:'Native movement evidence is incomplete');}
     else if(lifecycleStage==='first'){lifecycleStage='export';send({kind:'lifecycle-export'});}
     else if(lifecycleStage==='rejoin'&&report.nativeLoaded.length===2){lifecycleStage='closing';send({kind:'lifecycle-close'});}
    }
    else if(Date.now()-smokeAt>25000)await stop(1,'Native movement/chat smoke did not complete');
   }
   if(contentSmoke)await contentSmokeTick();
  }
 }catch(error){if(active()&&(!workScope||worldTransfer.matches(workScope,current()))){report.areaFailureStack=error.stack;await stop(1,error.message);}else diagnose({code:'godot.retired-area-job',reason:'Retired area preparation ended after the world changed'});}finally{busy=false;}
}
app.whenReady().then(async()=>{
 try{
  try{await fs.access(output);throw Error('Refusing to overwrite local test report');}catch(e){if(e.code!=='ENOENT')throw e;}
  if(nwsyncSmoke){const file=process.argv.find(v=>v.startsWith('--nwsync-fixture='))?.slice(17);if(!file||!path.isAbsolute(file))throw Error('Owned NWSync fixture descriptor required');syncFixture=JSON.parse(await fs.readFile(file,'utf8'));const url=new URL(syncFixture.url);if(syncFixture.version!==1||url.protocol!=='http:'||url.hostname!=='127.0.0.1'||!/^[a-f0-9]{40}$/.test(syncFixture.hash)||!path.isAbsolute(syncFixture.cacheDirectory)||syncFixture.entries.length!==13)throw Error('Invalid owned NWSync fixture');report.nwsyncFixture={hash:syncFixture.hash,resources:syncFixture.entries.length,reuseInstalledNWSync:false};}
  const latest=JSON.parse(await fs.readFile(path.join(project,'.cache/local-bridge/latest.json'),'utf8')),build=await fs.realpath(latest.build),relative=path.relative(path.join(project,'.cache/local-bridge'),build);
  if(!/^v[1-9][0-9]*$/.test(relative))throw Error('Unexpected staging build');
  browserSession.defaultSession.webRequest.onBeforeRequest((d,cb)=>cb({cancel:/^(https?|wss?):/.test(d.url)}));
  const {ClientSettings,defaultModsDirectory}=await import('../../electron/client_settings.mjs');const settings=new ClientSettings({directory:app.getPath('userData'),encryption:safeStorage,modsDirectory:await defaultModsDirectory(path.resolve(root,'../FullDecomp/NwnRootInstall'))});
  const loginPipe=process.argv.find(v=>v.startsWith('--private-login-pipe='))?.slice(21);
  const suppliedKeyMatches=loginPipe?await require('./private-login.cjs').savePrivateLogin(require('./private-login.cjs').connectPrivatePipe(loginPipe),settings):null;
  endpointOptions=(await import('./session-endpoint.mjs')).sessionEndpointOptions(process.argv);const endpointPolicy=endpointOptions.policy;startupServer=endpointOptions.startup;
  if(portalVaultName){if(endpointOptions.publicServers||startupServer||portalRecoveryMode)throw Error('Owned vault fixtures cannot be combined with public/recovery modes');const {validateVaultHandoffFixture}=await import('./vault-handoff-fixture.mjs');portalVaultFixture=await validateVaultHandoffFixture(JSON.parse(await fs.readFile(path.join(project,'reports',portalVaultName),'utf8')));}
  if(portalSyncFile){if(endpointOptions.publicServers||startupServer||portalRecoveryMode||!path.isAbsolute(portalSyncFile))throw Error('Invalid owned sync handoff mode');const {syncHandoffFixture}=await import('./sync-handoff-fixture.mjs');portalSyncFixture=syncHandoffFixture(JSON.parse(await fs.readFile(portalSyncFile,'utf8')));report.syncHandoffFixture={reuseInstalledNWSync:false,resources:15,manifests:portalSyncFixture.servers.map(v=>v.hash),pixels:portalSyncFixture.servers.map(v=>v.pixel)};}
  if(portalSyncRecovery)report.syncRecoveryMode=portalSyncRecovery;
  if(startupServer){report.scope='Explicitly authorized public-server Godot connection attempt; policy-bound transfers; no automatic character selection';report.endpoint=startupServer.host+':'+startupServer.port;}
  else if(endpointOptions.publicServers)report.scope='User-directed public server browser; no automatic connection or character selection';
  let publicUserDirectory;
  if(endpointOptions.publicServers||startupServer){for(const folder of ['Neverwinter Nights.0','Neverwinter Nights']){const candidate=path.join(app.getPath('documents'),folder);try{await fs.access(path.join(candidate,'nwsync','nwsyncmeta.sqlite3'));publicUserDirectory=candidate;break;}catch{}}publicUserDirectory??=path.join(app.getPath('documents'),'Neverwinter Nights');}
  const {NativeLobby}=await import('./native-lobby.mjs'),{NetworkCharacterVault}=await import('../../electron/network_character_vault.mjs');
  const vaultDirectory=(smoke||creationSmoke)?await fs.mkdtemp(path.join(os.tmpdir(),'nwn-godot-lifecycle-vault-')):path.join(app.getPath('userData'),'network-characters');
  report.vaultScope=(smoke||creationSmoke)?'Owned external temporary regression vault':'Existing application vault';
  const vault=new NetworkCharacterVault(vaultDirectory),installedCharacters=path.resolve(root,'../FullDecomp/NwnRootInstall/data/lcv');let localCatalog=new Map();
  lobby=new NativeLobby({publish:message=>{if(creationSmoke&&message.kind==='lobby'){report.creationLobbyStates??=[];report.creationLobbyStates.push({connection:message.connection,phase:message.state.phase,busy:message.state.busy,canCreate:message.state.canCreate,error:message.state.error});}if(setupService?.view&&setupService.view.scope.connection!==message.connection)setupService.reset();send({...message,auto:smoke||autoPlay});},
   listLocal:async()=>{
    const rows=[];
    for(const file of (await fs.readdir(installedCharacters)).filter(n=>/^[^/\\:\x00-\x1f]+\.bic$/i.test(n)).sort())rows.push({key:'installed:'+file,label:file.slice(0,-4)+' (installed)',source:'installed',file:path.join(installedCharacters,file)});
    for(const entry of await vault.list())rows.push({key:'vault:'+entry.id,label:entry.name+' (saved)',source:'vault',vaultId:entry.id});
    localCatalog=new Map(rows.map(row=>[row.key,row]));return rows;
   },
   readLocal:async key=>{
    const row=localCatalog.get(key),connection=lobby.connection;if(!row)throw Error('Character is not in the current local catalog');
    let bytes=await(row.source==='vault'?vault.read(row.vaultId):fs.readFile(row.file));let source=row.source;
    if(bookSmoke&&row.key==='installed:wizard.bic'){const {familyTestCharacter}=await import('./spellbook-fixture.mjs'),rules=Object.fromEntries(await Promise.all(['classes','spells'].map(async name=>[name,await textResolver.rules(name)]))),fixture=familyTestCharacter(bytes,rules);report.authoredFamilySpell={...fixture.metadata,originalSha256:crypto.createHash('sha256').update(bytes).digest('hex')};bytes=fixture.bytes;source='authored-family-fixture';}
    if(levelSmoke&&row.key==='installed:wizard.bic'){const {xpTestCharacter}=await import('./level-up-fixture.mjs'),fixture=xpTestCharacter(bytes,{exptable:await textResolver.rules('exptable')});report.levelFixture={...fixture.metadata,originalSha256:crypto.createHash('sha256').update(bytes).digest('hex')};bytes=fixture.bytes;source='authored-XP-fixture';}
    report.characterReads.push({connection,key,source,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),bytes:bytes.length});return bytes;
   },
   resolveName:value=>textResolver.raw(value),
   connect:async (connection,details={host:'127.0.0.1',port:5121,name:'GodotLocalTest',credentials:{password:''}})=>{
    const endpoint=endpointPolicy.require(details);lobby.endpoint=endpoint;report.endpoint=endpoint.host+':'+endpoint.port;
    await particleDelivery?.close();particleDelivery=null;
    textTestStarted=false;
    if(nuiReconnectSmoke||buffSmoke||partySmoke||shortcutReconnectSmoke){report.nuiSpellBaseline=null;report.nuiSpellConsumption=null;}
    loginConnection=connection;worldTransfer.clear();textDelivery?.reset();actions?.reset();driveQueue=Promise.resolve();movementRecords.clear();booted=false;loaded=null;currentArea=null;origin=null;chatSeen=false;lastPoseAt=0;report.nativePresentation=null;
    await win.webContents.executeJavaScript('window.godotLocalStaging.resume()');
    let pin;
    if(endpoint.host==='127.0.0.1'&&endpoint.port===5121){const profile=portalVaultFixture?.servers[0].profile??path.join(root,'runtime-logs/local-multiplayer-server');const log=await fs.readFile(path.join(profile,'logs/nwengineLog.txt'),'utf8');pin=log.match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];if(!pin)throw Error('Owned local server identity is absent');}
    if(connection!==lobby.connection)throw Error('Cancelled native login session');
    await controller.connect(win.webContents,{...endpoint,name:details.name,...(pin?{serverPublicKey:pin}:{}),credentials:details.credentials});
   },
   disconnect:async options=>{
    const retiring=network;await controller.disconnect(win.webContents,options);await nativeBinding?.catch(()=>{});await retiring?.delivery;
    await win.webContents.executeJavaScript('window.godotLocalStaging.settled()');
    if(network===retiring){await particleDelivery?.close();particleDelivery=null;network=null;worldTransfer.clear();content.reset(null,[]);booted=false;loaded=null;currentArea=null;send({kind:'loading',text:'Disconnected · ready to reconnect'});}
   },
   save:()=>network.exportCharacter()
  });
  const {createInstalledNetworkSession}=await import('../../electron/installed_network_session.mjs');
  nativePose=(await import('./native-object-pose.mjs')).nativeObjectPose;
  worldCursorId=(await import('../../src/game_cursor.js')).worldCursorId;
  const {ActionService}=await import('./action-service.mjs');
  const {SpellbookService}=await import('./spellbook-service.mjs');
  const {InventoryService}=await import('./inventory-service.mjs');
  const {CharacterSheetService}=await import('./character-sheet-service.mjs');
  const {LevelUpService}=await import('./level-up-service.mjs');
  const {CreationService}=await import('./creation-service.mjs');
  const {MapService}=await import('./map-service.mjs'),{JournalService}=await import('./journal-service.mjs');
  const {NuiService}=await import('./nui-service.mjs');
  const {BuffBarService}=await import('./buff-bar-service.mjs');
  const {PartyService}=await import('./party-service.mjs'),{PlayerListService}=await import('./player-list-service.mjs');
  const {parseGff}=await import('../../src/gff.js');
  const {CombatDelivery}=await import('./combat-delivery.mjs');
  ({ParticleDelivery}=await import('./particle-delivery.mjs'));
  networkSpellUsesLeft=(await import('../../src/network_spellbook.js')).networkSpellUsesLeft;
  nativeFloatEntry=(await import('../../src/movement_rate.js')).nativeFloatEntry;
  const {NetworkText}=await import('../../src/network_text.js'),{GameplayDelivery}=await import('./gameplay-delivery.mjs');
  const nativeRequests=new WeakMap();
  const {preparationDiagnosticScope}=await import('./preparation-diagnostic-scope.mjs');
  const prepareNativeSession=async(args,connection,owned=()=>connection===lobby.connection)=>{
   endpointPolicy.require(args);
   report.loginAccounts??=[];report.loginAccounts.push({connection,playerName:args.name,suppliedKeyMatches:suppliedKeyMatches?suppliedKeyMatches(args.credentials?.cdKey):null});
   const diagnosticScope=preparationDiagnosticScope({preparing:owned,connection,current:(session,c)=>network===session&&lobby.connection===c});let result;
   try{
   result=await createInstalledNetworkSession({...args,onDiagnostic:d=>{if(!diagnosticScope.allows())return;args.onDiagnostic?.(d);if(d.code?.startsWith('network.nwsync-'))diagnose(d);},...(nuiSmoke||portalNuiSmoke?{userDirectory:path.join(root,'runtime-logs/local-multiplayer-server')}:{}),...(syncFixture||portalSyncFixture?{cacheDirectory:(syncFixture??portalSyncFixture).cacheDirectory,reuseInstalledNWSync:false}:{}),persistCharacter:async message=>{
    if(network!==result.session||lobby.connection!==connection)throw Error('Character export belongs to a retired connection');
    if(shortcutReconnectSmoke){const saved=parseGff(message.data,'BIC ').root;report.shortcutExports??=[];report.shortcutExports.push({connection,sha256:crypto.createHash('sha256').update(message.data).digest('hex'),rows:structuredClone(saved.QBList??[]),lightPrepared:(saved.ClassList[0].MemorizedList0??[]).filter(v=>v.Spell===100).map(v=>v.Ready)});}
    if(characterSmoke){const root=parseGff(message.data,'BIC ').root;report.characterSheetSavedQuickbar=(root.QBList??[]).map((row,index)=>({index,type:row.QBObjectType,intParam:row.QBINTParam1})).filter(row=>row.index>=34);report.characterSheetExportSha256=crypto.createHash('sha256').update(message.data).digest('hex');}
    if(levelSmoke){const root=parseGff(message.data,'BIC ').root;report.levelExport={classes:root.ClassList.map(v=>({id:v.Class,level:v.ClassLevel})),abilities:['Str','Dex','Con','Int','Wis','Cha'].map(k=>root[k]),skills:(root.SkillList??[]).map(v=>v.Rank),feats:(root.FeatList??[]).map(v=>v.Feat),known:Object.fromEntries(root.ClassList.map(v=>[v.Class,Array.from({length:10},(_,l)=>v['KnownList'+l]??[]).flat().map(s=>s.Spell)])),sha256:crypto.createHash('sha256').update(message.data).digest('hex')};}
    if(portalVaultFixture){const saved=parseGff(message.data,'BIC ').root;report.vaultExports??=[];report.vaultExports.push({connection,firstName:saved.FirstName.entries[0]?.text,lastName:saved.LastName.entries[0]?.text,classId:saved.ClassList[0].Class,level:saved.ClassList[0].ClassLevel,bytes:message.data.length,sha256:crypto.createHash('sha256').update(message.data).digest('hex')});}
    if(creationSmoke&&creationExpected){const saved=parseGff(message.data,'BIC ').root,d=creationExpected;report.creationExports??=[];report.creationExports.push({classId:saved.ClassList[0].Class,level:saved.ClassList[0].ClassLevel,firstName:saved.FirstName.entries[0]?.text,lastName:saved.LastName.entries[0]?.text,portrait:saved.Portrait,voiceMatch:saved.SoundSetFile===d.soundset,appearanceMatch:saved.Gender===d.gender&&saved.Race===d.raceId&&saved.Appearance_Head===d.head&&saved.Phenotype===d.phenotype&&saved.Color_Skin===d.skin&&saved.Color_Hair===d.hair&&saved.Color_Tattoo1===d.tattoo1&&saved.Color_Tattoo2===d.tattoo2,abilityMatch:['Str','Dex','Con','Int','Wis','Cha'].every(k=>saved[k]===d.abilities[k]),featMatch:d.feats.every(f=>saved.FeatList.some(v=>v.Feat===f.id)),skillMatch:Object.entries(d.skills).every(([id,n])=>saved.SkillList[id]?.Rank===n),biographyMatch:saved.Description.entries[0]?.text===d.biography});}
    const entry=await vault.save(message,{id:lobby.vaultId??null});if(lobby.session===result.session)lobby.vaultId=entry.id;report.characterSaves.push({connection,id:entry.id,sha256:entry.sha256,bytes:entry.bytes});exportedKey='vault:'+entry.id;return entry;
   }});if(!diagnosticScope.allows()){await result.session.disconnect();throw Error('Cancelled native login session');}
   diagnosticScope.complete(result.session);nativeRequests.set(result.session,Object.fromEntries(['install','modsDirectory','disabledMods','userDirectory','cacheDirectory','name','sceneCapture'].filter(k=>args[k]!==undefined).map(k=>[k,args[k]])));
  if(portalVaultFixture){
   if(connection===1&&!report.vaultSeed){try{const {seedVaultHandoffFixture,verifyVaultHandoffSeed}=await import('./vault-handoff-fixture.mjs');let saved;try{saved=JSON.parse(await fs.readFile(path.join(project,'reports',portalVaultName.replace(/\.json$/,'.seed.json')),'utf8'));}catch(error){if(error.code!=='ENOENT')throw error;}report.vaultSeed=saved?await verifyVaultHandoffSeed(portalVaultFixture,saved,{identity:result.session.identity}):await seedVaultHandoffFixture(portalVaultFixture,{identity:result.session.identity,install:args.install});}catch(error){await result.session.disconnect();throw error;}}
   const {serverCharacterPlayRequest}=await import('../../src/network_character_selection.js'),reference=Buffer.from(serverCharacterPlayRequest({source:portalVaultFixture.source,resref:portalVaultFixture.reference})),write=result.session.peer.sendGameMessage.bind(result.session.peer);
   result.session.peer.sendGameMessage=bytes=>{report.vaultWire??=[];report.vaultWire.push({connection,major:bytes[1],minor:bytes[2],bytes:bytes.length,...(bytes[1]===2&&[2,17].includes(bytes[2])?{correctReference:Buffer.from(bytes).equals(reference)}:{})});return write(bytes);};
  }
   return result;
   }catch(error){diagnosticScope.cancel();throw error;}
  };
  const bindNativeSession=async(result,connection)=>{
   if(connection!==lobby.connection||result.session.closed)throw Error('Cancelled native login session');network=result.session;const session=network;
   if(creationSmoke){const decode=session.decodeMessage;session.decodeMessage=(...args)=>{const message=decode(...args);if(message.kind==='server-character-preview'){report.creationPreviewReplies??=[];report.creationPreviewReplies.push({connection,resref:message.resref,type:message.previewType,bytes:message.data.length,selected:session.selectedServerCharacter?.resref});}return message;};}
   const active=()=>network===session&&lobby.connection===connection;
   const checkActive=()=>{if(!active()||session.closed)throw Error('Cancelled native service installation');};
   if(portalSyncRecovery){const decode=session.decodeMessage;session.decodeMessage=function(...args){const message=decode.apply(this,args);if(active()&&message.kind==='server-resources'){report.syncReceivedAdvertisements??=[];report.syncReceivedAdvertisements.push({connection,hash:message.requirements.advertisement?.hash});}return message;};}
   const {EnvironmentDelivery}=await import('./environment-delivery.mjs');
   const {SkyDelivery}=await import('./sky-delivery.mjs');
   const {WeatherDelivery}=await import('./weather-delivery.mjs');
   const {WeatherModels}=await import('./weather-models.mjs');
   checkActive();
   const environmentReady=()=>booted&&loaded?.generation===session.areaGeneration&&loaded?.areaId===session.world.areaId?{connection,areaId:loaded.areaId,generation:loaded.generation,transferId:loaded.transferId}:null;
   const {WorldAudio}=await import('./world-audio.mjs');await worldAudio?.close();checkActive();report.worldAudio??=[];const audioReport={connection};report.worldAudio.push(audioReport);
   worldAudio=new WorldAudio({session,connection,active,ready:environmentReady,getResource:(...args)=>session.getResource(...args),send,diagnose:(code,reason)=>diagnose({code,reason}),report:audioReport});
   await environmentDelivery?.close();checkActive();
   const sky=new SkyDelivery({session,connection,active,ready:environmentReady,rules:name=>textResolver.rules(name),prepare:name=>win.webContents.executeJavaScript(`window.godotLocalStaging.visualModel(${JSON.stringify(name)})`),write:result=>require('./external-bundle.cjs').writeExternalGodotBundle(result,{registerLatest:false}),send:value=>{if(smoke){report.skyResources??=[];if(report.skyResources.length<128)report.skyResources.push(value);}send(value);},diagnose:(code,reason)=>diagnose({code,reason})});
   const weatherModels=new WeatherModels({session,connection,active,ready:environmentReady,prepare:name=>win.webContents.executeJavaScript(`window.godotLocalStaging.visualModel(${JSON.stringify(name)})`),write:result=>require('./external-bundle.cjs').writeExternalGodotBundle(result,{registerLatest:false}),particles:()=>particleDelivery,send:value=>{if(weatherSmoke){report.weatherModelDelivery??=[];report.weatherModelDelivery.push(value);}send(value);},diagnose:(code,reason)=>diagnose({code,reason})});
   const weather=new WeatherDelivery({session,connection,active,ready:environmentReady,models:weatherModels,rules:name=>textResolver.rules(name),send:value=>{if(weatherSmoke){report.weatherDelivered??=[];report.weatherDelivered.push(value);}send(value);},diagnose:(code,reason)=>diagnose({code,reason})});
   const environment=new EnvironmentDelivery({session,connection,active,ready:environmentReady,send,sky,weather});environmentDelivery=environment;
   textResolver=new NetworkText({world:session.world,getResource:(...a)=>session.getResource(...a),talkString:(...a)=>session.talkString(...a),diagnose:(code,reason)=>{if(active())diagnose({code,reason});}});
   const retiredCreation=await creation?.retire();checkActive();if(retiredCreation){report.creationRetiredServices??=[];report.creationRetiredServices.push(retiredCreation);}
   creation=new CreationService({lobby,session,connection,active,text:textResolver,send,preparePreview:request=>win.webContents.executeJavaScript(`window.godotLocalStaging.creationPreview(${JSON.stringify(request)})`),onPreviewPrepared:row=>{report.creationPreviewPrepared??=[];if(report.creationPreviewPrepared.length<128)report.creationPreviewPrepared.push({connection,...row});},onVoicePrepared:row=>{report.creationVoicePrepared??=[];if(report.creationVoicePrepared.length<128)report.creationVoicePrepared.push({connection,...row});},portrait:row=>win.webContents.executeJavaScript(`window.godotLocalStaging.creationPortrait(${JSON.stringify(row)})`),diagnose:(code,reason)=>diagnose({code,reason}),onSubmit:row=>{creationExpected=row.draft;report.creationSubmissions??=[];report.creationSubmissions.push({connection,createOnServer:row.createOnServer,bytes:row.bytes,classId:row.draft.classId,raceId:row.draft.raceId,firstName:row.draft.firstName,lastName:row.draft.lastName,portrait:row.draft.portrait});}});
   const delivery=new GameplayDelivery({session,connection,text:textResolver,active,feedbackOptions:()=>combatFeedback,diagnose:(code,reason)=>diagnose({code,reason}),
    send:payload=>{if(feedbackSmoke&&['floating','chat'].includes(payload.kind)){report.feedbackDeliveries??=[];if(report.feedbackDeliveries.length<200)report.feedbackDeliveries.push({connection,...payload,options:{...combatFeedback}});}send(payload);report.gameplayText[payload.kind]=(report.gameplayText[payload.kind]??0)+1;if(payload.kind==='chat'&&(payload.text??payload.rich?.text??'').includes('Godot local bridge check'))chatSeen=true;},
    portrait:async row=>win.webContents.executeJavaScript(`window.godotLocalStaging.portrait(${JSON.stringify(row)})`)});
   textDelivery=delivery;
   const {VisualDelivery}=await import('./visual-delivery.mjs');
   const {ClientDummies}=await import('./client-dummies.mjs');
   checkActive();if(visualDelivery){await visualDelivery.close();checkActive();report.visualSessions??=[];report.visualSessions.push(structuredClone(report.visuals));report.visuals={};}
   report.clientDummies??=[];const dummyReport={connection};report.clientDummies.push(dummyReport);
   const dummies=new ClientDummies({session,connection,active,ready:environmentReady,prepare:name=>win.webContents.executeJavaScript(`window.godotLocalStaging.visualModel(${JSON.stringify(name)})`),write:result=>require('./external-bundle.cjs').writeExternalGodotBundle(result,{registerLatest:false}),send,diagnose:(code,reason)=>diagnose({code,reason}),report:dummyReport});
   visualDelivery=new VisualDelivery({session,connection,active,ready:environmentReady,dummies,
    prepare:request=>win.webContents.executeJavaScript(`window.godotLocalStaging.visualDefinition(${JSON.stringify(request)})`),write:require('./visual-definition-bundle.cjs').writeVisualDefinitionBundle,
    tables:()=>textResolver.rules('visualeffects'),particles:()=>particleDelivery,send,diagnose:(code,reason)=>diagnose({code,reason}),report:report.visuals});
   const actionService=new ActionService({session,connection,text:textResolver,active,send,diagnose:(code,reason)=>diagnose({code,reason}),icon:async name=>win.webContents.executeJavaScript(`window.godotLocalStaging.icon(${JSON.stringify(name)})`),onSubmit:row=>{if(report.actionRequests.length<200)report.actionRequests.push({...row,connection});}});
   actions=actionService;
   const oldParty=await party?.retire();checkActive();if(partySmoke&&oldParty){report.partyRetiredServices??=[];report.partyRetiredServices.push(oldParty);}players?.reset();
   party=new PartyService({actions:actionService,portrait:row=>win.webContents.executeJavaScript(`window.godotLocalStaging.portrait(${JSON.stringify(row)})`),art:row=>win.webContents.executeJavaScript(`window.godotLocalStaging.mapArt(${JSON.stringify(row)})`),onRequest:row=>{report.partyRequests??=[];report.partyRequests.push({...row,connection});}});
   players=new PlayerListService({actions:actionService,onRequest:row=>{report.playerListRequests??=[];report.playerListRequests.push(row);}});
   const oldBuffs=await buffs?.retire();checkActive();if(buffSmoke&&oldBuffs){report.buffRetiredServices??=[];report.buffRetiredServices.push(oldBuffs);}buffs=new BuffBarService({session,connection,active,text:textResolver,icon:name=>actionService.icon(name),send:value=>{if(buffSmoke){report.buffDelivery??=[];report.buffDelivery.push({connection,kind:value.kind,viewId:value.viewId,effectId:value.effectId,resource:value.resource,label:value.label,...(value.image?{imageSha256:crypto.createHash('sha256').update(Buffer.from(value.image.split(',')[1],'base64')).digest('hex')}:{})});}send(value);},diagnose:(code,reason)=>diagnose({code,reason})});
   spellbook=new SpellbookService({actions:actionService,onPrepare:row=>{if(bookSmoke)report.preparationRequests.push(row);}});
   const {ShortcutChoiceService}=await import('./shortcut-choice-service.mjs');
   const {ensureShortcutStats}=await import('./shortcut-stats.mjs');
   checkActive();
   shortcutChoices=new ShortcutChoiceService({actions:actionService,shortcuts:spellbook,ensure:scope=>ensureShortcutStats(actionService,scope,()=>characterSheet),onAssign:row=>{report.shortcutMenuAssignments??=[];report.shortcutMenuAssignments.push({connection,...row});}});
   inventory?.reset();
   inventory=new InventoryService({actions:actionService,onRequest:row=>{report.inventoryRequests??=[];if(report.inventoryRequests.length<200)report.inventoryRequests.push(row);}});
   characterSheet?.reset();
   levelup?.reset();
   levelup=new LevelUpService({actions:actionService,restore:scope=>session.hudPanel({areaId:scope.areaId,areaGeneration:scope.areaGeneration,actorId:scope.actorId,panel:'character',open:Boolean(characterSheet?.opened),page:characterSheet?.page??0}),onRequest:row=>{report.levelRequests??=[];report.levelRequests.push(row);},onResult:row=>{report.levelResults??=[];report.levelResults.push(row);}});
   characterSheet=new CharacterSheetService({actions:actionService,shortcuts:spellbook,portrait:row=>win.webContents.executeJavaScript(`window.godotLocalStaging.portrait(${JSON.stringify(row)})`),onRequest:row=>{report.characterSheetRequests??=[];if(report.characterSheetRequests.length<200)report.characterSheetRequests.push(row);},onView:({id,page,scope})=>{if(!characterSmoke)return;const a=scope.actor,s=a.inventoryStats??{},r=a.replicated??{};report.characterSheetViews??=[];if(report.characterSheetViews.length<200)report.characterSheetViews.push({id,page,abilities:s.fields70??a.playerState?.abilities?.current,saves:[s.field98,s.field9a,s.field99],hp:r.hitPoints,ac:a.playerState?.combat?.armorClass,xp:s.field94,skills:structuredClone(s.skills??[]),feats:[...new Set([...(a.playerState?.feats??[]),...(a.playerState?.bonusFeats??[]),...(s.feats??[]).map(f=>f.id),...(s.fields118??[]),...(s.fields128??[])])]});}});
   areaMap?.reset();journal?.reset();
   areaMap=new MapService({actions:actionService,art:row=>win.webContents.executeJavaScript(`window.godotLocalStaging.mapArt(${JSON.stringify(row)})`),onView:({id,area})=>{report.mapViews??=[];report.mapViews.push({id,width:area.width,height:area.height,tileset:area.tileset});}});
   journal=new JournalService({actions:actionService,onRequest:row=>{report.journalRequests??=[];report.journalRequests.push(row);}});
   const retiringNui=await nui?.retire();checkActive();if(nuiReconnectSmoke&&retiringNui){report.nuiRetiredServices??=[];report.nuiRetiredServices.push(retiringNui);}
   nui=new NuiService({session,connection,active,send,text:textResolver,image:async(name,region)=>{const until=Date.now()+15000;while(active()&&!session.closed&&Date.now()<until){const value=await win.webContents.executeJavaScript(`window.godotLocalStaging.nuiImage(${JSON.stringify(name)},${JSON.stringify(region)})`);if(value)return value;await pause(50);}throw Error('Native NUI image staging was not ready');},diagnose:(code,reason)=>diagnose({code,reason}),onRequest:row=>{report.nuiRequests??=[];if(report.nuiRequests.length<500)report.nuiRequests.push({connection,...row});}});
   actionService.inventoryAction=async(action,item)=>{
    const view=inventory.view,row=view&&[...view.rows].find(([,row])=>row.object===item);
    if(!row)throw Error('Inventory item is no longer visible');
    if(action==='activate')return inventory.activate(view.id,row[0]);
    return inventory.action({viewId:view.id,entryId:row[0],operation:action});
   };
   const combat=new CombatDelivery({session,connection,active,tables:()=>actionService.tables(),send:row=>{if(row.kind==='combat-events'){report.combatInput??=[];for(const event of row.events)if(report.combatInput.length<150)report.combatInput.push({action:event.action,id:event.id,animation:event.animation,records:event.records?.length??0,ageMs:event.ageMs});}send(row);},diagnose:(code,reason)=>diagnose({code,reason})});combatDelivery=combat;
   portalAdoption.bind(session,connection);
   report.nativePortalBindings??=[];report.nativePortalBindings.push({connection,enabled:true,regression:portalHandoffSmoke});
   network.on('state',s=>{if(!active())return;creation?.observe();if(nwsyncSmoke&&s.resourceProgress){report.nwsyncProgress??=[];if(report.nwsyncProgress.length<128)report.nwsyncProgress.push({...s.resourceProgress});}if(report.states.at(-1)!==s.phase){report.states.push(s.phase);send({kind:'status',text:'Local server · '+s.phase});}});
   network.on('diagnostic',d=>{if(active())diagnose(d);});network.peer.on('diagnostic',d=>{if(active())diagnose(d);});
   network.on('message',({message,areaGeneration})=>{
    if(!active())return;
    if(message.kind==='server-character-list'){report.characterLists??=[];report.characterLists.push({connection,generation:message.generation,received:message.characters.length,uniqueReferences:new Set(message.characters.map(row=>`${row.source}:${row.resref}`)).size,accountCharacters:message.characters.filter(row=>row.source===17).length});}
    environment.receive(message);
    if(weatherSmoke&&message.kind==='area-weather'){report.weatherWire??=[];report.weatherWire.push({connection,...message});}
    if(nwsyncSmoke&&message.kind==='server-resources')report.nwsyncAdvertisement=message.requirements.advertisement;
    if(portalSyncFixture&&message.kind==='server-resources'){report.syncHandoffAdvertisements??=[];report.syncHandoffAdvertisements.push({connection,hash:message.requirements.advertisement?.hash});}
    if(feedbackSmoke&&message.kind==='damage-feedback'){report.feedbackServerDamage??=[];report.feedbackServerDamage.push({connection,...message,options:{...combatFeedback}});}
    if(message.kind==='object-updates'){publishMovement(session,session.world.presentationChanges);combat.receive(session.world.presentationChanges);visualDelivery?.receive(session.world.presentationChanges);if(combat.pending.length)flushCombat();}
    if(message.kind.startsWith('nui-')){report.nuiMessages??=[];if(report.nuiMessages.length<500)report.nuiMessages.push({kind:message.kind,token:message.token,format:message.format,...(nuiSmoke&&message.updates?{updates:message.updates.map(row=>({token:row.token,bind:row.bind,type:Array.isArray(row.value)?'array':typeof row.value,...(typeof row.value==='string'||Array.isArray(row.value)?{length:row.value.length}:{})}))}:{})});void nui.sync().catch(error=>diagnose({code:'godot.nui-project-failed',reason:error.message}));}
    if(recordsSmoke&&['journal','map-pin-created','map-pin-enabled'].includes(message.kind)){report.recordsMessages??=[];report.recordsMessages.push({kind:message.kind,operation:message.operation,id:message.id,enabled:message.enabled});}
    if(partySmoke&&message.kind==='party-list'){report.partyMembership??=[];report.partyMembership.push({connection,...message});}
    if(message.kind==='object-visual')void visualDelivery?.instant(message).catch(error=>diagnose({code:'visual.instant-delivery-failed',reason:error.message}));
    if(message.kind==='area-visual')visualDelivery?.areaInstant(message);
    if(message.kind==='script-sound')worldAudio?.receive(message);
    inventory?.receive(message);
    if(buffSmoke&&message.kind==='object-updates'){for(const row of message.records)if(row.action==='player-state'&&row.state?.effectIcons){report.buffServerIcons??=[];report.buffServerIcons.push({connection,actorId:row.id,...structuredClone(row.state.effectIcons)});}}
    if(characterSmoke&&message.kind==='object-updates'){for(const row of message.records)if(row.action==='inventory-stats'){report.characterSheetStatRecords??=[];if(report.characterSheetStatRecords.length<200)report.characterSheetStatRecords.push({id:row.id,mask:row.mask,keys:Object.keys(row.state)});}}
    if(['store-open','store-close','store-transaction'].includes(message.kind)){report.storeMessages??=[];report.storeMessages.push({...message});}
    if(storeSmoke&&message.kind==='examine'&&message.type==='item'){report.storeExaminations??=[];report.storeExaminations.push({targetId:message.targetId,identified:message.identified});}
    if(storeSmoke&&message.kind==='object-updates'){const rows=message.records.filter(row=>row.action==='inventory'&&row.channel==='M').map(({item,...row})=>row);if(rows.length){report.storeInventoryRecords??=[];if(report.storeInventoryRecords.length<100)report.storeInventoryRecords.push(rows);}}
    if(message.kind==='container-status'){report.containerStatuses??=[];report.containerStatuses.push({targetId:message.targetId,primary:message.primary});}
    if(message.kind==='inventory-result'){report.inventoryResults??=[];report.inventoryResults.push({connection,itemId:message.itemId,operation:message.operation,success:message.success,alternate:message.alternate});}
    if(shortcutReconnectSmoke&&message.kind==='object-updates')for(const row of message.records)if(row.action==='player-state'&&row.state?.memorizedSpellChanges){const changes=row.state.memorizedSpellChanges.filter(v=>v.position===0).flatMap(v=>v.added).filter(v=>v.spell===100&&v.level===0);if(changes.length){report.shortcutPreparedUpdates??=[];if(report.shortcutPreparedUpdates.length<30)report.shortcutPreparedUpdates.push({connection,id:row.id,changes:structuredClone(changes)});}}
    if(inventorySmoke&&message.kind==='combat-feedback'&&report.actionRequests.some(v=>v.connection===connection&&v.operation==='useSkill')){report.skillFeedback??=[];if(report.skillFeedback.length<100)report.skillFeedback.push({connection,...message});}
    if(inventorySmoke&&message.kind.startsWith('dialog-')&&report.actionRequests.some(v=>v.connection===connection&&v.operation==='useSkill'&&v.packedSkill===22)){report.skillDialogs??=[];if(report.skillDialogs.length<20)report.skillDialogs.push({connection,...message});}
    if(['camera-location','camera-mode','camera-store','camera-restore','camera-height','camera-lock','camera-limits','camera-attach','camera-flags'].includes(message.kind)){
     if(cameraSmoke||cameraCommandSmoke){report.cameraServerCommands??=[];report.cameraServerCommands.push({connection,...message});}send(message);
    }
    if(message.kind==='script-targeting')void actionService.serverTarget().catch(error=>{if(active())send({kind:'error',text:error.message});});
    if(['server-speech','system-notice','examine','combat-feedback','spell-feedback','damage-feedback','attack-feedback','initiative-feedback'].includes(message.kind)||message.kind.startsWith('dialog-'))void delivery.receive(message,areaGeneration);
   });if(connection!==lobby.connection){await session.disconnect();throw Error('Cancelled native login session');}lobby.attach(session,connection);return result;
  };
  const installNativeSession=(result,connection)=>{
   const work=bindNativeSession(result,connection).catch(async error=>{await result.session.disconnect();throw error;});nativeBinding=work;
   return work.finally(()=>{if(nativeBinding===work)nativeBinding=null;});
  };
  const {NativePortalAdoption}=await import('./portal-adoption.mjs');
  const retireForPortal=async(connection)=>{
   worldTransfer.clear();content.reset(null,[]);booted=false;loaded=null;currentArea=null;origin=null;chatSeen=false;lastPoseAt=0;report.nativePresentation=null;textTestStarted=false;
   textDelivery?.reset();actions?.reset();spellbook?.reset();inventory?.reset();characterSheet?.reset();levelup?.reset();areaMap?.reset();journal?.reset();players?.reset();movementRecords.clear();
   const pending=[contentWork,combatWork,bookRefresh,inventoryRefresh,sheetRefresh,levelRefresh,recordsRefresh,nuiRefresh,playersRefresh,driveQueue].filter(Boolean);
   const cleanup=await Promise.allSettled([creation?.retire(),visualDelivery?.close(),nui?.retire(),buffs?.retire(),party?.retire(),particleDelivery?.close(),...pending,environmentDelivery?.close(),worldAudio?.close()]);
   if(connection!==lobby.connection||stopping)throw Error('Cancelled native portal cleanup');
   const rejected=cleanup.find(v=>v.status==='rejected');if(rejected)throw Error('Native portal service cleanup failed');
   report.portalCleanup??=[];report.portalCleanup.push({connection,pending:pending.length,settled:cleanup.length,nui:cleanup[2]?.value,remainingThreads:particleDelivery?.workers?.slots.filter(v=>v.worker.threadId>=0).length??0});
   creation=null;visualDelivery=null;nui=null;buffs=null;party=null;players=null;particleDelivery=null;environmentDelivery=null;worldAudio=null;textDelivery=null;actions=null;spellbook=null;inventory=null;characterSheet=null;levelup=null;areaMap=null;journal=null;combatDelivery=null;
   driveQueue=Promise.resolve();
   await win.webContents.executeJavaScript('window.godotLocalStaging.settled()');
   if(connection!==lobby.connection||stopping)throw Error('Cancelled native portal frontend cleanup');
   await win.webContents.executeJavaScript('window.godotLocalStaging.resume()');
  };
  const portalAdoption=new NativePortalAdoption({lobby,policy:endpointPolicy,config:session=>nativeRequests.get(session),owns:(session,connection)=>!stopping&&network===session&&lobby.connection===connection,prepare:prepareNativeSession,
   install:async(next,connection)=>{
    if(portalRecoveryMode&&connection===2){
     report.portalRecoveryMode=portalRecoveryMode;
     if(portalRecoveryMode==='cancel'){
      await new Promise(resolve=>{portalRecoveryRelease=resolve;send({kind:'portal-recovery-test',mode:'cancel',screenshot:output.replace(/\.json$/,'-recovery')});});
      if(lobby.connection!==connection||next.session.closed||stopping)throw Error('Cancelled native portal test adoption');
     }else{
      const request=output.replace(/\.json$/,'.stop-destination.json'),ack=output.replace(/\.json$/,'.destination-stopped.json');
      await fs.writeFile(request,JSON.stringify({kind:'owned-handoff-stop',connection,host:next.host,port:next.port})+'\n',{flag:'wx'});
      const until=Date.now()+15000;let confirmed=false;
      while(Date.now()<until){try{const v=JSON.parse(await fs.readFile(ack,'utf8'));if(v.port!==5122||v.stopped!==true)throw Error('Invalid owned destination stop acknowledgement');confirmed=true;break;}catch(error){if(error.code!=='ENOENT')throw error;}await pause(50);}
      if(!confirmed){void stop(1,'Owned destination stop acknowledgement did not arrive');throw Error('Owned destination stop acknowledgement did not arrive');}report.portalRecoveryStopped=true;
     }
    }
    report.endpoint=next.host+':'+next.port;loginConnection=connection;await retireForPortal(connection);await installNativeSession(next,connection);
    if(portalRecoveryMode==='failure'&&connection===2)send({kind:'portal-recovery-test',mode:'failure',screenshot:output.replace(/\.json$/,'-recovery')});
   },
   failed:async(session,connection,previous)=>{if((network===session||network===previous)&&lobby.connection===connection){await nativeBinding?.catch(()=>{});await retireForPortal(connection);if(lobby.connection===connection&&(network===session||network===previous)){network=null;send({kind:'loading',text:'Server transfer failed · reconnect to try again'});}}},
   onEvent:event=>{report.portalAdoptions??=[];report.portalAdoptions.push(event);}});
  controller=require('../../electron/network_ipc.cjs').registerNetworkIpc(ipcMain,{applicationUrl:pathToFileURL(path.join(build,'index.html')).href,defaultInstall:path.resolve(root,'../FullDecomp/NwnRootInstall'),userDirectory:publicUserDirectory??null,...(publicUserDirectory?{cacheDirectory:path.join(app.getPath('userData'),'server-content')}:{}),clientSettings:settings,characterVault:vault,chooseInstall:async()=>null,createSession:async args=>{
   const connection=loginConnection;return installNativeSession(await prepareNativeSession(args,connection),connection);
  },onPortalSession:event=>{
   if(originGc)retiredOrigins.push({connection:lobby.connection,session:new WeakRef(event.previous),world:new WeakRef(event.previous.world)});
   report.portalCharacters??=[];report.portalCharacters.push({originConnection:lobby.connection,originReleased:event.previous.closed&&event.previous.portalHandoffReady,kind:event.next.session.character?'bic':'reference',bytes:event.next.session.character?.length??0,source:event.next.session.portalCharacter?.source??null,...(portalVaultFixture?{resref:event.next.session.portalCharacter?.resref}:{} )});
   if(portalSyncRecovery){const session=event.next.session,connect=session.connect;report.syncRecoveryConnects=0;session.connect=async function(options){report.syncRecoveryConnects++;return connect.call(this,options);};session.once('closed',()=>{report.syncRecoveryDestinationClosed=true;report.syncRecoveryCharacterWiped=session.character===null;report.syncRecoveryJoinWhileClosing=lobby.snapshot().canJoin;});}
   if(portalRecoveryMode){const session=event.next.session,connect=session.connect;report.portalRecoveryConnects=0;session.connect=async function(options){report.portalRecoveryConnects++;return connect.call(this,options);};session.once('closed',()=>{report.portalRecoveryDestinationClosed=true;report.portalRecoveryCharacterWiped=session.character===null;report.portalRecoveryJoinWhileClosing=lobby.snapshot().canJoin;});}
   const work=portalAdoption.adopt(event);portalAdoptionWork=work;return work.finally(()=>{if(portalAdoptionWork===work)portalAdoptionWork=null;});
  },onPortalConnected:event=>portalAdoption.connected(event),onPortalFailure:event=>portalAdoption.fail(event)});
  win=new BrowserWindow({show:false,width:1440,height:960,webPreferences:{preload:path.join(root,'electron/preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true,backgroundThrottling:false,offscreen:true}});controller.attach(win);win.webContents.setFrameRate(30);
  if(settingsSmoke){const {settingsFixture}=await import('./settings-fixture.mjs');setupFixture=await settingsFixture({directory:await fs.mkdtemp(path.join(os.tmpdir(),'nwn-godot-settings-')),encryption:safeStorage,profileFile:path.join(app.getPath('userData'),'client-settings.json')});}
  const {SettingsService}=await import('./settings-service.mjs');setupService=new SettingsService({store:setupFixture?.store??settings,connection:()=>lobby.connection,locked:()=>Boolean(lobby.busy||network&&!network.closed),send,invalidateResources:()=>controller.invalidateLobbyResources(win.webContents),onSave:async row=>{report.settingsMutations??=[];report.settingsMutations.push(row);await setupFixture?.saved(row);}});
  win.webContents.on('console-message',(_e,level,message)=>{if(/^GODOT_SOURCE_EXPORT [a-z-]+$/.test(message))report.sourceExportStage=message.slice(20);if(level>=3&&report.rendererErrors.length<20)report.rendererErrors.push(message);});
  await win.loadFile(path.join(build,'index.html'));
  const {ServerBrowserStore}=await import('./server-browser-store.mjs'),{ServerBrowserService}=await import('./server-browser-service.mjs'),{queryNetworkServer,fetchNetworkServerList}=await import('../../electron/server_browser.mjs');
  serverBrowser=new ServerBrowserService({lobby,policy:endpointPolicy,playerName:process.argv.some(v=>v.startsWith('--player-name='))?endpointOptions.name:null,store:new ServerBrowserStore((smoke||creationSmoke)?path.join(await fs.mkdtemp(path.join(os.tmpdir(),'nwn-godot-browser-')),'browser.json'):path.join(app.getPath('userData'),'native-server-browser.json'),{importLegacy:()=>smoke||creationSmoke?Promise.resolve({}):win.webContents.executeJavaScript(`(() => { const read = name => { try { const rows = JSON.parse(localStorage.getItem('nwn.multiplayer.'+name)??'[]'); return Array.isArray(rows)?rows.slice(0,100):[]; } catch { return []; } }; return {history:read('history'),favorites:read('favorites')}; })()`)}),query:queryNetworkServer,discover:fetchNetworkServerList,settings:()=>settings.status(),send,onEvent:row=>{report.browserEvents??=[];report.browserEvents.push(row);}});
  report.nativeSelectionOwner=await win.webContents.executeJavaScript('window.godotLocalStaging.nativeSelectionOwner()');if(report.nativeSelectionOwner!==true)throw Error('The hidden resource frontend still owns character selection');
  temp=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-godot-local-'));token=crypto.randomBytes(32).toString('hex');
  server=net.createServer(socket=>{
   if(wire||socket.remoteAddress!=='127.0.0.1'){socket.destroy();return;}
   wire=new JsonLines(socket);socket.setTimeout(10000,()=>{if(!auth)socket.destroy();});socket.on('close',()=>{if(!stopping)void stop(1,'Native client connection closed');});
   wire.on('message',m=>void command(m).catch(async e=>{
    if(m.kind==='hello'){void stop(1,'Native bridge authentication failed');return;}
    report.rejectedCommands??=[];if(report.rejectedCommands.length<256)report.rejectedCommands.push({kind:m.kind,connection:m.connection,reason:e.message});
    if(m.connection===lobby.connection&&m.kind==='browser-input'){await serverBrowser?.render();send({kind:'browser-notice',text:e.message});return;}
    if(m.connection===lobby.connection&&m.kind==='creation-input'){diagnose({code:'godot.creation-input-rejected',reason:m.operation+': '+e.message});send({kind:'creation-notice',text:e.message});await creation?.render();return;}
    if(m.connection===lobby.connection&&m.kind==='nui-input'){diagnose({code:'godot.nui-input-rejected',reason:m.operation+': '+e.message});send({kind:'nui-notice',windowId:m.windowId,text:e.message});return;}
    if(m.connection===lobby.connection&&['party-menu','quickbar-menu'].includes(m.kind))send({kind:'action-error',requestId:m.requestId,areaId:m.areaId,generation:m.generation,text:e.message});
    if(m.connection===lobby.connection&&m.kind==='party-target')send({kind:'target-error',token:m.token,areaId:m.areaId,generation:m.generation,text:e.message});
    if(m.connection===lobby.connection&&typeof m.kind==='string'&&m.kind.startsWith('inventory-')){diagnose({code:'godot.inventory-request-rejected',reason:m.kind+': '+e.message});send({kind:'inventory-notice',areaId:m.areaId,generation:m.generation,text:e.message});}
    if(m.connection===lobby.connection&&typeof m.kind==='string'&&m.kind.startsWith('sheet-')){diagnose({code:'godot.sheet-request-rejected',reason:m.kind+': '+e.message});send({kind:'sheet-notice',areaId:m.areaId,generation:m.generation,text:e.message});}
    if(m.connection===lobby.connection&&typeof m.kind==='string'&&m.kind.startsWith('level-')){diagnose({code:'godot.level-request-rejected',reason:m.kind+': '+e.message});send({kind:'level-notice',areaId:m.areaId,generation:m.generation,text:e.message});await levelup?.render();}
    if(m.connection===lobby.connection){lobby.error=e.message;lobby.emit();send({kind:'error',text:e.message});if(m.kind==='reply')send({kind:'dialog-error',areaId:m.areaId,generation:m.generation,entryId:m.entryId});if(typeof m.kind==='string'&&m.kind.startsWith('radial-'))send({kind:'action-error',requestId:m.requestId,areaId:m.areaId,generation:m.generation,text:e.message});if(typeof m.kind==='string'&&m.kind.startsWith('target-'))send({kind:'target-error',token:m.token,areaId:m.areaId,generation:m.generation,text:e.message});}
    else{if((nuiReconnectSmoke||portalNuiSmoke)&&m.kind==='nui-input'){report.nuiStaleInputs??=[];report.nuiStaleInputs.push({connection:m.connection,current:lobby.connection,operation:m.operation,windowId:m.windowId});}diagnose({code:'godot.stale-connection-input',reason:'An input from a retired native connection was ignored'});}
   }));wire.on('transportError',()=>{});wire.on('invalid',()=>void stop(1,'Invalid native bridge frame'));
  });await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});
  const ticket=path.join(temp,'ticket.json');await fs.writeFile(ticket,JSON.stringify({port:server.address().port,token}),{flag:'wx',mode:0o600});
  const verbose=process.argv.includes('--native-verbose');
  const args=['--path',project,'--rendering-method','forward_plus','--rendering-driver','vulkan',...(headless?['--headless']:[]),...(verbose?['--verbose','--log-file',output.replace(/\.json$/,'.engine.log')]:[]),'--','--local-ticket='+ticket];
  // windowsHide also suppresses the GUI window of this native executable.
  // Only explicitly headless checks should request hidden native startup.
  native=spawn(path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),args,{cwd:root,windowsHide:headless,stdio:['ignore','pipe','pipe']});
  nativeClosed=new Promise(resolve=>native.once('close',resolve));
  let nativeErrors='';native.stdout.on('data',data=>{const value=data.toString();if(verbose)report.nativeVerboseLog=((report.nativeVerboseLog??'')+value).slice(-18000);if(/LOCAL_NATIVE_LOADED/.test(value))console.log(value.trim());});native.stderr.on('data',data=>{nativeErrors=(nativeErrors+data.toString()).slice(-12000);report.nativeErrors=nativeErrors;if(/SCRIPT ERROR|Parse Error|Message queue out of memory/.test(nativeErrors)&&!stopping){void stop(1,'Native engine script or GUI queue failed');}});
  native.on('error',()=>void stop(1,'Native engine could not start'));native.on('exit',code=>{report.nativeExit=code;if(nativeErrors)report.nativeErrors=nativeErrors;if(!stopping){report.success=code===0&&(weatherSmoke?weatherRenderIntegrationComplete(report):nwsyncSmoke?nwsyncIntegrationComplete(report):cameraCommandSmoke?cameraCommandIntegrationComplete(report):cameraSmoke?cameraIntegrationComplete(report):feedbackSmoke?feedbackIntegrationComplete(report):shortcutReconnectSmoke?shortcutReconnectComplete(report):partySmoke?partyIntegrationComplete(report):integrationComplete(testMode,report));void stop(report.success?0:1,report.success?null:'Native engine exited before integration evidence completed');}});
  timer=setInterval(()=>{void tick();if((startupServer||endpointOptions.publicServers||portalRegionSmoke||portalHandoffSmoke)&&Date.now()-liveStatusAt>2000){liveStatusAt=Date.now();const state=lobby.snapshot();void fs.writeFile(output.replace(/\.json$/,'.status.json'),JSON.stringify({endpoint:report.endpoint,phase:state.phase,busy:state.busy,error:state.error,choices:state.choices.length,serverCharacterCount:network?.serverCharacters?.length??0,loginAccount:report.loginAccounts?.at(-1)??null,characterList:report.characterLists?.at(-1)??null,canSelect:state.canSelect,localAllowed:state.localAllowed,resourceProgress:state.resourceProgress,states:report.states,nativeLoaded:report.nativeLoaded,diagnostics:report.diagnostics.slice(-15),browserStatus:serverBrowser.status,sourcePreparation:report.sourcePreparation?.at(-1)??null,sourceExportStage:report.sourceExportStage??null,...(portalRegionSmoke?{portalRegionPhases:report.portalRegionPhases,commands:report.commands.slice(-8),actor:network?nativePose(network.world.registry.get(network.world.localObjectId)??{}):null}:{})})).catch(()=>{});}},50);console.log(endpointOptions.publicServers?'NATIVE PUBLIC SERVER BROWSER · choose any server':startupServer?'NATIVE AUTHORIZED SERVER STARTUP · manual character selection':autoPlay?'NATIVE LOCAL PREVIEW · automatic installed wizard admission to owned local server':'NATIVE LOCAL LOBBY READY · no automatic character upload');
  if(smoke||settingsSmoke||menuExitSmoke||creationSmoke)setTimeout(()=>{if(!stopping)void stop(1,'Local join or native settings deadline exceeded');},portalRegionSmoke?60000:shortcutReconnectSmoke?300000:180000);
 }catch(error){await stop(1,error.message);}
});
app.on('window-all-closed',()=>{});
process.on('SIGINT',()=>void stop(0));
