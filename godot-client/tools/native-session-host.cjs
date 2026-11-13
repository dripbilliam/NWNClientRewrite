// Protocol and protected-login owner only. No BrowserWindow or render staging.
const fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os'),net=require('node:net'),crypto=require('node:crypto'),{spawn}=require('node:child_process'),{registerHooks}=require('node:module'),{fileURLToPath}=require('node:url');
if(process.argv.includes('--list-flags')){const flags=require('./native-client-flags.cjs');process.stdout.write(process.argv.includes('--json')?JSON.stringify(flags.catalogue(),null,2)+'\n':flags.markdown());process.exit(0);}
const clientFlags=require('./native-client-flags.cjs');const managedClientOptions=clientFlags.validateHostOptions(process.argv.slice(2));
const performanceOptions=clientFlags.resolvePerformanceOptions(process.argv.slice(2),{env:process.env});
const featureManifest=require('./native-feature-manifest.cjs');let startupFeatureManifest=null,featureWorldScope='';
const project=path.resolve(__dirname,'..'),root=path.dirname(project),loaded=new Set();
const {previewProofMatches}=require('./native-character-preview-proof.cjs');
registerHooks({resolve(specifier,context,next){const value=next(specifier,context);if(specifier==='three'||specifier.startsWith('three/')||/\/(?:character_creation|character_creation_assets|model_parser|model_hierarchy|prepared_model_geometry|network_scene|native_ui_assets|native_rich_text|network_text|nui_skin|inventory_layout|item_icon|main|model_particles|particle_[^/]+|fountain_emitter|fountain_particle_providers|burst_single_emitter|lightning_emitter|emitter_target|model_reference_assets|model_reference_scene|model_references)\.js$/.test(value.url)||/\/(?:export-room|export-rigs|export-particles|particle-simulation|particle-workers|particle-worker|staging-area|staging-content|creation-service|gameplay-text|nui-service|inventory-service)\./.test(value.url))throw Error('Rendering dependency forbidden in native session owner: '+specifier);if(value.url.startsWith('file:'))loaded.add(fileURLToPath(value.url));return value;}});
const arg=name=>process.argv.find(v=>v.startsWith('--'+name+'='))?.slice(name.length+3);
const loadingPipeline=require('./native-loading-pipeline.cjs').resolveNativeLoadingPipeline(process.argv.slice(2));
const engineRuntime=performanceOptions.nativeRuntime.value,enginePackage=arg('native-runtime-package');
if(performanceOptions.runtime!=='standard'&&engineRuntime!=='editor')throw Error('Verified native runtime uses current project scripts; do not combine it with a packaged release');
if(!['editor','release'].includes(engineRuntime))throw Error('Invalid native engine runtime');
const nativeOverheadClocks=managedClientOptions.values['native-overhead-clocks']==='true';
if(nativeOverheadClocks&&engineRuntime!=='editor')throw Error('Native overhead clock candidate requires the reviewed editor runtime; release packaging is not validated');
const menuCheck=process.argv.includes('--menu-check'),headless=process.argv.includes('--native-headless');
const startupFeatureCheck=process.argv.includes('--startup-feature-check');if(startupFeatureCheck&&(!headless||process.argv.some(value=>['--menu-check','--public-servers','--local-check','--action-check','--creation-check','--script-floating-check','--script-floating-visual','--direct-handoff-check','--level-source-check','--record-loading'].includes(value))))throw Error('Startup feature checks require exclusive headless startup mode without server admission');
const menuExitCheck=process.argv.includes('--menu-exit-check');
if(menuExitCheck&&!menuCheck)throw Error('Original Exit control check requires the isolated no-server menu check');
const preworkCheckLimit=arg('prework-check-limit');
if(preworkCheckLimit!==undefined&&(!menuCheck||!/^[1-9][0-9]{0,3}$/.test(preworkCheckLimit)))throw Error('Prework corpus checks require an isolated menu check and a bounded model count');
const preworkCheckCold=process.argv.includes('--prework-check-cold');if(preworkCheckCold&&preworkCheckLimit===undefined)throw Error('Cold prework requires an isolated corpus check');
const nativeScreen=arg('native-screen');if(nativeScreen!==undefined&&!/^(0|[1-9][0-9]*)$/.test(nativeScreen))throw Error('Invalid native display index');
const actionNuiCheck=process.argv.includes('--action-nui-check');
const actionCorrectionCheck=process.argv.includes('--action-correction-check');
const actionRadialCheck=process.argv.includes('--action-radial-check');
const actionQuickbarCheck=process.argv.includes('--action-quickbar-check');
const actionPolymorphCheck=process.argv.includes('--action-polymorph-check');
const actionWorldRadialCheck=process.argv.includes('--action-world-radial-check');
const actionCombatPresentationCheck=process.argv.includes('--action-combat-presentation-check');
const actionNpcCombatCheck=process.argv.includes('--action-npc-combat-check');
const npcCombatAudit=arg('npc-combat-distinct-audit');
if(Boolean(npcCombatAudit)!==actionNpcCombatCheck)throw Error('NPC combat requires its explicit distinct-identity audit');
const actionAssociateRecordCheck=process.argv.includes('--action-associate-record-check');
const associateRecordHome=arg('associate-record-directory');
if(Boolean(associateRecordHome)!==actionAssociateRecordCheck)throw Error('Associate Record directory requires its isolated acceptance mode');
const associateRecordAudit=arg('associate-record-distinct-audit');
if(Boolean(associateRecordAudit)!==actionAssociateRecordCheck)throw Error('Associate Record requires its explicit distinct-identity audit');
const quickbarTestItemIds=new Set();
function quickbarTestItemState(world,id){const item=world.registry.get(id),actor=world.registry.get(world.localObjectId);return{id,exists:Boolean(item),objectType:item?.objectType,replicationRemoved:item?.replicationRemoved,deletionFlag:item?.deletionFlag,areaId:item?.areaId,location:item?.inventoryLocation,locationStatus:item?.inventoryLocationStatus,inventoryEquipmentSlot:item?.inventoryEquipmentSlot,equipmentOwnerId:item?.equipmentOwnerId,equippedSlots:Object.entries(actor?.clientEquipmentSlots??{}).filter(([,itemId])=>itemId===id).map(([slot])=>Number(slot)),baseItem:item?.item?.baseItem,canUse:item?.item?.canUse,shortcutSlots:world.quickbar.flatMap((b,index)=>b.type===1&&(b.itemId===id||b.secondaryItemId===id)?[index]:[])};}
const radialCaster=arg('radial-caster')??'standard';if(!['standard','wizard','cleric'].includes(radialCaster)||radialCaster!=='standard'&&!actionRadialCheck)throw Error('Radial spell fixture requires local radial mode');
const actionFeatCheck=process.argv.includes('--action-feat-check');
const actionBarterCheck=process.argv.includes('--action-barter-check');
const actionLobbyPagesCheck=process.argv.includes('--action-lobby-pages-check');
const actionLocalVaultCheck=process.argv.includes('--action-local-vault-check');
const actionLocalDeleteCheck=process.argv.includes('--action-local-delete-check');
let lobbyParticipant=null,lobbyParticipantWork=null,lobbyParticipantAbort=null;
const actionPlayersCheck=process.argv.includes('--action-players-check');if(actionPlayersCheck&&!actionBarterCheck)throw Error('Players check requires the owned two-peer fixture');
let barterPeer=null,barterPeerWork=null,barterPeerAbort=null;
const actionEffectsCheck=process.argv.includes('--action-effects-check');
const actionParticleCrowd=process.argv.includes('--action-particle-crowd');if(actionParticleCrowd&&!actionEffectsCheck)throw Error('Particle crowd requires isolated effects checks');
const actionRangedCheck=process.argv.includes('--action-ranged-check');
const actionParryCheck=process.argv.includes('--action-parry-check');
const actionSpecialAttackCheck=process.argv.includes('--action-special-attack-check');
const actionShieldCheck=process.argv.includes('--action-shield-check');
const actionDeflectionCheck=process.argv.includes('--action-deflection-check');if(actionDeflectionCheck&&!actionRangedCheck)throw Error('Deflection requires isolated ranged checks');
const actionMissCheck=process.argv.includes('--action-miss-check');if(actionMissCheck&&(!actionRangedCheck||actionDeflectionCheck))throw Error('Miss scenario requires an isolated ranged check');
const rangedWeapon=arg('ranged-weapon')??'bow';if(!['bow','sling'].includes(rangedWeapon)||rangedWeapon!=='bow'&&!actionRangedCheck)throw Error('Invalid isolated ranged weapon');
const shieldKind=arg('shield-kind')??'small';if(!['small','large','tower'].includes(shieldKind)||shieldKind!=='small'&&!actionShieldCheck)throw Error('Invalid isolated shield kind');
const specialAttackKind=arg('special-attack-kind')??'stun';if(!['stun','quivering','ki'].includes(specialAttackKind))throw Error('Invalid local special attack kind');
const directHandoffMode=require('./native-direct-handoff-mode.cjs').options(process.argv.slice(2)),directHandoffCheck=directHandoffMode.enabled;let directHandoffHarness=null,directHandoffFixture=null;
const levelSourceCheck=process.argv.includes('--level-source-check'),levelSourceName=arg('level-source-case'),levelSourceDirectory=arg('level-source-directory');let levelSourceHarness=null;
const scriptFloatingCheck=process.argv.includes('--script-floating-check'),scriptFloatingDirectory=arg('script-floating-directory');let scriptFloatingHarness=null;
const visualMode=require('./native-ordinary-speech-visual-mode.cjs').options(process.argv.slice(2)),scriptFloatingVisual=visualMode.enabled,scriptFloatingOwned=scriptFloatingCheck||scriptFloatingVisual;
const ordinarySpeechCheck=process.argv.includes('--ordinary-speech-check');if(ordinarySpeechCheck&&!scriptFloatingCheck)throw Error('Ordinary speech requires the composed ScriptFloating check');
if(scriptFloatingCheck&&(!headless||engineRuntime!=='editor'||!scriptFloatingDirectory||!arg('private-login-pipe')||process.argv.some(value=>['--level-source-check','--action-check','--creation-check','--local-check','--menu-check','--public-servers','--record-loading','--native-profile'].includes(value))))throw Error('ScriptFloating requires its exclusive protected headless original-local editor check');
if(!scriptFloatingOwned&&scriptFloatingDirectory)throw Error('ScriptFloating directory requires its explicit check');
if(levelSourceCheck&&(!headless||engineRuntime!=='editor'||!process.argv.includes('--native-debugger')||!levelSourceDirectory||!['wizard-multiclass','sorcerer-caster','cleric-new-class'].includes(levelSourceName)||process.argv.some(v=>['--action-check','--creation-check','--local-check','--menu-check','--public-servers'].includes(v))))throw Error('Source level-up requires its exclusive owned headless editor check');
if(!levelSourceCheck&&(levelSourceName||levelSourceDirectory))throw Error('Source level-up parameters require their explicit check');
const creationCheck=process.argv.includes('--creation-check');
const creationPackage=arg('creation-package')??'manual';if(!['manual','recommended'].includes(creationPackage)||!creationCheck&&arg('creation-package')!==undefined)throw Error('Package route requires its isolated creation check');
const creationCompletion=creationCheck?new(require('./native-creation-completion.cjs').CreationCompletion)():null;let creationHpOwner=null;
const creationDirectory=arg('creation-directory'),creationReconnectFrom=arg('creation-reconnect-from');
if((creationDirectory||arg('creation-port')||creationReconnectFrom)&&(!creationCheck||!creationDirectory||arg('creation-port')!=='5129'))throw Error('Vault parameters require isolated creation5129');
const actionCheck=process.argv.includes('--action-check'),localPort=directHandoffCheck||scriptFloatingOwned||levelSourceCheck||creationDirectory?5129:actionAssociateRecordCheck?5127:actionCheck?5125:5121;
const headlessPlayersCheck=actionCheck&&(actionPlayersCheck||actionQuickbarCheck||actionPolymorphCheck||actionWorldRadialCheck||actionCombatPresentationCheck||actionAssociateRecordCheck||actionNpcCombatCheck)&&headless;
if(actionNpcCombatCheck&&(!actionCheck||!headless||actionAssociateRecordCheck||actionQuickbarCheck||actionPolymorphCheck||actionWorldRadialCheck||actionCombatPresentationCheck||actionPlayersCheck||actionBarterCheck||actionNuiCheck||actionEffectsCheck||actionRadialCheck||actionFeatCheck||actionRangedCheck||actionParryCheck||actionSpecialAttackCheck||actionLobbyPagesCheck||actionLocalVaultCheck))throw Error('NPC combat requires its isolated owned headless loopback fixture');
if(actionAssociateRecordCheck&&(!actionCheck||!headless||actionQuickbarCheck||actionPolymorphCheck||actionWorldRadialCheck||actionCombatPresentationCheck||actionPlayersCheck||actionBarterCheck||actionNuiCheck||actionEffectsCheck||actionRadialCheck||actionFeatCheck||actionRangedCheck||actionParryCheck||actionSpecialAttackCheck||actionLobbyPagesCheck||actionLocalVaultCheck))throw Error('Associate Record requires its isolated owned headless loopback fixture');
if(actionCombatPresentationCheck&&(!actionCheck||!headless||actionQuickbarCheck||actionPolymorphCheck||actionWorldRadialCheck||actionPlayersCheck||actionNuiCheck||actionEffectsCheck||actionRadialCheck||actionFeatCheck))throw Error('CombatPresentation requires its isolated owned headless loopback fixture');
if(actionWorldRadialCheck&&(!actionCheck||!headless||actionQuickbarCheck||actionPolymorphCheck||actionPlayersCheck||actionNuiCheck||actionRadialCheck))throw Error('WorldRadial requires its isolated owned headless loopback fixture');
if(actionPolymorphCheck&&(!actionCheck||!headless||actionQuickbarCheck||actionPlayersCheck||actionNuiCheck))throw Error('Polymorph check requires its isolated owned headless loopback fixture');
if(actionQuickbarCheck&&(!actionCheck||!headless))throw Error('Quickbar check requires the owned headless loopback action fixture');
if(radialCaster!=='standard'&&!actionCheck)throw Error('Radial spell fixtures forbid public sessions');
if(actionLobbyPagesCheck&&(!actionCheck||headless||actionBarterCheck))throw Error('Lobby page checks require the isolated graphical local action fixture');
if(actionShieldCheck&&(!actionCheck||!actionRangedCheck||rangedWeapon!=='bow'||actionDeflectionCheck||actionMissCheck))throw Error('Shield requires one isolated bow check');
if(actionParryCheck&&(!actionCheck||actionRangedCheck||actionEffectsCheck||actionNuiCheck))throw Error('Parry requires one isolated melee check');
if(actionSpecialAttackCheck&&(!actionCheck||actionRangedCheck||actionEffectsCheck||actionNuiCheck||actionParryCheck))throw Error('Special attacks require isolated melee checks');
const localCheck=directHandoffCheck||scriptFloatingOwned||levelSourceCheck||creationCheck||actionCheck||process.argv.includes('--local-check');if(localCheck&&process.argv.includes('--public-servers'))throw Error('Local check forbids public endpoints');
const renderConfiguration=require('./native-render-configuration.cjs').resolveNativeRenderConfiguration({arg,env:process.env,isolated:localCheck||menuCheck});
if(actionLocalVaultCheck&&(!actionCheck||actionSpecialAttackCheck||actionParryCheck||actionRangedCheck||actionFeatCheck||actionNuiCheck||actionEffectsCheck||actionBarterCheck))throw Error('Local vault checks require the isolated standard action fixture');
if(actionLocalDeleteCheck&&(!actionLocalVaultCheck||headless||actionLobbyPagesCheck))throw Error('Local Delete requires the graphical isolated local-vault fixture');
const checkedCharacterKey=levelSourceCheck?(levelSourceName==='sorcerer-caster'?'installed:sorcerer.bic':levelSourceName==='cleric-new-class'?'installed:fighter.bic':'installed:wizard.bic'):actionAssociateRecordCheck?'installed:bard.bic':actionLocalVaultCheck?'local:nwn_local_ui.bic':actionSpecialAttackCheck?'installed:monk.bic':actionParryCheck?'installed:fighter.bic':actionRangedCheck?'installed:ranger.bic':actionFeatCheck?'installed:druid.bic':radialCaster==='cleric'?'installed:cleric.bic':'installed:wizard.bic';
const localCycles=Number(arg('local-cycles')??1);if(!Number.isSafeInteger(localCycles)||localCycles<1||localCycles>8||localCycles!==1&&!localCheck)throw Error('Invalid native local connection cycle count');
const localStreamAbort=process.argv.includes('--local-stream-abort');if(localStreamAbort&&(!localCheck||localCycles<2))throw Error('Streaming abort requires repeated local checks');
const localCancelCheck=process.argv.includes('--local-cancel-check');if(localCancelCheck&&!localCheck)throw Error('Cancel check requires local mode');
let cancellationSink,cancellationStage=0,cancellationSentAt=0;
const debuggerCheck=process.argv.includes('--native-debugger');
const nativeProfile=process.argv.includes('--native-profile');let profileAt=0,settingsProbeSent=false,desktopProbeSent=false,actionsProbeSent=false,menuCheckFinishing=false,localAdmissionPending=false;
const recordLoading=process.argv.includes('--record-loading');let loadingRecording=null,recordingDirectory=null,recordingCatalog=0;
const {performance,monitorEventLoopDelay}=require('node:perf_hooks');
const hostDelay=monitorEventLoopDelay({resolution:20});let hostDelayEnabled=false;
let hostCpu=process.cpuUsage(),hostClock=performance.now(),hostLoop=performance.eventLoopUtilization();
function setHostProfiling(value){if(value===hostDelayEnabled)return;hostDelayEnabled=value;if(value){hostDelay.enable();hostDelay.reset();hostCpu=process.cpuUsage();hostClock=performance.now();hostLoop=performance.eventLoopUtilization();}else hostDelay.disable();}
function hostMetrics(){const now=performance.now(),cpu=process.cpuUsage(),loop=performance.eventLoopUtilization(),span=Math.max(1,now-hostClock);const out={interval_ms:span,cpu_ms:(cpu.user+cpu.system-hostCpu.user-hostCpu.system)/1000,event_loop_utilization:performance.eventLoopUtilization(loop,hostLoop).utilization,event_loop_resolution_ms:20,event_loop_mean_ms:Number.isFinite(hostDelay.mean)?hostDelay.mean/1e6:0,event_loop_p95_ms:hostDelay.percentile(95)/1e6,event_loop_max_ms:hostDelay.max/1e6,...process.memoryUsage()};hostCpu=cpu;hostClock=now;hostLoop=loop;hostDelay.reset();return out;}
const run=arg('run')??'native-session-'+Date.now();if(!/^[a-z0-9-]+$/.test(run))throw Error('Invalid native run name');
const output=path.join(project,'reports',run+'.json'),nativeReport=path.join(project,'reports',run+'.native.json');
if(creationCheck&&process.env.NWN_CREATION_APPLY_DIAGNOSTIC==='1'&&(!debuggerCheck||engineRuntime!=='editor'))throw Error('Owned apply diagnostic requires the verified existing editor runtime under its debugger');
const creationApplyDiagnostic=creationCheck&&process.env.NWN_CREATION_APPLY_DIAGNOSTIC==='1'?new(require('./native-creation-apply-diagnostic.cjs').CreationApplyDiagnostic)(path.join(project,'reports',run+'.apply')):null;let creationStackWork=null,creationCpuWork=null;
const worldRadialCapture=actionWorldRadialCheck?new(require('./native-world-radial-capture.cjs').NativeWorldRadialCapture)(path.join(project,'reports',run+'.first-raw-world.json')):null;
let directPortal,directRawWire=null;
let session,lobby,browser,server,socket,native,temporary,timer,ending=false,authenticated=false,setupSession=null,snapshotGeneration=-1;
let catalogReady=false;
let settingsBroker,loginProfiles;
let localPlaying=false,localWork=null,localWalk=false,localWalkAt=0,localWalkProof=null;
let localWalkOrigin=null,localWalkGeneration=-1,authoritativeDistance=0;
let rawSerial=0,rawPending=null;
let quickbarInventoryRevision=0;
let localCycleEnding=false,localJoinPending=false,localDisconnectedAt=0,staleProbeConnection=-1,lastRetiredConnection=-1;
const {rawWorldFrames}=require('./raw-world-frames.cjs');
const worldDeltas=new (require('./raw-world-deltas.cjs').RawWorldDeltas)();
const rawCombat=new (require('./raw-combat-events.cjs').RawCombatEvents)();
const rawVoice=new (require('./raw-voice-events.cjs').RawVoiceEvents)(rawCombat);
const rawScriptSounds=new (require('./raw-script-sounds.cjs').RawScriptSounds)(rawCombat);
const rawVisual=new (require('./raw-visual-events.cjs').RawVisualEvents)(rawCombat);
const visibilityIdentity=(world,actor)=>world.entityDisclosures.transportRow(actor,rawCombat.object(actor));
const rawTileVisibility=new (require('./raw-tile-visibility.cjs').RawTileVisibility)(visibilityIdentity);
const rawCreatureVisibilityPermission=new (require('./raw-creature-visibility-permission.cjs').RawCreatureVisibilityPermission)(visibilityIdentity);
const nativeTextEvents=new (require('./native-text-event-scope.cjs').NativeTextEventScope)(rawCombat);
const nativeClockBridge=new (require('./native-clock-bridge.cjs').NativeClockBridge)({
 send(frame,encodedLine){
  if(!socket||socket.destroyed||socket.writableEnded)return {status:'unavailable'};
  // false means queued backpressure, not an unwritten frame to retry.
  const writable=socket.write(encodedLine);loadingRecording?.frame(frame,encodedLine);
  return {status:'accepted',backpressure:!writable};
 },
 isCurrent:(current,connection)=>!ending&&current===session&&connection===lobby?.connection
});
let nativeClockOwner=null,nativeClockConnection=-1;
const report={success:false,protocolOnly:true,renderingPrepared:false,publicConnections:0,states:[],areas:[],diagnostics:[],scope:'Direct native world entry; gameplay/effects/UI migration incomplete'};
const sessionFailureJournal=require('./native-session-failure-journal.cjs').createSessionFailureJournal({report,append:line=>fs.appendFile(output.replace(/\.json$/,'.connection.jsonl'),line)});
const creationBridge=(direction,kind,bytes,details={})=>{if(!creationCheck)return;report.creationBridgeTrace??={rows:[],dropped:0};const trace=report.creationBridgeTrace;if(trace.rows.length>=256){trace.dropped++;return;}trace.rows.push({direction,kind,bytes,at:Date.now(),ending,...details});};
const combatCheckLifecycle=actionCombatPresentationCheck?new(require('./native-combat-check-lifecycle.cjs').NativeCombatCheckLifecycle)():null;
const associateRecordLifecycle=actionAssociateRecordCheck?new(require('./native-combat-check-lifecycle.cjs').NativeCombatCheckLifecycle)():null;
const npcCombatLifecycle=actionNpcCombatCheck?new(require('./native-combat-check-lifecycle.cjs').NativeCombatCheckLifecycle)():null;
report.renderConfiguration=renderConfiguration.summary;
report.loadingPipeline=loadingPipeline.summary;
report.performanceConfiguration=performanceOptions;
if(headlessPlayersCheck)report.headlessUiScope={gameplayControls:true,authoritativeLocalOutcomes:true,admissionUi:false,characterPreviewUi:false,desktopSettings:false,pixels:false,scope:'Protocol admission to the owned loopback fixture followed by actual native gameplay UI. Graphical admission/preview/settings and pixels are separate acceptance.'};
let characterPreviewStore;
let localCharacterRoots=[];
report.requestedLocalCycles=localCycles;
report.localStreamAbortRequested=localStreamAbort;
const send=value=>{if(scriptFloatingCheck&&scriptFloatingHarness&&value.kind==='ui-protocol'){try{scriptFloatingHarness.delivered(value,session,lobby?.connection);}catch{scriptFloatingHarness.failure??='ScriptFloating Host observation failed';}}if(creationApplyDiagnostic&&['finish','finish-ack'].includes(value.kind))creationApplyDiagnostic.boundary('host',value.kind+':send-request',{connection:lobby?.connection??0,ending});if(value.kind==='lobby'){
 const state=value.state;value.localCharacterRoots=localCharacterRoots;
 report.lobbyStates??=[];
 if(report.lobbyStates.length<256)report.lobbyStates.push({connection:value.connection,phase:state.phase,busy:state.busy,error:state.error,canSelect:state.canSelect,connected:state.connected,at:Date.now()});
 }if(socket&&!socket.destroyed){const scoped={connection:lobby?.connection??0,...value};if(recordLoading&&scoped.kind==='setup')scoped.recordingDirectory=path.join(recordingDirectory,'catalog-'+(++recordingCatalog));const text=JSON.stringify(scoped,(_key,v)=>typeof v==='bigint'?{native64:String(v)}:v)+'\n';if(worldRadialCapture&&scoped.kind==='setup')worldRadialCapture.observeSetup(text);if(creationApplyDiagnostic&&scoped.kind==='setup')creationApplyDiagnostic.setupFrame(text);if(creationCheck){creationBridge('write',scoped.kind,Buffer.byteLength(text),{connection:scoped.connection,phase:scoped.state?.phase??null,queued:socket.writableLength});socket.write(text,error=>{creationBridge('flushed',scoped.kind,Buffer.byteLength(text),{connection:scoped.connection,error:error?.code??null,queued:socket?.writableLength??null});if(creationApplyDiagnostic&&['finish','finish-ack'].includes(scoped.kind))creationApplyDiagnostic.boundary('host',scoped.kind+':write-callback',{connection:scoped.connection,queued:socket?.writableLength,code:error?.code,ending});});}else socket.write(text);loadingRecording?.frame(scoped,text);}};
const sendForConnection=(connection,value)=>send({...value,connection});
const rejectRetired=message=>{if(report.retiredCommands===undefined)report.retiredCommands=[];if(report.retiredCommands.length<64)report.retiredCommands.push({kind:message.kind,connection:message.connection,current:lobby.connection});};
const ownsConnection=message=>session&&!session.closed&&Number.isSafeInteger(message.connection)&&message.connection===lobby.connection;
const movementKeys=['position','orientation','facingTarget','animation','path','walkRate','runRate','field8F4','field8EC','actionFlag'];let revision=0;
async function finish(reason){
 if(ending)return;if(creationApplyDiagnostic)creationApplyDiagnostic.boundary('host','finish:start',{ending,success:report.success===true});ending=true;hostDelay.disable();clearInterval(timer);if(reason)report.failure=reason;
 if(levelSourceCheck&&levelSourceHarness){report.levelUpSourceObservations=levelSourceHarness.snapshot();if(!report.levelUpSourceObservations.bounded){report.success=false;report.failure??='Source level-up observation bounds were exceeded';}}
 if(scriptFloatingCheck&&scriptFloatingHarness)report.scriptFloatingObservations=scriptFloatingHarness.snapshot();
 report.nativeClockProtocol=nativeClockBridge.snapshot();
 if(nativeClockOwner){nativeClockBridge.retire(nativeClockOwner,nativeClockConnection);nativeClockOwner=null;nativeClockConnection=-1;}
 if(worldRadialCapture)report.firstRawCapture=await worldRadialCapture.settle();
 if(creationCpuWork)await creationCpuWork;
 if(creationStackWork)await creationStackWork;
 if(creationApplyDiagnostic)report.creationApplyDiagnostic=creationApplyDiagnostic.summary();
 try{cancellationSink?.close();}catch{}
 await directPortal?.dispose();
 if(directPortal)report.directPortal=directPortal.snapshot();
 await browser?.retire().catch(()=>{});
 await loginProfiles?.retire();
 if(lobbyParticipant){report.lobbyParticipant={...lobbyParticipant.snapshot(),metadata:lobbyParticipant.metadata};await lobbyParticipant.close().catch(()=>{});}
 lobbyParticipantAbort?.abort();await lobbyParticipantWork?.catch(()=>{});
 if(native&&native.exitCode===null){send({kind:'finish'});await new Promise(resolve=>{const timeout=setTimeout(resolve,5000);native.once('exit',()=>{clearTimeout(timeout);resolve();});});if(native.exitCode===null){report.forcedNativeStop=true;native.kill();}}
 if(barterPeer){report.barterPeer={...barterPeer.snapshot(),metadata:barterPeer.metadata};await barterPeer.close().catch(()=>{});}
 barterPeerAbort?.abort();await barterPeerWork?.catch(()=>{});
 if(scriptFloatingCheck)report.scriptFloatingEndScopeCurrent=Boolean(scriptFloatingHarness?.current(session,lobby?.connection));
 await session?.disconnect().catch(()=>{});
 settingsBroker?.close();
 if(characterPreviewStore){try{await characterPreviewStore.close();}catch{report.success=false;report.characterPreviewCleanupFailed=true;}report.characterPreviewStorage=characterPreviewStore.snapshot();}
 if(loadingRecording)report.loadingRecording=await loadingRecording.close({run,sourceSha256:report.sourceSha256,applicationCacheInitiallyEmpty:true,osAndDriverCacheCold:false});
 socket?.destroy();server?.close();
 if(temporary){
  if(recordLoading&&native?.exitCode!==null){try{const owned=await fs.realpath(temporary),prepared=await fs.realpath(path.join(temporary,'prepared'));if(path.dirname(prepared)!==owned||path.basename(prepared)!=='prepared'||!path.basename(owned).startsWith('nwn-native-session-'))throw Error('Prepared cache ownership differs');await fs.rm(prepared,{recursive:true});report.recordingPreparedCacheRemoved=true;}catch(error){if(error.code!=='ENOENT')report.recordingPreparedCacheCleanup=error.message;}}
  await fs.unlink(path.join(temporary,'ticket.json')).catch(()=>{});await fs.rmdir(temporary).catch(()=>{});
 }
 try{
  const value=JSON.parse(await fs.readFile(nativeReport,'utf8'));report.native={success:value.success,workersRemaining:value.workers_remaining,world:value.world,nativeCatalog:value.native_catalog,gameplayUi:value.gameplay_ui,runtimeFeatures:value.runtime_features};
  if(value.runtime_features?.valid===false){report.success=false;report.failure='Native feature configuration rejected: '+(value.runtime_features.errors??[]).join('; ');if(startupFeatureManifest){startupFeatureManifest.nativeStartup=value.runtime_features;startupFeatureManifest.verification={status:'rejected',errors:value.runtime_features.errors??[]};await fs.writeFile(output.replace(/\.json$/,'.startup.json'),JSON.stringify(startupFeatureManifest,null,2)+'\n');}}
  if(directHandoffCheck){await directHandoffHarness.flushDiagnostics();directHandoffHarness.terminal({nativeExit:report.nativeExit,disconnected:!session||session.closed===true,workersRemaining:value.workers_remaining,forcedStop:Boolean(report.forcedNativeStop)});report.directHandoff=directHandoffHarness.snapshot();report.directHandoffProof=directHandoffHarness.evaluate();if(!report.directHandoffProof.success||!value.success||value.protocol_finish_ack!==true||report.failure){report.success=false;report.failure??='Current direct-route handoff evidence rejected';}directHandoffHarness.close();}
  if(creationApplyDiagnostic){report.creationNativeRuntimeTrace=value.creation_runtime_trace??null;if(!require('./native-creation-apply-diagnostic.cjs').runtimeTraceReady(report.creationNativeRuntimeTrace)){report.success=false;report.failure??='Owned native diagnostic trace did not retain valid armed evidence';}}
  if(menuExitCheck){report.menuExitCheck=value.menu_exit_check;report.success=report.success&&value.menu_exit_check?.success===true&&value.clean_exit===true&&value.gameplay_success===false;}
  if(actionCheck&&(!report.actions?.success||!report.exportedCharacter||!creationCheck&&!headlessPlayersCheck&&!report.characterPreviewProof?.success))report.success=false;
  if(actionAssociateRecordCheck){
   const {NativeMessageReader}=await import('../../src/native_message.js');
   const target=report.actions?.checks?.find(row=>row.passed&&row.label==='Authoritative owned associate retains its source Record target')?.details?.targetId;
   report.associateRecordLifecycle=associateRecordLifecycle.result(value,report.nativeExit);
   report.associateRecordServerProof=require('./native-associate-record-proof.cjs').associateRecordProof({wire:report.associateRecordWireSent,target,actions:report.actions?.success===true&&report.associateRecordIdentityPreflight?.distinct===true,lifecycle:report.associateRecordLifecycle.success},NativeMessageReader);
   if(!report.associateRecordServerProof.success||report.failure){report.success=false;report.failure??='Composed original-server target Record outcome/lifecycle was not verified';}
  }
  if(actionQuickbarCheck&&!report.quickbarMacroPersistence?.success){report.success=false;report.failure??='Original-server macro QBList persistence was not verified';}
  if(actionNpcCombatCheck){
   report.npcCombatLifecycle=npcCombatLifecycle.result(value,report.nativeExit);
   report.npcCombatServerProof=require('./native-npc-combat-proof.cjs').npcCombatProof({received:report.npcCombatReceived,stimuli:report.npcCombatStimuli,actions:report.actions,lifecycle:report.npcCombatLifecycle.success});
   if(!report.npcCombatServerProof.success||!report.npcCombatIdentityPreflight?.distinct||!report.actionCharacter?.uploadedUnchanged||report.actionCharacter.originalSha256!==report.actionCharacter.uploadedSha256||report.failure){report.success=false;report.failure??='Original NPC attack/model/facing/stop outcome, exact PC upload, participant audit or completion lifecycle was not verified';}
  }
  if(actionPolymorphCheck){
   const {NativeMessageReader}=await import('../../src/native_message.js'),wire=report.polymorphWireSent??[],events=report.polymorphAppearanceEvents??[];
   for(const row of wire){const bytes=Uint8Array.from(row.bytes),reader=new NativeMessageReader(1);reader.setReadMessage(bytes.subarray(3),bytes.length-3,0xffffffff,1);row.actorId=reader.readObjectIdClient();row.valid=reader.messageReadOverflow()===0&&reader.messageReadUnderflow()===0;delete row.bytes;}
   const baseline=wire[0]?.beforeAppearance,form=report.actionFixture.appearance;
   report.polymorphServerProof={success:wire.length===3&&wire.every(row=>row.valid&&row.actorId===row.controlledId)&&Number.isInteger(baseline)&&baseline!==form&&wire[1].beforeAppearance===form&&wire[2].beforeAppearance===form&&events.some(row=>row.appearance===baseline&&row.at>=wire[1].at&&row.at<wire[2].at),baseline,form,wire,events,source:'Decoded original Input6/30 actor packets, actual original-server appearance updates and native physical-control/query assertions. There is no synthetic cancel acknowledgment.'};
   if(!report.polymorphServerProof.success){report.success=false;report.failure??='Original-server shape/reversion outcomes were not verified';}
  }
  if(actionCombatPresentationCheck){
   report.combatPresentationLifecycle=combatCheckLifecycle.result(value,report.nativeExit);
   if(!report.combatPresentationLifecycle.success||report.failure){report.success=false;report.failure??='Owned combat completion/ACK lifecycle was not verified';}
   const {NativeMessageReader}=await import('../../src/native_message.js'),wire=report.combatPresentationWireSent??[];
   for(const row of wire){const bytes=Uint8Array.from(row.bytes),reader=new NativeMessageReader(1);reader.setReadMessage(bytes.subarray(3),bytes.length-3,0xffffffff,1);if(row.minor===18){row.spellId=reader.readDword();row.classIndex=reader.readByte();row.domainLevel=reader.readByte();row.metamagic=reader.readByte();row.flags=reader.readByte();if(row.flags&1)row.targetId=reader.readObjectIdClient();if(row.flags&2)row.position=[reader.readFloat(),reader.readFloat(),reader.readFloat()];row.targetType=reader.readWord();}else if(row.minor===20){row.actionId=reader.readWord();row.groupId=reader.readWord();}else row.targetId=reader.readObjectIdClient();row.valid=reader.messageReadOverflow()===0&&reader.messageReadUnderflow()===0;delete row.bytes;}
   const cast=wire.find(row=>row.minor===18&&row.valid&&row.spellId===100&&Number.isInteger(row.targetId)&&row.targetId!==0x7f000000),attack=cast?wire.find(row=>row.minor===2&&row.valid&&row.targetId===cast.targetId&&row.at>=cast.at):null,cancel=attack?wire.find(row=>row.minor===20&&row.valid&&row.actionId===3&&row.at>=attack.at):null,received=report.combatPresentationReceived??[];
   const actualCast=Boolean(cast)&&received.some(row=>row.cast?.spell===100&&row.cast?.target===cast.targetId&&row.at>=cast.at),actualAttack=Boolean(attack)&&received.some(row=>row.attacks>0&&row.at>=attack.at);
   report.combatPresentationServerProof={success:Boolean(cast&&attack&&cancel&&actualCast&&actualAttack&&report.actions?.success),wire,received,source:'Actual native spellbook/world target input; decoded6/18,6/2,6/20 and original-server cast/attack records, consumed preparation/private native pose/facing/cancel assertions. No GPU/pixel/full-combat claim.'};
   if(!report.combatPresentationServerProof.success){report.success=false;report.failure??='Original-server combat presentation outcomes were not verified';}
  }
  if(actionWorldRadialCheck){
   const {NativeMessageReader}=await import('../../src/native_message.js'),wire=report.worldRadialWireSent??[];
   for(const row of wire){const bytes=Uint8Array.from(row.bytes),reader=new NativeMessageReader(1);reader.setReadMessage(bytes.subarray(3),bytes.length-3,0xffffffff,1);if(row.minor===20){row.actionId=reader.readWord();row.groupId=reader.readWord();}else row.targetId=reader.readObjectIdClient();row.valid=reader.messageReadOverflow()===0&&reader.messageReadUnderflow()===0;delete row.bytes;}
   const talk=wire.find(row=>row.minor===8&&row.valid&&row.targetId!==0x7f000000),attack=wire.find(row=>row.minor===2&&row.valid&&row.targetId===talk?.targetId&&row.at>=talk.at),cancel=wire.find(row=>row.valid&&row.at>=attack?.at&&(row.minor===2&&row.targetId===0x7f000000||row.minor===20&&row.actionId===3));
   const outcome=report.actions?.checks?.find(row=>row.passed&&row.label==='Original server retires the attack queue after physical native cancellation');
   report.worldRadialServerProof={success:Boolean(talk&&attack&&cancel&&outcome),wire,source:'Physical native target Talk/Attack and eligible Disengage or actual queue cancellation, exact decoded6/8,6/2,6/20 packets and received original-server dialog/feedback/action queue retirement. No synthetic gameplay acknowledgment; unexercised Disengage UI is recorded explicitly.'};
   if(!report.worldRadialServerProof.success){report.success=false;report.failure??='Original-server world radial outcomes were not verified';}
  }
  if(actionQuickbarCheck){
   const {NativeMessageReader}=await import('../../src/native_message.js'),requests=[];
   for(const wire of report.quickbarWireSent??[])if(wire.major===12&&wire.complete){const bytes=Uint8Array.from(wire.bytes),reader=new NativeMessageReader(1);reader.setReadMessage(bytes.subarray(3),bytes.length-3,0xffffffff,1);const itemId=reader.readObjectIdClient(),destinationId=reader.readObjectIdClient(),slot=wire.minor===1?reader.readDword():undefined;requests.push({at:wire.at,minor:wire.minor,itemId,destinationId,slot});}
   const trace=report.quickbarItemTrace??[],rows=[];
   for(const id of quickbarTestItemIds){const request=requests.find(row=>row.itemId===id&&row.minor===7),removed=trace.find(row=>row.kind==='inventory-result'&&row.itemId===id&&row.minor===7&&row.success===true&&!row.alternate&&row.at>=request?.at),restore=requests.find(row=>row.itemId===id&&row.minor===1&&row.at>=removed?.at),attached=trace.find(row=>row.kind==='inventory-result'&&row.itemId===id&&row.minor===1&&row.success===true&&!row.alternate&&row.at>=restore?.at),preflight=trace.find(row=>row.direction==='client-preflight'&&row.item?.id===id&&row.operation==='unequip'),slot=preflight?.item?.inventoryEquipmentSlot;
    rows.push({itemId:id,slot,success:Boolean(request&&removed&&restore&&attached&&Number.isInteger(slot)&&removed.itemState?.equipmentOwnerId==null&&removed.itemState?.equippedSlots.length===0&&attached.itemState?.equipmentOwnerId===preflight.item.equipmentOwnerId&&attached.itemState?.equippedSlots.includes(slot)&&restore.slot===slot),unequipSendToResultMs:removed&&request?removed.at-request.at:null,equipSendToResultMs:attached&&restore?attached.at-restore.at:null,unequipState:removed?.itemState,equipState:attached?.itemState});}
   report.quickbarItemServerProof={success:rows.length===1&&rows.every(row=>row.success)&&!(report.commandErrors??[]).some(row=>row.kind==='item-action'),rows,requests,source:'Exact original-server12/7 and12/1 responses matched by itemID/order to decoded outgoing native packets and post-receive canonical equipment state; no repository coordinates inferred'};
   if(!report.quickbarItemServerProof.success){report.success=false;report.failure??='Original-server item-specific equipment/cache outcomes were not verified';}
   const associateRequests=[];
   for(const wire of report.quickbarWireSent??[])if(wire.major===6&&wire.minor===27&&wire.complete){const bytes=Uint8Array.from(wire.bytes),reader=new NativeMessageReader(1);reader.setReadMessage(bytes.subarray(3),bytes.length-3,0xffffffff,1);associateRequests.push({at:wire.at,targetId:reader.readObjectIdClient(),command:reader.readInt()});}
   const windowRequests=[];
   for(const wire of report.quickbarWireSent??[])if(wire.major===13&&[1,2].includes(wire.minor)&&wire.complete){const bytes=Uint8Array.from(wire.bytes),reader=new NativeMessageReader(1);reader.setReadMessage(bytes.subarray(3),bytes.length-3,0xffffffff,1);windowRequests.push(wire.minor===1?{at:wire.at,minor:1,open:reader.readBool()!==0,ownerId:reader.readObjectIdClient()}:{at:wire.at,minor:2,panel:reader.readByte(),self:reader.readBool()!==0});}
   const associate=associateRequests.find(row=>row.command===-19),opened=(report.quickbarAssociateWindows??[]).find(row=>row.open&&row.ownerId===associate?.targetId&&row.at>=associate?.at),presented=report.actions?.checks?.find(row=>row.passed&&row.label==='Canonical and actual alternate inventory retain the received associate owner'),paged=report.actions?.checks?.find(row=>row.passed&&row.label==='Actual original alternate page controls present the current received second-page row'),page=windowRequests.find(row=>row.minor===2&&row.panel===1&&!row.self&&row.at>=opened?.at),close=windowRequests.find(row=>row.minor===1&&!row.open&&row.ownerId===associate?.targetId&&row.at>=page?.at);
   report.quickbarAssociateServerProof={success:Boolean(associate&&opened&&presented&&presented.details?.speakerId===associate.targetId&&paged&&page&&close),requests:associateRequests,opened,presented,paged,windowRequests,sendToWindowMs:associate&&opened?opened.at-associate.at:null,inventoryEvents:report.quickbarAssociateInventory??[],source:'Decoded outgoing6/27 signed command/target, actual original server13/1 owner and lower r/i disclosure, current native alternate row/page view, original self=false13/2 and exact-owner13/1 close notification. Close/layout reflection are client-owned, not server acknowledgments.'};
   if(!report.quickbarAssociateServerProof.success){report.success=false;report.failure??='Original-server bound associate inventory outcome was not verified';}
  }
  if(actionLobbyPagesCheck&&!report.lobbyPages?.success)report.success=false;
  if(actionLocalDeleteCheck&&!report.localDelete?.success)report.success=false;
  if(levelSourceCheck&&(!report.levelUpSourceProof?.success||report.levelUpSourceProof.sourceOnly!==true||!report.levelUpSourceFixture?.originalInputUnchanged||!report.levelUpSourceExport))report.success=false;
  if(scriptFloatingCheck&&!report.scriptFloatingProof?.success)report.success=false;
  if(scriptFloatingVisual&&(!report.visualReady||!report.visualFinished||!value.success||value.workers_remaining!==0||value.protocol_finish_ack!==true||report.forcedNativeStop)){report.success=false;report.failure??='Distinct visual inspection lifecycle was incomplete';}
  if(scriptFloatingVisual){report.native.movementAcceptance=false;report.native.pixelAcceptance=false;report.native.performanceAcceptance=false;}
  if(creationCheck&&(!report.creationProof?.success||!(creationReconnectFrom?report.creationReconnectSelection?.success&&!report.nativeCreation:report.nativeCreation?.nativeGenerated)||!report.creationPostAdmissionExportComplete||!report.exportedCharacter?.classes?.some(row=>row.level===1)))report.success=false;
  if(creationCheck&&report.creationProof?.expected){const e=report.creationProof.expected,c=report.exportedCharacter;if(!c?.classes.some(row=>row.id===e.classId&&row.level===1&&row.domain1===(e.domains?.[0]??null)&&row.domain2===(e.domains?.[1]??null)&&row.school===e.school)||!e.known.every(id=>c.known[e.classId]?.includes(id))||!e.feats.every(id=>c.feats.includes(id)))report.success=false;}
  if(creationCheck&&report.creationProof?.expected&&'skills'in report.creationProof.expected){const expected=report.creationProof.expected.skills,actual=report.exportedCharacter?.skills;report.creationSkillRanksMatch=Array.isArray(expected)&&Array.isArray(actual)&&expected.length===actual.length&&expected.every((rank,index)=>rank===actual[index]);if(!report.creationSkillRanksMatch)report.success=false;}
  if(creationCheck&&report.creationProof?.expected&&'gender'in report.creationProof.expected){report.creationGenderMatch=Number.isInteger(report.creationProof.expected.gender)&&report.creationProof.expected.gender===report.exportedCharacter?.gender;if(!report.creationGenderMatch)report.success=false;}
  if(creationCheck&&report.creationProof?.expected&&'goodEvil'in report.creationProof.expected){const e=report.creationProof.expected,c=report.exportedCharacter;report.creationAlignmentMatch=Number.isInteger(e.goodEvil)&&Number.isInteger(e.lawChaos)&&e.goodEvil===c?.goodEvil&&e.lawChaos===c?.lawChaos;if(!report.creationAlignmentMatch)report.success=false;}
  if(creationCheck&&report.creationProof?.expected&&'abilities'in report.creationProof.expected){const expected=report.creationProof.expected.abilities,actual=report.exportedCharacter?.abilities;report.creationAbilityScoresMatch=Array.isArray(expected)&&Array.isArray(actual)&&expected.length===6&&actual.length===6&&expected.every((score,index)=>Number.isInteger(score)&&score===actual[index]);if(!report.creationAbilityScoresMatch)report.success=false;}
  if(creationCheck&&report.creationProof?.expected&&'race'in report.creationProof.expected){const e=report.creationProof.expected,c=report.exportedCharacter;report.creationRaceMatch=Number.isInteger(e.race)&&e.race===c?.race&&e.subrace===c?.subrace&&e.age===c?.age&&e.appearance===c?.appearance&&e.biography===c?.biography;if(!report.creationRaceMatch)report.success=false;}
  if(creationCheck&&report.creationProof?.expected){report.creationTailExportProof=require('./native-creation-export-proof.cjs').compare(report.creationProof.expected,report.creationExportDetails??{});if(!report.creationTailExportProof.success)report.success=false;}
  if(creationCheck&&report.creationProof?.expected){report.creationHpProof=require('./native-creation-hp-proof.cjs').compare(report.creationProof.expected.hitpoints,report.nativeCreation?.hitpoints??null,report.creationExportHitpoints??null,Boolean(creationReconnectFrom),report.creationAuthoritativeHitpoints??null);if(!report.creationHpProof.success){report.success=false;report.failure??='Uploaded/exported original HP cache fields or SHORT types differ';}}
  if(creationCheck&&arg('creation-class')==='cleric'&&report.creationProof?.expected){const classProof=require('./native-creation-class-proof.cjs'),expected=report.creationProof.expected;report.creationDivineClassProof={source:creationReconnectFrom?null:classProof.verifySource(report.nativeCreation?.classFields,expected),exported:classProof.verifyExport(report.creationExportClassFields,expected)};if(!creationReconnectFrom&&!report.creationDivineClassProof.source.success||!report.creationDivineClassProof.exported.success){report.success=false;report.failure??='Cleric source/export class/domain/divine field proof differs';}}
  if(creationCheck){report.creationWireProof=require('./native-creation-wire-proof.cjs').creationWireProof({wire:report.creationWireSent,vault:Boolean(creationDirectory),reconnect:Boolean(creationReconnectFrom),selection:report.creationReconnectSelection});if(!report.creationWireProof.success){report.success=false;report.failure??='Original creation/selection transport subtype was not verified';}}
  if(localCheck&&!directHandoffCheck&&!recordLoading&&!scriptFloatingOwned&&(!value.success||value.workers_remaining!==0||!value.protocol_finish_ack||!(report.localWalkDistance>0.2)||!(report.authoritativeDistance>0.2&&report.authoritativeDistance<2)))report.success=false;
  if(scriptFloatingCheck){report.scriptFloatingNativeExit=scriptFloatingHarness.nativeExit(value,report.scriptFloatingEndScopeCurrent);report.native.gameplaySuccess=value.gameplay_success;report.native.movementAcceptance=false;report.native.pixelAcceptance=false;if(!report.scriptFloatingNativeExit.success){report.success=false;report.failure??='Dedicated ScriptFloating native lifecycle/readiness proof rejected';}}
  if(localCheck&&recordLoading&&(!value.playable||!value.object_visuals_complete||value.workers_remaining!==0||!value.protocol_finish_ack||!report.loadingRecording?.complete||!report.loadingCheck))report.success=false;
  if(localCancelCheck&&(!report.cancelCheck?.peerClosed||report.cancelCheck.elapsedMs>1000||value.session_cancel_probes!==1))report.success=false;
  const expectedRetirements=localCycles-1+(localStreamAbort?1:0);
  if(localCheck&&!directHandoffCheck&&!recordLoading&&((report.localCycles?.length??0)!==localCycles||localStreamAbort&&(report.localAbortedCycles?.length??0)!==1||localCycles>1&&((value.stale_input_probes??0)!==expectedRetirements||(value.stale_session_messages??0)<4*expectedRetirements||(report.retiredCommands??[]).filter(row=>row.kind==='walk').length!==expectedRetirements)))report.success=false;
 }catch{report.success=false;report.failure??='Native result is unavailable';}
 if(/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m.test(report.engineErrors??'')){report.success=false;report.failure??='Native engine or lifetime errors';}
 if(debuggerCheck){const debug=await fs.readFile(path.join(project,'reports',run+'.cdb.log'),'utf8').catch(()=>'');report.debuggerArmed=/^NATIVE_SESSION_ARMED\r?$/m.test(debug);report.nativeException=/^NATIVE_SESSION_EXCEPTION\r?$/m.test(debug);if(!report.debuggerArmed||report.nativeException){report.success=false;report.failure??='Native debugger evidence failed';}}
 report.sourceUnchanged=true;for(const[file,digest]of Object.entries(report.sourceSha256??{}))if(crypto.createHash('sha256').update(await fs.readFile(path.join(project,file))).digest('hex')!==digest)report.sourceUnchanged=false;
 if(!report.sourceUnchanged){report.success=false;report.failure??='Native sources changed during the check';}
 if(characterPreviewStore&&(!characterPreviewStore.closed||characterPreviewStore.files.size||report.characterPreviewCleanupFailed))report.success=false;
 report.loadedProtocolModules=[...loaded].filter(file=>file.startsWith(root+path.sep)).map(file=>path.relative(root,file).replaceAll('\\','/')).sort();
 report.unpinnedProtocolModules=report.loadedProtocolModules.filter(file=>!Object.hasOwn(report.sourceSha256??{},path.relative(project,path.join(root,file)).replaceAll('\\','/')));
 if(localCheck&&report.unpinnedProtocolModules.length){report.success=false;report.failure??='Observed protocol modules lacked an initial source pin';}
 await sessionFailureJournal.settled();
 if(creationApplyDiagnostic){creationApplyDiagnostic.boundary('host','report:write',{ending,success:report.success===true});report.creationApplyDiagnostic=creationApplyDiagnostic.summary();}await fs.writeFile(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:report.success,failure:report.failure,report:output}));process.exit(report.success?0:1);
}
(async()=>{
 const chunks=[];let inputBytes=0;for await(const chunk of process.stdin){inputBytes+=chunk.length;if(inputBytes>65536)throw Error('Private native startup request exceeds bound');chunks.push(chunk);}
 let startup;try{startup=JSON.parse(Buffer.concat(chunks).toString('utf8'));}finally{for(const chunk of chunks)chunk.fill(0);}
 let savedKey=startup.cdKey??'';delete startup.cdKey;
 if(actionAssociateRecordCheck){
  const auditPath=await fs.realpath(associateRecordAudit),ownedRoot=await fs.realpath(path.join(project,'.cache/associate-record-gui-server-tests'));
  if(!auditPath.startsWith(ownedRoot+path.sep)||path.basename(auditPath)!=='auth-config-audit.json'||(await fs.stat(auditPath)).size>65536)throw Error('Associate Record audit escapes its owned evidence');
  const audit=JSON.parse(await fs.readFile(auditPath,'utf8')),reference=audit.records?.find(row=>row.label==='accepted_npc14')?.participantPublicTagHash;
  if(!/^[a-f0-9]{64}$/.test(reference??''))throw Error('Associate Record reference identity is unavailable');
  const {publicCdKey}=await import('../../electron/network_login_identity.mjs');
  const publicId=publicCdKey(savedKey);if(publicId.length!==8)throw Error('Associate Record protected participant identity is unavailable');
  const publicIdentityHash=crypto.createHash('sha256').update(publicId).digest('hex');
  report.associateRecordIdentityPreflight={distinct:publicIdentityHash!==reference,publicIdentityHash,referenceMainPublicIdentityHash:reference};
  if(!report.associateRecordIdentityPreflight.distinct)throw Error('Associate Record explicit participant matches the busy reference identity');
 }
 if(actionNpcCombatCheck){
  const auditPath=await fs.realpath(npcCombatAudit),ownedRoot=await fs.realpath(path.join(project,'.cache/associate-record-gui-server-tests'));
  if(!auditPath.startsWith(ownedRoot+path.sep)||path.basename(auditPath)!=='auth-config-audit.json'||(await fs.stat(auditPath)).size>65536)throw Error('NPC combat audit escapes its owned evidence');
  const audit=JSON.parse(await fs.readFile(auditPath,'utf8')),reference=audit.records?.find(row=>row.label==='accepted_npc14')?.participantPublicTagHash;
  if(!/^[a-f0-9]{64}$/.test(reference??''))throw Error('NPC combat reference identity is unavailable');
  const {publicCdKey}=await import('../../electron/network_login_identity.mjs');
  const publicId=publicCdKey(savedKey);if(publicId.length!==8)throw Error('NPC combat protected participant identity is unavailable');
  const publicIdentityHash=crypto.createHash('sha256').update(publicId).digest('hex');
  report.npcCombatIdentityPreflight={distinct:publicIdentityHash!==reference,publicIdentityHash,referenceMainPublicIdentityHash:reference};
  if(!report.npcCombatIdentityPreflight.distinct)throw Error('NPC combat explicit participant matches the busy reference identity');
 }
 let barterPeerKey=startup.barterPeerCdKey??'';delete startup.barterPeerCdKey;
 if(barterPeerKey&&(!actionCheck||!actionBarterCheck&&!actionLobbyPagesCheck))throw Error('Participant credentials require an owned two-participant test');
 if(recordLoading){const parent=localCheck?os.tmpdir():path.join(startup.settingsDirectory,'native-loading-recordings');await fs.mkdir(parent,{recursive:true});recordingDirectory=await fs.mkdtemp(path.join(parent,localCheck?'nwn-native-loading-recording-':'capture-'));const {NativeLoadingRecording}=await import('./native-loading-recording.mjs');loadingRecording=new NativeLoadingRecording(recordingDirectory);report.recordingDirectory=recordingDirectory;console.log('NATIVE LOADING RECORDING: '+recordingDirectory);}
 if(directHandoffCheck){directHandoffFixture=await(await import('./native-direct-handoff-fixture.mjs')).read(directHandoffMode.directory);startup.userDirectory=directHandoffFixture.clientDirectory;startup.settingsDirectory=startup.userDirectory;startup.settings={...startup.settings,modsDirectory:path.join(startup.userDirectory,'workshop'),disabledMods:[]};}
 if(creationDirectory){report.creationVaultFixture=await require('./native-creation-vault-fixture.cjs').read(creationDirectory);startup.userDirectory=path.join(report.creationVaultFixture.directory,'client');startup.settingsDirectory=startup.userDirectory;startup.settings={...startup.settings,modsDirectory:path.join(startup.userDirectory,'workshop'),disabledMods:[]};await fs.mkdir(startup.userDirectory,{recursive:true});}
 if(creationReconnectFrom){const file=await fs.realpath(creationReconnectFrom),reports=await fs.realpath(path.join(project,'reports'));if(!file.startsWith(reports+path.sep)||!/^native-creation-[a-z0-9-]+\.json$/.test(path.basename(file))||(await fs.stat(file)).size>16*1024*1024)throw Error('Creation reconnect reference escapes its explicit accepted report');const bytes=await fs.readFile(file),previous=JSON.parse(bytes);if(!previous.success||!previous.creationProof?.success||!previous.creationTailExportProof?.success||!previous.creationPostAdmissionExportComplete||previous.endpoint!=='127.0.0.1:5129'||previous.creationVaultFixture?.descriptorSha256!==report.creationVaultFixture.descriptorSha256)throw Error('Creation reconnect reference is not accepted from this exact original vault');report.creationReconnectReference={file,sha256:crypto.createHash('sha256').update(bytes).digest('hex')};}
 if(levelSourceCheck){
  const fixture=await require('./native-level-up-source-server.cjs').read(levelSourceDirectory),client=path.join(fixture.directory,'client');await fs.mkdir(client,{recursive:true});startup.userDirectory=client;startup.settingsDirectory=client;startup.settings={...startup.settings,modsDirectory:path.join(client,'workshop'),disabledMods:[]};report.levelUpSourceServerFixture=fixture;
  const recipe=(await import('./native-level-up-source-fixture.mjs')).levelSourceCase(levelSourceName);levelSourceHarness=new(require('./native-level-up-source-check.cjs').SourceLevelUpCheck)(recipe);
 }
 if(scriptFloatingOwned){
  const fixture=await(await import('./native-script-floating-server.mjs')).read(scriptFloatingDirectory),client=path.join(fixture.directory,'client');await fs.mkdir(client,{recursive:true});startup.userDirectory=client;startup.settingsDirectory=client;startup.settings={...startup.settings,modsDirectory:path.join(client,'workshop'),disabledMods:[]};report.scriptFloatingServerFixture=fixture;
  const {decodeServerGameMessage}=await import('../../src/network_game_messages.js');if(scriptFloatingCheck)scriptFloatingHarness=new(ordinarySpeechCheck?require('./native-ordinary-speech-capture.cjs').OrdinarySpeechCapture:require('./native-script-floating-capture.cjs').ScriptFloatingCapture)(decodeServerGameMessage,rawCombat);
 }
 if(actionCheck){
  let actionsHome;
  if(actionAssociateRecordCheck){
   actionsHome=await fs.realpath(associateRecordHome);const ownedRoot=await fs.realpath(path.join(project,'.cache/associate-record-live-tests'));
   if(!actionsHome.startsWith(ownedRoot+path.sep)||path.basename(actionsHome)!=='server')throw Error('Associate Record fixture escapes its owned acceptance directory');
  }else ({actionsHome}=await import('./native-actions-fixture.mjs'));
  startup.userDirectory=path.join(actionsHome,'client');startup.settingsDirectory=path.join(actionsHome,'client');startup.settings={...startup.settings,modsDirectory:path.join(actionsHome,'client/workshop'),disabledMods:[]};report.actionFixture=JSON.parse(await fs.readFile(path.join(actionsHome,'fixture.json')));
  if(actionNpcCombatCheck){
   if(report.actionFixture.module!=='GodotCombatNpc1'||report.actionFixture.port!==5125||report.actionFixture.npcCombat?.canonicalClassesUnchanged!==true||report.actionFixture.npcCombat?.pcUnchanged!==true)throw Error('NPC combat requires its exact owned fixture');
   for(const file of ['modules/GodotCombatNpc1.mod','client/nwm/GodotCombatNpc1.nwm'])if(crypto.createHash('sha256').update(await fs.readFile(path.join(actionsHome,file))).digest('hex')!==report.actionFixture.sha256)throw Error('NPC original-server and native catalog module bytes differ');
   report.npcCombatFixtureDirectory=actionsHome;
  }
  if(actionAssociateRecordCheck){
   const fixture=report.actionFixture;
   if(fixture.module!=='AssocRecordGui'||fixture.port!==5127||fixture.rows?.skill?.customized!==1||fixture.rows.skill.unchanged!==3||fixture.rows?.feat?.customized!==3||fixture.rows.feat.unchanged!==4||fixture.proficiency?.id!==45)throw Error('Associate Record requires its exact authored target-GUI fixture');
   for(const file of ['modules/AssocRecordGui.mod','client/nwm/AssocRecordGui.nwm'])if(crypto.createHash('sha256').update(await fs.readFile(path.join(actionsHome,file))).digest('hex')!==fixture.sha256)throw Error('Associate Record original-server and native catalog bytes differ');
   report.associateRecordFixtureDirectory=actionsHome;
  }
 }
 settingsBroker=require('./settings-client.cjs').createSettingsClient({initial:startup.settings,onStatus:value=>{startup.settings=value;},fallbackKey:()=>savedKey});
 const settings=require('./settings-client.cjs').credentialSettings(settingsBroker,()=>startup.settings,()=>savedKey,{fixedResources:actionCheck||levelSourceCheck||scriptFloatingOwned});
 report.bootStage='loading-protocol-modules';const startupStatus=setInterval(()=>{void fs.writeFile(output.replace(/\.json$/,'.startup.json'),JSON.stringify({bootStage:report.bootStage,loaded:[...loaded].map(file=>path.relative(root,file))}));},2000);startupStatus.unref();
 for(const file of [output,nativeReport,...(creationApplyDiagnostic?[nativeReport+'.phases.jsonl',nativeReport+'.runtime.jsonl']:[])]){try{await fs.access(file);throw Error('Native report already exists');}catch(error){if(error.code!=='ENOENT')throw error;}}
 const {NativeCharacterPreviewStore}=await import('./native-character-preview-store.mjs');characterPreviewStore=await new NativeCharacterPreviewStore(path.join(root,'runtime-logs/native-character-previews',run)).open();
 const {NativeCommandPump}=await import('./native-command-pump.mjs');
 const {guiPanelEventForHost,guiPanelHeaderForHost}=await import('../../src/network_gui_panel_access.js');
 const {playerRosterHeader}=await import('../../src/network_player_roster.js');
 const {NativeDirectPortal}=await import('./native-direct-portal.mjs');
 const {NativeDirectHandoffHostCheck}=require('./native-direct-handoff-host-check.cjs');
 const handoffCharacterProof=directHandoffCheck?await import('./native-handoff-character-proof.mjs'):null;
 const {NativeLobby}=await import('./native-lobby.mjs'),{ServerBrowserService}=await import('./server-browser-service.mjs'),{ServerBrowserStore}=await import('./server-browser-store.mjs'),{ServerEndpointPolicy,parseAllowedServer}=await import('./server-endpoint.mjs'),{queryNetworkServer,fetchNetworkServerList}=await import('../../electron/server_browser.mjs'),{createInstalledNetworkSession}=await import('../../electron/installed_network_session.mjs');
 const {NetworkCharacterVault}=await import('../../electron/network_character_vault.mjs');
 report.bootStage='reading-protected-settings';
 const sourceFiles=['tools/native-handoff-character-proof.mjs','tools/native-direct-handoff-recovery.cjs','tools/native-direct-handoff-host-check.cjs','tools/native-direct-handoff-capture.cjs','tools/native-direct-handoff-fixture.mjs','tools/native-direct-handoff-query.mjs','tools/test-native-direct-handoff.ps1','tests/native_direct_handoff_world.gd','tests/native_direct_handoff_probe.gd','tools/native-direct-portal.mjs','tools/portal-adoption.mjs','tools/native-direct-handoff-mode.cjs','native_live_world.gd','native_session_world.gd','tools/native-session-host.cjs','tools/native-session-bootstrap.cjs','tools/raw-world-frames.cjs','tools/raw-world-deltas.cjs','tools/raw-combat-events.cjs','systems/native_level_up.gd','systems/native_game_desktop.gd','systems/native_ui_art.gd','systems/native_render_settings.gd','systems/native_main_menu.gd','systems/draggable_panel.gd','systems/native_gameplay_ui.gd','systems/native_inventory.gd','systems/bridge_frames.gd','systems/model_rigs.gd','systems/model_reference_state.gd','systems/particle_surface.gd','systems/entity_registry.gd','systems/native_interaction_policy.gd','systems/native_hud.gd','systems/world_input.gd'];
 sourceFiles.push('project.godot','tools/native-window-screen.ps1','tools/settings-broker.cjs','tools/settings-client.cjs','tools/login-profile-service.mjs','../electron/client_settings.mjs');
 sourceFiles.push('tools/native-dialog-input.mjs','tools/native-correction-fixture.mjs');
 sourceFiles.push('tools/activity-input.mjs');
 sourceFiles.push('tools/native-loading-recording.mjs','tools/native-loading-writer.mjs');
 for(const file of ['tools/raw-visual-events.cjs','tools/native-effects-fixture.mjs','tools/native-particle-crowd-fixture.mjs','tools/native-ranged-fixture.mjs','tools/native-parry-fixture.mjs','tools/native-special-attack-fixture.mjs','systems/native_keyboard.gd','systems/native_item_icons.gd','systems/native_ui_skin.gd','systems/camera_controller.gd','systems/area_environment.gd'])if(!sourceFiles.includes(file))sourceFiles.push(file);
 for(const file of await fs.readdir(path.join(project,'systems')))if(file.endsWith('.gd')&&!sourceFiles.includes('systems/'+file))sourceFiles.push('systems/'+file);
 sourceFiles.push('tools/native-lobby-participant.mjs','tools/native-command-pump.mjs','tools/native-lobby.mjs','tools/native-character-preview-store.mjs','systems/native_character_preview.gd','tools/server-browser-service.mjs','../electron/network_abort.mjs','../electron/network_peer.mjs','../electron/installed_network_session.mjs','../electron/server_browser.mjs','tools/skill-input.mjs','tools/native-actions-fixture.mjs','tests/native_live_actions_probe.gd','systems/native_data/feedback_descriptors.json','../electron/network_game_session.mjs');
 if(levelSourceCheck)sourceFiles.push('tests/native_live_level_up_source_probe.gd','tests/native_creation_source_live_probe.gd','tools/native-level-up-source-check.cjs','tools/native-level-up-source-proof.cjs','tools/native-level-up-snapshot-evidence.cjs','tools/native-level-up-source-fixture.mjs','tools/native-level-up-source-server.cjs','tools/query-native-level-up-source-server.mjs','tools/test-native-level-up-source-live.ps1','tools/native-level-up-no-build.ps1',path.relative(project,path.join(levelSourceDirectory,'fixture.json')).split(path.sep).join('/'));
 if(scriptFloatingCheck)sourceFiles.push('tests/native_script_floating_world.gd','tests/native_live_script_floating_probe.gd','tools/native-script-floating-capture.cjs','tools/native-script-floating-server.mjs','tools/query-native-script-floating-server.mjs','tools/test-native-script-floating-live.ps1','tools/native-level-up-no-build.ps1','tools/native-text-event-scope.cjs','join-native.ps1',path.relative(project,path.join(scriptFloatingDirectory,'fixture.json')).split(path.sep).join('/'));
 if(scriptFloatingVisual)sourceFiles.push('tests/native_ordinary_speech_visual_world.gd','tests/native_ordinary_speech_visual_probe.gd','tools/native-ordinary-speech-visual-mode.cjs','tools/native-ordinary-speech-visual.test.cjs','tools/test-native-ordinary-speech-visual.ps1','tools/native-script-floating-server.mjs','tools/query-native-script-floating-server.mjs','tools/native-level-up-no-build.ps1','join-native.ps1',path.relative(project,path.join(scriptFloatingDirectory,'fixture.json')).split(path.sep).join('/'));
 if(ordinarySpeechCheck)sourceFiles.push('tests/native_live_ordinary_speech_probe.gd','tests/native_live_composed_text_probe.gd','tools/native-ordinary-speech-capture.cjs','tools/test-native-ordinary-speech-live.ps1');
 if(scriptFloatingOwned)for(const file of ['modules/ScriptFloat1.mod','client/nwm/ScriptFloat1.nwm'])sourceFiles.push(path.relative(project,path.join(scriptFloatingDirectory,file)).replaceAll('\\','/'));
 if(levelSourceCheck)for(const file of await fs.readdir(path.join(project,'systems/client_api')))if(file.endsWith('.gd'))sourceFiles.push('systems/client_api/'+file);
 if(actionQuickbarCheck)sourceFiles.push('tests/native_live_quickbar_probe.gd','tests/native_live_associate_quickbar_probe.gd','tests/native_quickbar_associate_server_fixture.mjs','../src/network_emote_input.js','../src/native_message.js','../src/network_associate_input.js','../src/network_quickbar.js','../src/gff.js','../src/network_equipment_cache.js','../src/network_inventory_response.js');
 if(actionPolymorphCheck)sourceFiles.push('tests/native_live_polymorph_probe.gd','tests/native_polymorph_server_fixture.mjs','../src/network_polymorph_input.js','../src/native_message.js');
 if(actionWorldRadialCheck)sourceFiles.push('tests/native_live_world_radial_probe.gd','tests/native_live_quickbar_probe.gd','tools/native-world-radial-capture.cjs','../src/network_player_requests.js','../src/native_message.js');
 if(actionCombatPresentationCheck)sourceFiles.push('tests/native_live_combat_presentation_probe.gd','tests/native_live_world_radial_probe.gd','tests/native_live_quickbar_probe.gd','tools/native-combat-check-lifecycle.cjs','../src/network_spell_input.js','../src/native_message.js');
 if(actionNpcCombatCheck)sourceFiles.push(path.relative(project,npcCombatAudit).split(path.sep).join('/'),'tests/native_live_npc_combat_probe.gd','tests/native_live_quickbar_probe.gd','tests/native_npc_combat_server_fixture.mjs','tools/native-npc-combat-proof.cjs','tools/native-npc-combat-character.cjs','tools/native-combat-check-lifecycle.cjs');
 if(actionAssociateRecordCheck)sourceFiles.push(path.relative(project,associateRecordAudit).split(path.sep).join('/'),'tests/native_live_associate_record_probe.gd','tests/native_live_world_radial_probe.gd','tests/native_live_quickbar_probe.gd','tests/native_associate_record_gui_fixture.mjs','tests/native_associate_record_server_fixture.mjs','tools/test-native-associate-record-live.ps1','tools/native-associate-record-proof.cjs','tools/native-associate-record-pin.cjs','tools/native-combat-check-lifecycle.cjs','../src/network_hud_input.js','../src/native_message.js');
 // Browser behavior is split across imported policy/store/filter/sort modules.
 // Pin those dependencies too; hashing only the service cannot certify them.
 sourceFiles.push('tools/server-browser-store.mjs','tools/server-browser-filters.mjs','tools/server-browser-sort.mjs','tools/server-endpoint.mjs','tools/local-protocol.cjs','../src/server_discovery.js','../src/gff_text.js');
 sourceFiles.push('tools/private-login.cjs','../src/network_barter.js','../src/network_world.js','../src/network_game_messages.js');
 sourceFiles.push('tools/native-character-preview-proof.cjs');
 sourceFiles.push('tools/native-local-character-files.mjs');
 sourceFiles.push('tools/native-local-character-discovery.mjs','../electron/workshop_content.mjs');
 sourceFiles.push('tools/native_prework_worker.gd');
 sourceFiles.push('../src/network_map_input.js','../src/network_area.js','../src/network_hud_messages.js','tools/native-map-fixture.mjs','tools/native-journal-fixture.mjs');
 sourceFiles.push('../src/network_party_input.js','../src/network_party.js');
 sourceFiles.push('tools/native-players-fixture.mjs','tools/test-native-actions.ps1','../src/network_hud_input.js','tools/chat-input.mjs','../src/network_chat_input.js');
 sourceFiles.push('tools/native-hud-fixture.mjs','tests/native_live_hud_probe.gd');
 sourceFiles.push('tests/native_live_item_tooltip_probe.gd');
 sourceFiles.push('systems/server_store.gd');
 for(const file of ['../src/network_item_text_bubble.js','systems/native_item_tooltip.gd','systems/inventory_slot.gd','systems/native_barter_slot.gd','systems/server_inventory.gd','systems/native_barter.gd','systems/native_barter_view.gd','systems/native_nameplate.gd'])if(!sourceFiles.includes(file))sourceFiles.push(file);
 if(actionBarterCheck)sourceFiles.push('tools/native-barter-peer.mjs');
 for(const directory of ['native_data','native_render'])for(const file of await fs.readdir(path.join(project,'systems',directory)))if(file.endsWith('.gd'))sourceFiles.push('systems/'+directory+'/'+file);
 sourceFiles.push('systems/character_lobby.gd','systems/native_character_lobby.gd');
 sourceFiles.push('tools/native-engine-runtime.cjs','tools/native-performance-runtime.cjs','tools/ensure-release-runtime.ps1','tools/prepare-release-test.ps1','tools/prepare-release-pack.gd');
 report.compiledParticlesRequested=process.env.NWN_PARTICLE_KERNEL!=='gd';
 if(report.compiledParticlesRequested)sourceFiles.push('native/particle_kernel.cpp','native/particle_simulation.hpp','native/particle_kernel.gdextension','tools/build-particle-kernel.ps1','tools/ensure-particle-kernel.ps1','join-native.ps1','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json');
 if(report.compiledParticlesRequested)for(const file of await fs.readdir(path.join(project,'native')))if(file.endsWith('.hpp')&&!sourceFiles.includes('native/'+file))sourceFiles.push('native/'+file);
 // Include the observed initial module graph, not only the legacy hand list.
 if(creationCheck)for(const file of ['tools/native-creation-apply-diagnostic.cjs','tools/native-creation-socket-trace.cjs','tools/break-owned-creation-native.ps1','tools/native-creation-owned-identity.ps1','tools/native-creation-class-proof.cjs','tools/native-creation-reconnect-mode.ps1','tools/test-native-creation-vault-reconnect.ps1','tools/native-creation-hp-proof.cjs','tools/native-creation-hp-owner.cjs','tools/native-creation-export-proof.cjs','tools/native-creation-wire-proof.cjs','tools/native-creation-completion.cjs','tools/test-native-creation-full-live.ps1','tools/test-native-creation-vault-live.ps1','tests/native_creation_live_probe.gd','tests/native_creation_source_live_probe.gd','tests/native_creation_cleric_live_probe.gd'])if(!sourceFiles.includes(file))sourceFiles.push(file);
 if(creationDirectory)sourceFiles.push('tools/native-creation-vault-fixture.cjs',path.relative(project,path.join(creationDirectory,'fixture.json')).replaceAll('\\','/'));
 if(creationReconnectFrom)sourceFiles.push(path.relative(project,report.creationReconnectReference.file).replaceAll('\\','/'));
 for(const file of loaded)if(file.startsWith(root+path.sep)){const relative=path.relative(project,file).replaceAll('\\','/');if(!sourceFiles.includes(relative))sourceFiles.push(relative);}
 // Owned checks also pin potential lazy protocol imports before they execute.
 // This has no polling/rendering effect and does not expand normal launch IO.
 if(localCheck){const pinDirectory=async directory=>{for(const entry of await fs.readdir(directory,{withFileTypes:true})){const file=path.join(directory,entry.name);if(entry.isSymbolicLink())throw Error('Linked protocol source cannot be pinned');if(entry.isDirectory())await pinDirectory(file);else if(/\.(?:js|mjs|cjs)$/.test(entry.name)){const relative=path.relative(project,file).replaceAll('\\','/');if(!sourceFiles.includes(relative))sourceFiles.push(relative);}}};for(const directory of ['src','electron'])await pinDirectory(path.join(root,directory));}
 report.sourceSha256={};for(const file of sourceFiles)report.sourceSha256[file]=crypto.createHash('sha256').update(await fs.readFile(path.join(project,file))).digest('hex');
 const install=path.resolve(root,'../FullDecomp/NwnRootInstall'),userDirectory=startup.userDirectory;
 const cacheDirectory=path.join(userDirectory,'replacement-client/server-content'),policy=new ServerEndpointPolicy({allowed:scriptFloatingOwned||levelSourceCheck||actionCheck||creationDirectory?[{host:'127.0.0.1',port:localPort}]:[],allowAny:!menuCheck&&process.argv.includes('--public-servers'),internet:!menuCheck&&process.argv.includes('--public-servers')});
 if(scriptFloatingOwned)policy.allowed.delete('127.0.0.1:5121');
 if(directHandoffCheck){policy.allowed.clear();for(const target of directHandoffFixture.servers)policy.allowed.add(target.host+':'+target.port);}
 const vault=new NetworkCharacterVault(path.join(startup.settingsDirectory,'network-characters')),localCatalog=new Map();
 const sourceDescriptor=current=>{
  const archives=[],nwsync=[],seen=new Set(),groups=new Map();
  for(const entry of [...current.resourceResult.resolved].reverse()){
   if(entry.kind==='nwsync'){nwsync.unshift({hash:entry.name,cacheDirectory,nativeDirectory:path.join(userDirectory,'nwsync'),helper:path.join(root,'tooling/native/content-reader/nwn-content-reader.exe')});continue;}
   if(!['nwm','hak'].includes(entry.kind))continue;
   if(typeof entry.resource!=='string')throw Error('This server archive has no native file-backed resource location');
   const key=path.resolve(entry.resource).toLowerCase();if(seen.has(key))continue;seen.add(key);
   const base=entry.kind==='nwm'?23000000:path.dirname(entry.resource).toLowerCase()===path.join(userDirectory,'hak').toLowerCase()?31000000:30000000,order=groups.get(base)??0;groups.set(base,order+1);
   archives.push({path:path.resolve(entry.resource),priority:base+order});
  }
  const tlk=current.resourceResult.resolved.find(entry=>entry.kind==='tlk');
  const config=sessionConfigs.get(current),descriptor={install,archives,nwsync,customTlk:tlk?{name:tlk.name,path:typeof tlk.resource==='string'?tlk.resource:null}:null,profileDirectory:config?.userDirectory??userDirectory,modsDirectory:config?.modsDirectory??startup.settings.modsDirectory,disabledMods:config?.disabledMods??startup.settings.disabledMods};if(creationCheck)report.creationResourceSources=structuredClone(descriptor);return descriptor;
 };
 const creationSelectionCodec=creationCheck?await import('../../src/network_character_selection.js'):null;
 const sessionConfigs=new WeakMap(),sessionPersistence=new WeakMap();
 const rememberVaultId=current=>{const state=sessionPersistence.get(current);if(state&&lobby.session===current&&lobby.connection===state.connection)state.vaultId=lobby.vaultId??state.vaultId;return state?.vaultId??null;};
 const retirePresentation=(current,connection)=>{
  if(current&&nativeClockOwner===current){nativeClockBridge.retire(current,nativeClockConnection);nativeClockOwner=null;nativeClockConnection=-1;}
  if(session!==current)return;
  session=null;setupSession=null;catalogReady=false;rawPending=null;worldDeltas.reset();snapshotGeneration=-1;sendForConnection(connection,{kind:'session-reset'});
 };
 const attach=(current,connection)=>{
  const send=value=>sendForConnection(connection,value);
  current.characterPreviewEncoder=bytes=>characterPreviewStore.encode(bytes);
  if(directHandoffCheck)current.on('portal-ready',next=>{try{directHandoffHarness.ready({previous:current,next});}catch(error){directHandoffHarness.fail(error.message);}});
  session=current;setupSession=null;catalogReady=false;snapshotGeneration=-1;rawPending=null;worldDeltas.reset();send({kind:'session-reset'});
  // The dedicated clock listener binds before the later UI listener below,
  // and before Session.connect can deliver its first accepted packet.
  nativeClockOwner=current;nativeClockConnection=connection;report.nativeClockAttach=nativeClockBridge.attach(current,connection);
  if(scriptFloatingCheck)current.peer.on('message',bytes=>{if(ending||session!==current||lobby.connection!==connection)return;try{scriptFloatingHarness.packet(current,connection,bytes);}catch{scriptFloatingHarness.failure??='ScriptFloating original packet observation failed';}});
  if(localCheck){localPlaying=false;localWork=null;localWalk=false;localWalkAt=0;localWalkProof=null;localWalkOrigin=null;localWalkGeneration=-1;authoritativeDistance=0;localCycleEnding=false;report.firstPlayable=null;report.movementWhileStreaming=null;report.nativeChooserReady=null;report.characterPreviewProof=null;}
  if(creationCheck){const originalSend=current.peer.sendGameMessage.bind(current.peer);report.creationWireSent=[];current.peer.sendGameMessage=async(bytes,...options)=>{if(bytes[0]===112&&bytes[1]===2&&[1,2,14,17,19].includes(bytes[2])){if(report.creationWireSent.length>=8)throw Error('Owned creation wire evidence exceeded its bound');const row={at:Date.now(),major:bytes[1],minor:bytes[2],bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')};if([2,14,17].includes(bytes[2])){const selected=current.selectedServerCharacter;row.source=selected?.source;row.resref=selected?.resref;row.generation=current.characterListGeneration;if(selected){const canonical=creationSelectionCodec.serverCharacterPlayRequest(selected);row.canonical=Buffer.from(bytes).equals(Buffer.from(canonical));}else row.canonical=false;}report.creationWireSent.push(row);}return originalSend(bytes,...options);};}
  if(actionLobbyPagesCheck){
   report.lobbyPageWire={sent:[],received:[]};const originalSend=current.peer.sendGameMessage.bind(current.peer);
   current.peer.sendGameMessage=async(bytes,...options)=>{if(bytes[0]===112&&bytes[1]===49&&[1,2].includes(bytes[2]))report.lobbyPageWire.sent.push([...bytes]);return originalSend(bytes,...options);};
  }
  if(actionQuickbarCheck){
   const originalSend=current.peer.sendGameMessage.bind(current.peer);report.quickbarWireSent=[];
   current.peer.sendGameMessage=async(bytes,...options)=>{if(bytes[0]===112&&(bytes[1]===12&&[1,7].includes(bytes[2])||bytes[1]===30&&bytes[2]===2||bytes[1]===6&&bytes[2]===27||bytes[1]===13&&[1,2].includes(bytes[2]))&&report.quickbarWireSent.length<64)report.quickbarWireSent.push({at:Date.now(),major:bytes[1],minor:bytes[2],bytes:[...bytes.subarray(0,512)],complete:bytes.length<=512});return originalSend(bytes,...options);};
  }
  if(actionPolymorphCheck){
   const originalSend=current.peer.sendGameMessage.bind(current.peer);report.polymorphWireSent=[];
   current.peer.sendGameMessage=async(bytes,...options)=>{if(bytes[0]===112&&bytes[1]===6&&bytes[2]===30&&report.polymorphWireSent.length<16)report.polymorphWireSent.push({at:Date.now(),controlledId:current.world.localObjectId,beforeAppearance:current.world.registry.get(current.world.localObjectId)?.appearance?.appearance,bytes:[...bytes]});return originalSend(bytes,...options);};
  }
  if(actionWorldRadialCheck){
   const originalSend=current.peer.sendGameMessage.bind(current.peer);report.worldRadialWireSent=[];
   current.peer.sendGameMessage=async(bytes,...options)=>{if(bytes[0]===112&&bytes[1]===6&&[2,8,20].includes(bytes[2])&&report.worldRadialWireSent.length<32)report.worldRadialWireSent.push({at:Date.now(),minor:bytes[2],controlledId:current.world.localObjectId,bytes:[...bytes]});return originalSend(bytes,...options);};
  }
  if(actionCombatPresentationCheck){
   const originalSend=current.peer.sendGameMessage.bind(current.peer);report.combatPresentationWireSent=[];
   current.peer.sendGameMessage=async(bytes,...options)=>{if(bytes[0]===112&&bytes[1]===6&&[2,18,20].includes(bytes[2])&&report.combatPresentationWireSent.length<32)report.combatPresentationWireSent.push({at:Date.now(),minor:bytes[2],controlledId:current.world.localObjectId,bytes:[...bytes]});return originalSend(bytes,...options);};
  }
  if(actionAssociateRecordCheck){
   const originalSend=current.peer.sendGameMessage.bind(current.peer);report.associateRecordWireSent=[];
   current.peer.sendGameMessage=async(bytes,...options)=>{if(bytes[0]===112&&(bytes[1]===21&&bytes[2]===1||bytes[1]===53&&bytes[2]===1)&&report.associateRecordWireSent.length<96)report.associateRecordWireSent.push({at:Date.now(),major:bytes[1],minor:bytes[2],controlledId:current.world.localObjectId,bytes:[...bytes]});return originalSend(bytes,...options);};
  }
  current.on('state',state=>{if(ending||current!==session||connection!==lobby.connection)return;if(levelSourceCheck){try{levelSourceHarness.observe(current,connection);}catch{levelSourceHarness.failure??='Received class observation was incomplete';}}if(['playing','area-loading'].includes(state.phase))lobby.creating=false;report.states.push({connection,phase:state.phase});});
  current.on('message',({message,areaGeneration})=>{if(ending||current!==session||connection!==lobby.connection)return;if(levelSourceCheck){try{levelSourceHarness.disclosure(current,connection,message);}catch{levelSourceHarness.failure??='Received disclosure observation was incomplete';}}
   if(actionQuickbarCheck&&message.kind==='inventory-window-status'){report.quickbarAssociateWindows??=[];if(report.quickbarAssociateWindows.length<32)report.quickbarAssociateWindows.push({at:Date.now(),...structuredClone(message),windows:current.world.inventoryWindows.snapshot()});report.quickbarInventoryTimings??=[];if(report.quickbarInventoryTimings.length<128)report.quickbarInventoryTimings.push({phase:'accepted-window-message',at:Date.now(),owner:message.ownerId,open:message.open});}
   if(actionQuickbarCheck&&message.kind==='object-updates'&&message.records?.some(row=>row.action==='inventory'&&['r','i'].includes(row.channel))){quickbarInventoryRevision++;report.quickbarInventoryTimings??=[];if(report.quickbarInventoryTimings.length<128)report.quickbarInventoryTimings.push({phase:'accepted-inventory-message',at:Date.now(),revision:quickbarInventoryRevision});}
   if(actionQuickbarCheck&&message.kind==='object-updates')for(const row of message.records??[])if(row.action==='inventory'&&['r','i'].includes(row.channel)){report.quickbarAssociateInventory??=[];if(report.quickbarAssociateInventory.length<64)report.quickbarAssociateInventory.push({at:Date.now(),id:row.id,operation:row.operation,channel:row.channel,slot:row.slot,x:row.x,y:row.y,panel:row.panel,pageCount:row.pageCount,ownerId:current.world.inventories.get(row.channel)?.ownerId,entries:current.world.inventories.get(row.channel)?.entries?.length});}
   if(actionPolymorphCheck&&message.kind==='object-updates')for(const row of message.records??[])if(row.action==='appearance'&&row.id===current.world.localObjectId&&row.state?.appearance!==undefined){report.polymorphAppearanceEvents??=[];if(report.polymorphAppearanceEvents.length<32)report.polymorphAppearanceEvents.push({at:Date.now(),id:row.id,appearance:row.state.appearance,areaGeneration});}
   if(actionCombatPresentationCheck&&message.kind==='object-updates')for(const row of message.records??[])if(row.id===current.world.localObjectId&&row.state&&(row.state.animation!==undefined||row.state.facingTarget!==undefined)){report.combatPresentationReceived??=[];if(report.combatPresentationReceived.length<96)report.combatPresentationReceived.push({at:Date.now(),id:row.id,animation:row.state.animation,cast:row.state.cast,attacks:row.state.attacks?.length??0,facingTarget:row.state.facingTarget,pathCount:row.state.path?.length});}
   if(actionNpcCombatCheck&&message.kind==='object-updates')for(const row of message.records??[]){const object=current.world.registry.get(row.id);if(object?.objectType===5&&!object.replicationRemoved&&row.state&&(row.state.animation!==undefined||row.state.facingTarget!==undefined)){report.npcCombatReceived??=[];if(report.npcCombatReceived.length<128)report.npcCombatReceived.push({at:Date.now(),id:row.id,nativeLifetime:rawCombat.identity(object),generation:areaGeneration,areaId:current.world.areaId,animation:row.state.animation,attacks:structuredClone(row.state.attacks??[]),facingTarget:row.state.facingTarget,pathCount:row.state.path?.length,classesDisclosed:Object.hasOwn(object.replicated?.stats??{},'classes')});}}
   if(actionLobbyPagesCheck&&message.kind==='server-character-player'&&current===session&&connection===lobby.connection)report.lobbyPageWire.received.push({present:message.present,id:message.character.id,classes:message.character.classes??[]});
   if(actionPlayersCheck&&message.kind==='object-updates')for(const row of message.records){const misc=row.state?.light;if(misc?.field270!==undefined){report.captionTrace??=[];if(report.captionTrace.length>=64)report.captionTrace.shift();report.captionTrace.push({at:Date.now(),id:row.id,mode:misc.field270,text:String(misc.field278??'').slice(0,256)});}}
   if(actionBarterCheck&&(message.kind.startsWith('barter-')||message.kind==='object-updates'&&message.records.some(row=>row.action==='inventory'))){
    report.barterTrace??=[];if(report.barterTrace.length>=160)report.barterTrace.shift();
    report.barterTrace.push({kind:message.kind,...(message.kind==='object-updates'?{records:message.records.filter(row=>row.action==='inventory').map(({channel,operation,id,x,y,slot})=>({channel,operation,id,x,y,slot}))}:{message}),actorId:current.world.localObjectId,open:current.world.barter?.open,repositories:Object.fromEntries(['R','I','A','B'].map(channel=>[channel,(current.world.inventories.get(channel)?.entries??[]).map(row=>({id:row.id,channel:current.world.registry.get(row.id)?.inventoryLocation?.channel,ownerId:current.world.registry.get(row.id)?.inventoryLocation?.ownerId}))]))});
   }
   if(actionCheck){report.actionEventCounts??={};report.actionEventCounts[message.kind]=(report.actionEventCounts[message.kind]??0)+1;if(['spell-feedback','combat-feedback','server-speech','safe-projectile'].includes(message.kind)){report.actionProtocol??=[];if(report.actionProtocol.length>=128)report.actionProtocol.shift();report.actionProtocol.push(structuredClone(message));}}
   if(actionQuickbarCheck&&message.kind.startsWith('dialog-')){report.quickbarDialogTimeline??=[];if(report.quickbarDialogTimeline.length<64)report.quickbarDialogTimeline.push({at:Date.now(),direction:'server',kind:message.kind,entryId:message.entryId,firstCount:message.firstCount,secondCount:message.secondCount,replyCount:message.replies?.length});}
   if(actionQuickbarCheck&&quickbarTestItemIds.size){
    report.quickbarItemTrace??=[];
    if(message.kind==='object-updates')for(const row of message.records??[])if((quickbarTestItemIds.has(row.id)||row.action==='inventory'&&row.channel==='I')&&report.quickbarItemTrace.length<128)report.quickbarItemTrace.push({at:Date.now(),direction:'server',kind:row.action,id:row.id,channel:row.channel,operation:row.operation,slot:row.slot,remove:row.remove,items:[...quickbarTestItemIds].map(id=>quickbarTestItemState(current.world,id))});
    if(message.kind==='inventory-result'&&report.quickbarItemTrace.length<128)report.quickbarItemTrace.push({at:Date.now(),direction:'server',...structuredClone(message),itemState:quickbarTestItemState(current.world,message.itemId)});
   }
   if(actionRadialCheck&&message.kind==='object-updates')for(const row of message.records??[])if(row.action==='player-state'&&row.state?.playerFlags!==undefined){report.radialActivityFlags??=[];if(report.radialActivityFlags.length<64)report.radialActivityFlags.push({id:row.id,flags:row.state.playerFlags});}
   if(current!==session||connection!==lobby.connection||ending)return;
    let nativeTextEvent=null;try{nativeTextEvent=nativeTextEvents.capture(current.world,message,areaGeneration,connection);}catch{report.nativeTextEventCaptureFailures=Math.min(65535,(report.nativeTextEventCaptureFailures??0)+1);}
   for(const frame of rawTileVisibility.frames(current.world,message,areaGeneration,connection))send(frame);
   for(const frame of rawCreatureVisibilityPermission.frames(current.world,message,areaGeneration,connection))send(frame);
   if(message.kind==='voice-play'){const frame=rawVoice.frame(current.world,message,areaGeneration,connection);if(frame)send(frame);}
   if(message.kind==='script-sound'){const frame=rawScriptSounds.frame(current.world,message,areaGeneration,connection);if(frame)send(frame);}
   if(['object-updates','object-visual','area-visual','safe-projectile'].includes(message.kind)){const frame=rawVisual.frame(current.world,areaGeneration,connection,message);if(frame){send(frame);report.rawVisualEvents=(report.rawVisualEvents??0)+frame.events.length;}}
   if(message.kind==='gui-panel-disabled'||message.kind==='gui-panel-popup'){const event=guiPanelEventForHost(current.world,message,areaGeneration);if(event)send({kind:'ui-protocol',generation:areaGeneration,message:{kind:'gui-panel-access-event',event}});}
   if(message.kind==='inventory-window-status')send({kind:'ui-protocol',generation:areaGeneration,message:{...message,windows:current.world.inventoryWindows.snapshot()}});
   if(message.kind.startsWith('nui-'))send({kind:'ui-protocol',generation:areaGeneration,message:{...message,...(message.kind==='nui-create'?{nativeSerial:current.world.nui.windows.get(message.token)?.serial}:{})}});
   if(message.kind.startsWith('barter-'))send({kind:'ui-protocol',generation:areaGeneration,message:{...message,nativeBarterSerial:current.world.barter?.serial??0,nativeBarterRevision:current.world.barter?.revision??0}});
    else if(['combat-feedback','spell-feedback','damage-feedback','attack-feedback','initiative-feedback','server-speech','dialog-entry','dialog-replies','dialog-selected','dialog-close','examine','custom-token','tlk-overrides','inventory-result','inventory-ack','level-up-classes','level-up-available','level-up-result','store-open','store-close','store-transaction'].includes(message.kind))send({kind:'ui-protocol',generation:areaGeneration,message:nativeTextEvent?{...message,nativeTextEvent}:message});
   if(message.kind==='object-updates'){const frame=rawCombat.frame(current.world,areaGeneration,connection);if(frame){send(frame);report.rawCombatEvents=(report.rawCombatEvents??0)+frame.events.length;}}
   if(snapshotGeneration!==areaGeneration||message.kind!=='object-updates')return;
   const records=[];for(const event of current.world.presentationChanges){if(event.action!=='movement')continue;const object=current.world.registry.get(event.id);if(!object||object.objectType!==5||object.areaId!==current.world.areaId||object.replicationRemoved)continue;records.push({id:event.id,revision:++revision,created:Boolean(event.created),changes:structuredClone(event.changes),initial:Object.fromEntries(movementKeys.filter(key=>object.replicated[key]!==undefined).map(key=>[key,structuredClone(object.replicated[key])]))});}
   if(actionCorrectionCheck)for(const record of records){if(record.id!==current.world.localObjectId||!record.changes.position)continue;report.correctionWirePositions??=[];if(report.correctionWirePositions.length>=16)report.correctionWirePositions.shift();report.correctionWirePositions.push({revision:record.revision,position:record.changes.position});}
   if(records.length)send({kind:'movement',areaId:current.world.areaId,generation:areaGeneration,records});
  });
 };
 const createSession=async(request,connection,{signal,owned=()=>!ending&&connection===lobby.connection}={})=>{
  const {nativeVaultId=null,...options}=request,state={connection,vaultId:nativeVaultId};
   const created=await createInstalledNetworkSession({...options,signal,onDiagnostic:d=>{if(report.diagnostics.length<128)report.diagnostics.push(d);sessionFailureJournal.record(d,connection);},persistCharacter:async message=>{
    if(directHandoffCheck){if(!directHandoffHarness.exported(created.session,connection,message.data))throw Error('Unexpected owned direct export');return{id:'native-direct-handoff',name:'Original handoff fixture'};}
    if(!actionCheck&&!creationCheck&&!levelSourceCheck&&!scriptFloatingOwned){rememberVaultId(created.session);const saved=await vault.save(message,{id:state.vaultId});state.vaultId=saved.id;return saved;}
    const {parseGff}=await import('../../src/gff.js'),c=parseGff(message.data,'BIC ').root;
    report.exportedCharacter={sha256:crypto.createHash('sha256').update(message.data).digest('hex'),gender:c.Gender,goodEvil:c.GoodEvil,lawChaos:c.LawfulChaotic,race:c.Race,subrace:c.Subrace,age:c.Age,appearance:c.Appearance_Type,biography:c.Description?.entries?.[0]?.text??'',classes:c.ClassList.map(v=>({id:v.Class,level:v.ClassLevel,domain1:v.Domain1??null,domain2:v.Domain2??null,school:v.School??null})),abilities:['Str','Dex','Con','Int','Wis','Cha'].map(k=>c[k]),skills:(c.SkillList??[]).map(v=>v.Rank),feats:(c.FeatList??[]).map(v=>v.Feat),known:Object.fromEntries(c.ClassList.map(v=>[v.Class,Array.from({length:10},(_,l)=>v['KnownList'+l]??[]).flat().map(s=>s.Spell)]))};
    if(levelSourceCheck&&levelSourceHarness.exportOwner){const {getGffStructType,getGffFieldTypes}=await import('../../src/gff.js');levelSourceHarness.exported(created.session,connection,c,getGffStructType,getGffFieldTypes);const file=run+'.level-source-export.bic';await fs.writeFile(path.join(project,'reports',file),message.data,{flag:'wx'});report.levelUpSourceExport={file,sha256:report.exportedCharacter.sha256};}
    if(creationCheck){const {getGffStructType,getGffFieldTypes}=await import('../../src/gff.js');report.creationExportDetails=require('./native-creation-export-proof.cjs').snapshot(c,getGffStructType,getGffFieldTypes);report.creationExportHitpoints=require('./native-creation-hp-proof.cjs').snapshot(c,getGffFieldTypes);if(arg('creation-class')==='cleric')report.creationExportClassFields=require('./native-creation-class-proof.cjs').snapshot(c,getGffStructType,getGffFieldTypes);report.creationAuthoritativeHitpoints=require('./native-creation-hp-owner.cjs').witness(creationHpOwner,created.session,session,connection,Boolean(report.creationPostAdmissionExportRequested));report.creationExports??=[];if(report.creationExports.length>=8)throw Error('Owned creation export evidence exceeded its finite bound');const file=run+'.export'+(report.creationExports.length?'-'+report.creationExports.length:'')+'.bic';await fs.writeFile(path.join(project,'reports',file),message.data,{flag:'wx'});report.creationExports.push({file,sha256:report.exportedCharacter.sha256,at:Date.now(),postAdmissionRequested:Boolean(report.creationPostAdmissionExportRequested)});}
    if(actionQuickbarCheck){const row=c.QBList?.[35],canonical={QBObjectType:row?.QBObjectType,QBCommandLabel:row?.QBCommandLabel,QBCommandLine:row?.QBCommandLine};report.quickbarExportHistory??=[];if(report.quickbarExportHistory.length<4)report.quickbarExportHistory.push({at:Date.now(),sha256:report.exportedCharacter.sha256,count:c.QBList?.length??0,slot35:canonical});if(report.quickbarMacroExportRequested&&!report.quickbarMacroPersistence)report.quickbarMacroPersistence={success:Array.isArray(c.QBList)&&c.QBList.length===36&&row?.QBObjectType===18&&row.QBCommandLabel==='Native macro'&&row.QBCommandLine==='/tk NATIVE_QUICKBAR_MACRO_ACK',sha256:report.exportedCharacter.sha256,count:c.QBList?.length??0,slot35:canonical,source:'Original-server character-export BIC QBList before scratch-slot restoration; not the client-owned layout mirror'};}
    return{id:'native-local-actions',name:'Local actions fixture'};
   }});
  if(signal?.aborted||!owned()){await created.session.disconnect();throw Error('Cancelled native session preparation');}
  // Only resource/login metadata crosses handoffs. Identity is cloned by the
  // policy-checked coordinator; private credentials and source pins are absent.
  const config={};for(const key of ['install','name','userDirectory','cacheDirectory','modsDirectory','disabledMods','reuseInstalledNWSync'])if(options[key]!==undefined)config[key]=structuredClone(options[key]);
  sessionConfigs.set(created.session,Object.freeze(config));sessionPersistence.set(created.session,state);
  created.session.deferNuiResources=true;return created;
 };
 lobby=new NativeLobby({listLocal:async()=>{localCatalog.clear();const status=await settings.status(),{discoverLocalCharacterFiles}=await import('./native-local-character-discovery.mjs');const discovered=await discoverLocalCharacterFiles({install,profileDirectory:userDirectory,modsDirectory:status.modsDirectory,disabledMods:status.disabledMods}),rows=discovered.rows;localCharacterRoots=[...discovered.roots,path.join(vault.directory,'blobs')];if(!localCheck)for(const entry of await vault.list())rows.push({key:'vault:'+entry.id,label:entry.name+' (saved)',source:'vault',vaultId:entry.id,file:path.join(vault.directory,'blobs',entry.sha256+'.bic'),catalogStem:entry.id});const {localCharacterFile}=await import('./native-local-character-files.mjs');for(const row of rows){row.nativeFile=await localCharacterFile(row.file);if(row.storageSource)row.nativeFile.storageSource=row.storageSource;localCatalog.set(row.key,row);}report.localDiscovery={rows:rows.length,roots:localCharacterRoots.length,profile:rows.filter(row=>row.source==='local').length,workshop:rows.filter(row=>row.source==='workshop').length};return rows;},readLocal:async key=>{const row=localCatalog.get(key);if(!row)throw Error('Unknown local character');if(directHandoffCheck){if(key!=='installed:wizard.bic'||path.resolve(row.file)!==path.join(install,'data/lcv/wizard.bic'))throw Error('Direct handoff installed character identity differs');const bytes=await fs.readFile(row.file);directHandoffHarness.readCharacter(session,lobby.connection,key,bytes);return bytes;}if(scriptFloatingOwned){if(key!=='installed:wizard.bic'||path.resolve(row.file)!==path.join(install,'data/lcv/wizard.bic'))throw Error('ScriptFloating installed Wizard identity differs');const bytes=await fs.readFile(row.file);report.scriptFloatingInstalledCharacter={sha256:crypto.createHash('sha256').update(bytes).digest('hex'),bytes:bytes.length,unchanged:true};return bytes;}if(levelSourceCheck){const recipe=levelSourceHarness.recipe;if(key!==checkedCharacterKey||path.resolve(row.file)!==path.join(install,'data/lcv',recipe.file)||!session?.resolver||session.closed)throw Error('Owned source level-up installed file/scope differs');const original=await fs.readFile(row.file),{parse2da}=await import('../../src/area.js'),{decodeResourceText}=await import('../../src/resource_archive.js'),xp=parse2da(decodeResourceText(await session.resolver.getResource('exptable',2017))),fixture=(await import('./native-level-up-source-fixture.mjs')).xpOnlyLevelSourceCharacter(original,xp,levelSourceName);report.levelUpSourceFixture=fixture.metadata;return fixture.bytes;}if(actionNpcCombatCheck){const fixture=require('./native-npc-combat-character.cjs').exactNpcCharacter(await fs.readFile(row.file));report.actionCharacter=fixture.metadata;return fixture.bytes;}if(actionCheck){const input=await fs.readFile(row.file),fixture=await(await import('./native-actions-fixture.mjs')).actionTestCharacter(input,{rangedWeapon});report.actionCharacter=fixture.metadata;
  if(radialCaster!=='standard'){const spellFixture=await(await import('./native-radial-spell-fixture.mjs')).radialSpellCharacter(fixture.bytes,radialCaster);fixture.bytes=spellFixture.bytes;fixture.metadata.radial=spellFixture.metadata;fixture.metadata.uploadedSha256=spellFixture.metadata.uploadedSha256;}
  const {parseGff}=await import('../../src/gff.js'),c=parseGff(fixture.bytes,'BIC ').root;
  report.characterPreviewExpected={sha256:fixture.metadata.uploadedSha256,abilities:Object.fromEntries(['Str','Dex','Con','Int','Wis','Cha'].filter(k=>Number.isInteger(c[k])).map(k=>[k,c[k]])),classes:c.ClassList.filter(v=>Number.isInteger(v.Class)&&Number.isInteger(v.ClassLevel)).map(v=>({id:v.Class,level:v.ClassLevel})),skill_count:(c.SkillList??[]).filter(v=>Number.isInteger(v.Rank)).length,feat_count:(c.FeatList??[]).filter(v=>Number.isInteger(v.Feat)).length,spell_count:c.ClassList.flatMap(v=>Array.from({length:10},(_,level)=>v['KnownList'+level]??[]).flat()).filter(v=>Number.isInteger(v.Spell)).length};
  return fixture.bytes;}return row.source==='vault'?vault.read(row.vaultId):fs.readFile(row.file);},resolveName:async value=>value?.text??value?.entries?.[0]?.text??'',publish:send,
  connect:async(connection,details,{signal}={})=>{
   signal?.throwIfAborted();
   if(menuCheck)throw Error('Network connections forbidden in menu check');
   const endpoint=policy.require(details),credentials={...details.credentials};lobby.endpoint=endpoint;report.endpoint=`${endpoint.host}:${endpoint.port}`;if(!credentials.cdKey)credentials.cdKey=await settings.cdKey();
   if(actionCheck){if((!headlessPlayersCheck&&!report.nativeAdmission?.success)||details.name!=='GodotNativeLocalTest')throw Error('Owned action admission must pass through the native profile and Direct Connect controls');report.nativeAdmissionIdentity={name:details.name,...endpoint,admission:headlessPlayersCheck?'headless-protocol':'native-controls'};}
   const status=await settings.status();signal?.throwIfAborted();
   const created=await createSession({install,...endpoint,name:details.name,credentials,userDirectory,cacheDirectory,modsDirectory:status.modsDirectory,disabledMods:status.disabledMods},connection,{signal});
   if(signal?.aborted||connection!==lobby.connection){await created.session.disconnect();throw Error('Cancelled native connection');}
   lobby.previewAccountScope=crypto.createHash('sha256').update(JSON.stringify([created.session.identity.publicKey,created.metadata.name])).digest('hex');
   attach(created.session,connection);lobby.attach(created.session,connection);directPortal.bind(created.session,connection);report.publicConnections+=endpoint.host==='127.0.0.1'?0:1;
   let pin;if(endpoint.host==='127.0.0.1'&&endpoint.port===localPort){if(directHandoffCheck){const source=await(await import('./native-direct-handoff-fixture.mjs')).identityPin(directHandoffMode.directory,endpoint);pin=source.pin;}else if(scriptFloatingOwned){const source=await(await import('./native-script-floating-server.mjs')).pin(scriptFloatingDirectory);pin=source.pin;report.scriptFloatingServerIdentity={fileSha256:source.fileSha256,identitySha256:source.identitySha256,descriptorSha256:source.descriptorSha256};}else if(levelSourceCheck){const source=await require('./native-level-up-source-server.cjs').pin(levelSourceDirectory);pin=source.pin;report.levelUpSourceServerIdentity={fileSha256:source.fileSha256,identitySha256:source.identitySha256,descriptorSha256:source.descriptorSha256};}else if(creationDirectory){const source=await require('./native-creation-vault-fixture.cjs').pin(creationDirectory);pin=source.pin;report.creationServerIdentitySource={path:path.relative(root,source.sourcePath).replaceAll('\\','/'),fileSha256:source.fileSha256,identitySha256:source.identitySha256,descriptorSha256:source.descriptorSha256};}else if(actionAssociateRecordCheck){const source=await require('./native-associate-record-pin.cjs').readAssociateRecordServerPin(report.associateRecordFixtureDirectory);pin=source.pin;report.associateRecordServerIdentitySource={path:path.relative(root,source.sourcePath).split(path.sep).join('/'),fileSha256:source.fileSha256,identitySha256:source.identitySha256};}else{const log=await fs.readFile(path.join(root,actionCheck?'runtime-logs/native-playability-actions-server/logs/nwengineLog.txt':'runtime-logs/local-multiplayer-server/logs/nwengineLog.txt'),'utf8');pin=log.match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];if(!pin)throw Error('Owned local server identity is unavailable');}}
   if(signal?.aborted||connection!==lobby.connection){await created.session.disconnect();return;}
   const connecting=created.session.connect({...endpoint,metadata:created.metadata,timeout:45000,...(pin?{expectedServerPublicKey:Buffer.from(pin,'base64')}:{})});
   if(localCancelCheck&&cancellationStage===1){setTimeout(()=>{if(connection===lobby.connection&&!created.session.closed){cancellationSentAt=performance.now();send({kind:'probe-session-cancel'});}},100);}
   await connecting;
  },disconnect:async options=>{
   const retiring=options.targetSession;
   rememberVaultId(retiring);retirePresentation(retiring,lobby.connection);
   try{if(options.saveCharacter&&retiring&&!retiring.closed&&['playing','area-loading'].includes(retiring.phase))await retiring.exportCharacter();}
   catch{throw Error('Disconnected, but the character could not be saved.');}
   finally{await retiring?.disconnect();localDisconnectedAt=Date.now();}
  },save:()=>{const current=lobby.session;rememberVaultId(current);return current.exportCharacter();}});
 directPortal=new NativeDirectPortal({lobby,policy,isCurrent:(current,connection)=>!ending&&session===current&&lobby.connection===connection,
  configFor:current=>{const config=sessionConfigs.get(current);return config?{...structuredClone(config),nativeVaultId:rememberVaultId(current)}:null;},
  prepare:async(request,connection,owned,signal)=>{const current=session,from=lobby.connection,next=await createSession(request,connection,{owned,signal});try{if(directHandoffCheck){const pin=await(await import('./native-direct-handoff-fixture.mjs')).identityPin(directHandoffMode.directory,request);next.expectedServerPublicKey=Buffer.from(pin.pin,'base64');directHandoffHarness.preparing({current,connection:from,next,endpoint:request});}return next;}catch(error){await next.session.disconnect();throw error;}},
  retire:async context=>{const{previous,to,current,signal}=context;signal.throwIfAborted();if(!current())throw Error('Retired native portal source');retirePresentation(previous,to);if(directHandoffCheck)await directHandoffHarness.retire(context);},
  install:(next,connection,previous)=>{if(directHandoffCheck)directHandoffHarness.install({previous,next,connection});const origin=sessionPersistence.get(previous),destination=sessionPersistence.get(next.session);if(origin&&destination)destination.vaultId=origin.vaultId??destination.vaultId;attach(next.session,connection);lobby.attach(next.session,connection);report.publicConnections+=lobby.endpoint.host==='127.0.0.1'?0:1;},
  resetFailed:(current,connection,previous)=>{if(lobby.connection!==connection||session!==current&&session!==previous)return;retirePresentation(session,connection);},
  onEvent:event=>{if(directHandoffCheck)directHandoffHarness.transferevent(event);report.portalEvents??=[];if(report.portalEvents.length>=128)report.portalEvents.shift();report.portalEvents.push({...event,at:Date.now()});}
 });
 if(directHandoffCheck)directHandoffHarness=new NativeDirectHandoffHostCheck({canonicalCharacterContinuity:true,compareCharacterChain:handoffCharacterProof.compareHandoffCharacterChain,compareRetryCharacter:handoffCharacterProof.compareHandoffCharacters,progressDiagnostics:true,fixture:directHandoffFixture,scenario:directHandoffMode.scenario,send,finish:reason=>void finish(reason),getScope:()=>({session,lobby,catalogReady,rawSerial,portalState:directPortal.snapshot(),rawPending:Boolean(rawPending),rawPendingSerial:rawPending?.serial,rawPendingGeneration:rawPending?.generation,pendingCommands:commandPump.tasks.size,lastCommandKind:report.lastCommandKind,socketBytesWritten:socket?.bytesWritten,socketWritableLength:socket?.writableLength,socketBytesRead:socket?.bytesRead,socketDestroyed:socket?.destroyed,...(directRawWire??{})}),rawCombat,characterDigest:bytes=>handoffCharacterProof.readHandoffCharacter(bytes)});
 lobby.inspectServer=async({endpoint,signal})=>{const target=policy.require(endpoint);return queryNetworkServer({...target,signal,extended:true});};
 browser=new ServerBrowserService({lobby,policy,store:new ServerBrowserStore(path.join(startup.settingsDirectory,'native-server-browser.json')),query:queryNetworkServer,discover:fetchNetworkServerList,settings:()=>settings.status(),send,playerName:arg('player-name')??null});
 const {LoginProfileService}=await import('./login-profile-service.mjs');
 loginProfiles=new LoginProfileService({store:settings,connection:()=>lobby.connection,locked:()=>localCheck||actionCheck||creationCheck||menuCheck||!lobby.snapshot().canJoin||browser.busy,send,onChange:status=>browser.adoptLoginProfile(status)});
 if(arg('server'))browser.lastAttempt={...parseAllowedServer(arg('server')),name:arg('player-name')??(await browser.store.load()).last.name};
 async function command(message,sessionAtDispatch=session,sendAtDispatch=send){
  loadingRecording?.acknowledgement(message);
  if(message.kind==='catalog-ready'&&message.nativeView)loadingRecording?.view(message.nativeView);
  const session=sessionAtDispatch;
  const send=value=>sendAtDispatch({connection:message.connection??lobby.connection,...value});
  report.lastCommandKind=message.kind;
  if(authenticated&&message.kind==='login-profile-input'){await loginProfiles.command(message);return;}
  if(!authenticated){if(message.kind!=='hello'||message.token!==token)throw Error('Native session handshake failed');authenticated=true;if(startupFeatureManifest){startupFeatureManifest.nativeStartup=message.runtimeFeatures;startupFeatureManifest.verification=featureManifest.verifyNativeObservation(startupFeatureManifest,message.runtimeFeatures);await fs.writeFile(output.replace(/\.json$/,'.startup.json'),JSON.stringify(startupFeatureManifest,null,2)+'\n');if(startupFeatureManifest.verification.status==='rejected'){void finish('Native startup feature verification failed: '+startupFeatureManifest.verification.errors.join('; '));return;}}lobby.emit();report.startupSurface=localCheck?'browser':'main-menu';send({kind:localCheck?'browser-open':'main-menu-open'});return;}
  if(authenticated&&directHandoffHarness?.command(message,session,message.connection??lobby.connection))return;
  if(directHandoffCheck&&message.kind==='browser-observed'){report.browserReady=true;void directHandoffHarness.boot().catch(error=>directHandoffHarness.fail(error.message));return;}
  if(message.kind==='main-menu-observed'){
   if(startupFeatureManifest){startupFeatureManifest.nativeStartup=message.runtimeFeatures;startupFeatureManifest.verification=featureManifest.verifyNativeObservation(startupFeatureManifest,message.runtimeFeatures,{requireObservedThread:true});await fs.writeFile(output.replace(/\.json$/,'.startup.json'),JSON.stringify(startupFeatureManifest,null,2)+'\n');if(startupFeatureManifest.verification.status==='rejected'){void finish('Native startup feature verification failed: '+startupFeatureManifest.verification.errors.join('; '));return;}}
   report.startupMainMenu={ready:message.ready,mainVisible:message.mainVisible,browserHidden:message.browserHidden,lobbyHidden:message.lobbyHidden};
   if(startupFeatureCheck&&!menuCheckFinishing){menuCheckFinishing=true;if(!message.ready||!message.browserHidden||!message.lobbyHidden){void finish('Headless startup ownership/readiness check failed');return;}report.headlessStartupScope='Logical menu readiness and capability handshake; headless visibility/pixels are not graphical acceptance';send({kind:'finish'});return;}
   if(menuCheck&&!menuCheckFinishing){menuCheckFinishing=true;if(!message.ready||!message.mainVisible||!message.browserHidden||!message.lobbyHidden){void finish('Native startup did not show Main Menu');return;}send({kind:menuExitCheck?'probe-original-menu-exit':'finish-menu-check'});}return;
  }
  if(message.kind==='browser-observed'){report.browserReady=true;if(menuCheck&&!menuCheckFinishing){menuCheckFinishing=true;send({kind:'finish-menu-check'});}else if(!menuCheck&&localCheck&&!session){
   if(headlessPlayersCheck){if(!localAdmissionPending){localAdmissionPending=true;send({kind:'browser-closed',connection:lobby.connection});await lobby.join({connection:lobby.connection,details:{host:'127.0.0.1',port:localPort,name:'GodotNativeLocalTest',credentials:{password:''}}});if(lobby.error)void finish('Headless local protocol admission failed: '+lobby.error);}return;}
   if(actionCheck){if(!localAdmissionPending){localAdmissionPending=true;send({kind:'probe-native-admission',host:'127.0.0.1',port:localPort});}return;}
   if(localCancelCheck&&cancellationStage===0){
    cancellationStage=1;cancellationSink=require('node:dgram').createSocket('udp4');await new Promise((resolve,reject)=>{cancellationSink.once('error',reject);cancellationSink.bind(0,'127.0.0.1',resolve);});policy.allowed.add('127.0.0.1:'+cancellationSink.address().port);
    send({kind:'browser-closed',connection:lobby.connection});await lobby.join({connection:lobby.connection,details:{host:'127.0.0.1',port:cancellationSink.address().port,name:'GodotCancelLocalTest',credentials:{password:''}}});return;
   }
   if(localCancelCheck&&cancellationStage!==2)return;
   send({kind:'browser-closed',connection:lobby.connection});await lobby.join({connection:lobby.connection,details:{host:'127.0.0.1',port:localPort,name:'GodotNativeLocalTest',credentials:{password:''}}});if(lobby.error)void finish('Local admission failed: '+lobby.error);}return;}
  if(message.kind==='browser-input'){if(message.operation==='join'&&loginProfiles.busy){browser.status='Wait for the login profile to finish saving';await browser.render();return;}await browser.command(message);return;}
  if(message.kind==='native-admission-proof'){if(!actionCheck||message.connection!==lobby.connection)throw Error('Native admission proof is not owned');report.nativeAdmission=message;if(!message.success)void finish('Native admission UI check failed');return;}
  if(message.kind==='native-chooser-ready'){
   if(!localCheck||!ownsConnection(message)||!lobby.selectable()||typeof message.key!=='string'||!message.key||message.key!==lobby.selected||message.key!==message.firstKey||message.unadmitted!==true)throw Error('Native chooser readiness is not owned');
   lobby.row({connection:message.connection,key:message.key});
   report.nativeChooserReady={...message,success:true};return;
  }
  if(message.kind==='native-character-preview-proof'){
   if(!actionCheck)throw Error('Native preview proof requires the owned action fixture');
   if(!ownsConnection(message)||!lobby.selectable()||message.key!==lobby.selected||message.sha256!==lobby.preview?.sha256){report.staleCharacterPreviewProofs=(report.staleCharacterPreviewProofs??0)+1;return;}
   const valid=previewProofMatches(message,{connection:lobby.connection,key:lobby.selected,sha256:lobby.preview?.sha256},report.characterPreviewExpected);
   report.characterPreviewProof={...message,success:Boolean(valid)};if(!valid)void finish('Native preview did not match the owned BIC');return;
  }
  if(message.kind==='test-lobby-participant'){
   if(!actionLobbyPagesCheck||!ownsConnection(message)||!lobby.selectable())throw Error('Roster participant command is not owned');
   if(message.operation==='start'){
    if(lobbyParticipantWork||!barterPeerKey)throw Error('Owned roster participant credentials or startup are unavailable');
    const connection=lobby.connection,key=barterPeerKey;barterPeerKey='';lobbyParticipantAbort=new AbortController();
    lobbyParticipantWork=(async()=>{try{
     const participant=await(await import('./native-lobby-participant.mjs')).startNativeLobbyParticipant({install,userDirectory:path.join(userDirectory,'roster-participant'),cdKey:key,signal:lobbyParticipantAbort.signal});
     if(ending||lobby.connection!==connection){await participant.close();return;}lobbyParticipant=participant;send({kind:'test-lobby-participant-status',value:participant.snapshot()});
    }catch(error){if(!ending&&lobby.connection===connection){send({kind:'test-lobby-participant-status',value:{ready:false,error:error.message}});void finish(error.message);}}})();return;
   }
   if(message.operation==='close'&&lobbyParticipant){await lobbyParticipant.close();send({kind:'test-lobby-participant-status',value:lobbyParticipant.snapshot()});return;}
   throw Error('Invalid owned roster participant operation');
  }
  if(message.kind==='native-lobby-pages-proof'){
   if(!actionLobbyPagesCheck||!ownsConnection(message)||report.lobbyPages)throw Error('Roster proof is not owned');
   report.lobbyPages=message;const wire=report.lobbyPageWire??{};
   const valid=message.success&&message.checks?.length===18&&message.checks.every(row=>row.passed)&&wire.received?.some(row=>row.present&&row.id===message.rosterId)&&wire.received?.some(row=>!row.present&&row.id===message.rosterId)&&wire.sent?.some(row=>row[2]===1)&&wire.sent?.some(row=>row[2]===2)&&lobbyParticipant?.snapshot().closed&&!session.characterSubmitted&&session.world.registry.objects.size===0;
   report.lobbyPageAuthoritative={success:Boolean(valid),observerSubmitted:Boolean(session.characterSubmitted),observerWorldObjects:session.world.registry.objects.size};
   if(!valid){report.lobbyPages.success=false;void finish('Native live roster proof failed');}return;
  }
  if(message.kind==='native-local-delete-proof'){
   if(!actionLocalDeleteCheck||!ownsConnection(message)||!lobby.selectable()||report.localDelete)throw Error('Local Delete proof is not owned');
   const refresh=report.localDeleteRefresh??[];
   const valid=message.success&&Array.isArray(message.checks)&&message.checks.length>=18&&message.checks.every(row=>row.passed)&&refresh.length===2&&refresh.every(row=>row.accepted&&row.absent&&!row.listed)&&!session.characterSubmitted&&session.world.registry.objects.size===0;
   report.localDelete={...message,success:Boolean(valid),observerSubmitted:Boolean(session.characterSubmitted),observerWorldObjects:session.world.registry.objects.size};
   if(!valid)void finish('Native live Delete/refresh proof failed');return;
  }
  if(message.kind==='lobby-page'){await lobby.setPage(message);return;}
  if(message.kind==='lobby-choose'){await lobby.choose(message);return;}
  if(message.kind==='lobby-local-refresh'){
   const row=actionLocalDeleteCheck?lobby.locals.get(message.key):null;await lobby.refreshLocal(message);
   if(actionLocalDeleteCheck){
    const expected=['local:nwn_delete_a.bic','local:nwn_delete_b.bic'];
    if(!expected.includes(message.key)||!row?.nativeFile?.path)throw Error('Unexpected owned Delete fixture');
    const wanted=path.join(userDirectory,'localvault',message.key.slice(6));
    if(path.resolve(row.nativeFile.path)!==path.resolve(wanted))throw Error('Owned Delete fixture path mismatch');
    let absent=false;try{await fs.access(wanted);}catch(e){if(e.code!=='ENOENT')throw e;absent=true;}
    (report.localDeleteRefresh??=[]).push({key:message.key,requestId:message.requestId,accepted:lobby.localRefreshAck?.requestId===message.requestId&&lobby.localRefreshAck?.accepted!==false,absent,listed:lobby.locals.has(message.key)});
   }return;
  }
  if(message.kind==='lobby-play'){await lobby.play(message);return;}
  if(message.kind==='lobby-disconnect'){lobby.requireOwner(message);if(lobby.cancelling||typeof message.saveCharacter!=='boolean')throw Error('Invalid disconnect request');rememberVaultId(lobby.session);const cleanup=directPortal.cancel(lobby.session,message.connection),leaving=lobby.leave(message);await Promise.all([cleanup,leaving]);return;}
  if(message.kind==='lobby-export'){report.nativeExportRequests=(report.nativeExportRequests??0)+1;if(actionQuickbarCheck&&session?.world.quickbar[35]?.type===18)report.quickbarMacroExportRequested={at:Date.now(),index:35};await lobby.export(message);return;}
  if(message.kind==='lobby-cancel-join'){
   lobby.requireOwner(message);if(!lobby.snapshot().canCancelJoin)throw Error('No connection attempt to cancel');const retiring=session,connection=lobby.connection,cleanup=directPortal.cancel(lobby.session,connection),leaving=lobby.cancelJoin(message);await Promise.all([cleanup,leaving]);
   if(localCancelCheck&&lobby.connection===connection+1&&cancellationStage===1){report.cancelCheck={elapsedMs:performance.now()-cancellationSentAt,peerClosed:retiring?.peer.closed===true};cancellationStage=2;cancellationSink.close();cancellationSink=null;}
   return;
  }
  if(message.kind==='lobby-join'){send({kind:'browser-open'});return;}
  if(message.kind==='creation-source-phase'||message.kind==='creation-native-phase'){if(creationApplyDiagnostic&&ownsConnection(message))creationApplyDiagnostic.record('native',message);return;}
  if(message.kind==='creation-proof'){if(!creationCheck||!ownsConnection(message))return;if(creationApplyDiagnostic)creationApplyDiagnostic.record('native',{kind:message.kind,phase:'Source controls completed',checks:message.checks,connection:message.connection});report.creationProof=message;if(creationReconnectFrom)report.creationReconnectSelection=message.reconnectSelection??{success:false};if(!message.success)void finish('Native character creation probe failed: '+JSON.stringify(message.failures));return;}
  if(message.kind.startsWith('native-creation-')){
   if(!ownsConnection(message))throw Error('Character creation belongs to a retired connection');
   // Capture the requesting draft before any asynchronous character upload.
   // A reply must never inherit a replacement global session/draft identity.
   const creationOwner=session,creationReply={kind:'native-creation-result',connection:message.connection,draft:message.draft,operation:message.kind};
   try{
    if(!Number.isSafeInteger(message.draft)||message.draft<1)throw Error('Character creation draft is unavailable');
    if(message.kind==='native-creation-begin'){if(!lobby.selectable()||!session.resourceResult?.ready)throw Error('Character creation is not available');lobby.creating=true;lobby.emit();}
    else if(message.kind==='native-creation-cancel'){if(session.characterUploaded||session.characterSubmitted)throw Error('Character is already submitted');lobby.creating=false;lobby.emit();}
    else if(message.kind==='native-creation-submit'){
     if(!lobby.creating||!lobby.selectable()||typeof message.data!=='string'||message.data.length>4*1024*1024)throw Error('Character submission is stale or too large');
     const bytes=Buffer.from(message.data,'base64');try{if(bytes.toString('base64')!==message.data)throw Error('Invalid character encoding');report.nativeCreation={bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),nativeGenerated:true};if(creationCheck){const {parseGff,getGffFieldTypes,getGffStructType}=await import('../../src/gff.js');const creationRoot=parseGff(bytes,'BIC ').root;report.nativeCreation.hitpoints=require('./native-creation-hp-proof.cjs').snapshot(creationRoot,getGffFieldTypes);if(arg('creation-class')==='cleric'){const classProof=require('./native-creation-class-proof.cjs');report.nativeCreation.classFields=classProof.snapshot(creationRoot,getGffStructType,getGffFieldTypes);report.nativeCreation.classShape=classProof.verifySource(report.nativeCreation.classFields);if(!report.nativeCreation.classShape.success)throw Error('Native Cleric upload field shape differs from original first-level writer');}}await creationOwner.selectCharacter(bytes,{createOnServer:creationOwner.localVaultAllowed!==true});}finally{bytes.fill(0);}
    }else throw Error('Unsupported native character operation');
    send({...creationReply,accepted:true});
   }catch(error){send({...creationReply,accepted:false,text:error.message});}return;
  }
  if(message.kind==='catalog-ready'){if(!ownsConnection(message)){rejectRetired(message);return;}catalogReady=true;report.catalogReady=true;return;}
  if(message.kind==='raw-world-accepted'){if(creationApplyDiagnostic)creationApplyDiagnostic.accepted(message);if(!ownsConnection(message)){rejectRetired(message);return;}if(rawPending?.serial===message.serial&&rawPending.generation===message.generation&&worldDeltas.acknowledge(message)){if(actionQuickbarCheck&&rawPending.inventoryRevision>0){report.quickbarInventoryTimings??=[];if(report.quickbarInventoryTimings.length<128)report.quickbarInventoryTimings.push({phase:'raw-world-ack',at:Date.now(),serial:rawPending.serial,revision:rawPending.inventoryRevision});}rawPending=null;}return;}
  if(message.kind==='finished'){if(message.connection!==lobby.connection){rejectRetired(message);return;}if(creationApplyDiagnostic)creationApplyDiagnostic.boundary('native','finished:received',{connection:message.connection,success:message.success===true,ending});combatCheckLifecycle?.mark('finished',message.connection,message.success===true);associateRecordLifecycle?.mark('finished',message.connection,message.success===true);npcCombatLifecycle?.mark('finished',message.connection,message.success===true);send({kind:'finish-ack'});combatCheckLifecycle?.mark('ack-sent',message.connection);associateRecordLifecycle?.mark('ack-sent',message.connection);npcCombatLifecycle?.mark('ack-sent',message.connection);report.success=menuCheck?Boolean(message.success&&(menuExitCheck?report.startupMainMenu?.ready:report.browserReady)&&report.publicConnections===0):Boolean(message.success);return;}
  if(message.kind==='level-source-progress'){if(!levelSourceCheck||!ownsConnection(message)||message.generation!==session.areaGeneration||message.areaId!==session.world.areaId||message.actorId!==session.world.localObjectId)throw Error('Source level-up progress scope retired');if(!Number.isSafeInteger(message.checks)||message.checks<0||message.checks>1024||typeof message.phase!=='string'||message.phase.length>160||typeof message.success!=='boolean')throw Error('Source level-up progress exceeds schema');report.levelUpSourceProgress={at:Date.now(),checks:message.checks,phase:message.phase,success:message.success};await fs.writeFile(output.replace(/\.json$/,'.level-source-progress.json'),JSON.stringify(report.levelUpSourceProgress));return;}
  if(['ordinary-speech-visual-ready','ordinary-speech-visual-sample','ordinary-speech-visual-finished'].includes(message.kind)){
   if(!scriptFloatingVisual)throw Error('Visual observation requires its distinct mode');
   const observation=require('./native-ordinary-speech-visual-mode.cjs').payload(message,session,lobby.connection);
   if(message.seconds!==visualMode.seconds)throw Error('Visual hold differs from reviewed duration');
   if(message.kind==='ordinary-speech-visual-ready'){if(report.visualReady)throw Error('Duplicate visual readiness');report.visualReady=observation;console.log('NATIVE_LOCAL_VISUAL_READY '+JSON.stringify(observation));}
   else if(!report.visualReady)throw Error('Visual observation precedes readiness');
   if(message.kind==='ordinary-speech-visual-sample'){report.visualSamples??=[];if(report.visualSamples.length>=180)throw Error('Visual sample bound exceeded');report.visualSamples.push(observation);}
   await fs.writeFile(output.replace(/\.json$/,'.visual.json'),JSON.stringify({ready:report.visualReady,last:observation},null,2)+'\n');
   if(message.kind==='ordinary-speech-visual-finished'){if(message.elapsedMs<visualMode.seconds*1000)throw Error('Visual hold ended early');report.visualFinished=observation;report.localCycles=[{connection:lobby.connection,generation:session.areaGeneration,visualInspection:true,movementAcceptance:false}];localCycleEnding=true;send({kind:'finish'});}
   return;
  }
  if(message.kind==='script-floating-finished'){if(!scriptFloatingCheck||!ownsConnection(message)||message.scope?.connection!==lobby.connection||message.scope?.generation!==session.areaGeneration||message.scope?.areaId!==session.world.areaId)throw Error('ScriptFloating completion scope retired');if(Buffer.byteLength(JSON.stringify(message))>65536)throw Error('ScriptFloating completion exceeds64KiB');report.scriptFloatingProof=scriptFloatingHarness.finish(message);if(!report.scriptFloatingProof.success){void finish('Original ScriptFloating received/native proof rejected');return;}report.localCycles=[{connection:lobby.connection,generation:session.areaGeneration,scriptFloatingCheck:true,movementAcceptance:false}];localCycleEnding=true;send({kind:'finish'});return;}
  if(message.kind==='level-source-finished'){if(!levelSourceCheck||!ownsConnection(message)||message.generation!==session.areaGeneration||message.areaId!==session.world.areaId||message.actorId!==session.world.localObjectId)throw Error('Source level-up completion scope retired');report.levelUpSourceInput=message;if(!message.success){void finish('Actual source level-up controls rejected: '+JSON.stringify(message.failures));return;}try{levelSourceHarness.prepare(message,session,lobby.connection);await session.exportCharacter();report.levelUpSourceProof=levelSourceHarness.finish(session,lobby.connection);if(!report.levelUpSourceProof.success)throw Error('Original source level-up received/export proof differs');report.localWalkDistance=localWalkProof.nativeDistance;report.authoritativeDistance=localWalkProof.serverDistance;report.localCycles=[{connection:lobby.connection,generation:session.areaGeneration,levelSourceCheck:true}];localCycleEnding=true;send({kind:'finish'});}catch(error){void finish(error.message);}return;}
  if(message.kind==='actions-progress'){if(actionCheck&&ownsConnection(message)){report.actionProgress??=[];report.actionProgress.push(message);await fs.writeFile(output.replace(/\.json$/,'.progress.json'),JSON.stringify({last:message,checks:report.actionProgress},null,2));}return;}
  if(message.kind==='actions-finished'){if(!actionCheck||!ownsConnection(message))return;report.actions=message;combatCheckLifecycle?.mark('actions-complete',message.connection,message.success===true);associateRecordLifecycle?.mark('actions-complete',message.connection,message.success===true);npcCombatLifecycle?.mark('actions-complete',message.connection,message.success===true);if(!message.success){void finish('Native UI action checks failed: '+JSON.stringify(message.failures));return;}await session.exportCharacter();combatCheckLifecycle?.mark('export-complete',message.connection,Boolean(report.exportedCharacter));associateRecordLifecycle?.mark('export-complete',message.connection,Boolean(report.exportedCharacter));npcCombatLifecycle?.mark('export-complete',message.connection,Boolean(report.exportedCharacter));report.localWalkDistance=localWalkProof.nativeDistance;report.authoritativeDistance=localWalkProof.serverDistance;report.localCycles=[{connection:lobby.connection,generation:session.areaGeneration,actionCheck:true}];localCycleEnding=true;combatCheckLifecycle?.mark('finish-sent',message.connection);associateRecordLifecycle?.mark('finish-sent',message.connection);npcCombatLifecycle?.mark('finish-sent',message.connection);send({kind:'finish'});return;}
  if(message.kind==='native-desktop-proof'){if(!localCheck||!ownsConnection(message))return;report.desktopProof=message;if(!message.success)throw Error('Native gameplay desktop probe failed');return;}
  if(message.kind==='render-settings-proof'){if(!localCheck||!ownsConnection(message))return;if(!message.opened||!message.paused||!message.restored||message.emitters<1||message.objects_before!==message.objects_after)throw Error('Native graphics settings probe failed');report.renderSettingsProof=message;return;}
  if(message.kind==='observed'){
   if(message.nativeView)loadingRecording?.view(message.nativeView);
   if(!ownsConnection(message)){rejectRetired(message);return;}
   report.lastObservation=message;setHostProfiling(Boolean(message.frame_profile?.enabled!==false&&message.frame_profile?.metrics));
   if(startupFeatureManifest){const scopeKey=[message.connection,message.generation,message.areaId].join('/');if(scopeKey!==featureWorldScope&&message.state?.ready&&message.generation===session?.areaGeneration&&message.areaId===session?.world?.areaId){featureWorldScope=scopeKey;startupFeatureManifest.worldSelections=featureManifest.worldSelection(message.state,{connection:message.connection,generation:message.generation,areaId:message.areaId});startupFeatureManifest.worldVerification=featureManifest.verifyWorldSelection(startupFeatureManifest,startupFeatureManifest.worldSelections);await fs.writeFile(output.replace(/\.json$/,'.startup.json'),JSON.stringify(startupFeatureManifest,null,2)+'\n');if(startupFeatureManifest.worldVerification.status==='rejected'){void finish('Native world feature verification failed: '+startupFeatureManifest.worldVerification.errors.join('; '));return;}}}
   if(message.frame_profile?.enabled!==false&&message.frame_profile?.metrics&&Date.now()-profileAt>=2000){
    profileAt=Date.now();const state=message.state??{},particles=state.native_particles??{};
    const sample={protocol_output:message.protocol_output,record_selection:message.record_selection,render_configuration:renderConfiguration.summary,particle_configuration:{presentation:renderConfiguration.summary.particle_presentation,lighting:renderConfiguration.summary.particle_lighting},protocol_host:hostMetrics(),particle_visibility:message.particle_visibility,ui_startup:message.ui_startup,at:profileAt,connection:message.connection,generation:message.generation,areaId:message.areaId,fps:message.fps,ready:state.ready,pending_batches:state.pending_batches,entities:state.entities,desired:state.desired,tiles:state.terrain?.rendered_tiles,particles:Object.fromEntries(['emitters','simulated','active','vertices','failed','culled_emitters','currently_culled'].map(key=>[key,particles[key]])),shared_particles:state.native_particle_stream??null,frame_profile:message.frame_profile};
    if(message.profile_presentation)sample.profile_presentation=message.profile_presentation;
    if(Number.isFinite(message.native_ticks_ms))sample.native_ticks_ms=message.native_ticks_ms;
    if(message.area_lighting)sample.area_lighting=message.area_lighting;
    if(state.focus_lighting)sample.focus_lighting=state.focus_lighting;
    if(state.point_shadows)sample.point_shadows=state.point_shadows;
    if(state.placeable_lights)sample.placeable_lights=state.placeable_lights;
    loadingRecording?.baseline(sample);
    await fs.appendFile(path.join(project,'reports',run+'.performance.jsonl'),JSON.stringify(sample)+'\n');
   }
   if(directHandoffCheck)return;
   // Visual inspection has its own current-source readiness and never enters generic movement/picking.
   if(scriptFloatingVisual){
    if(!localCycleEnding&&!actionsProbeSent&&catalogReady&&!rawPending&&session.phase==='playing'&&message.generation===session.areaGeneration&&message.areaId===session.world.areaId&&message.nativeProcessId===native?.pid&&message.state.ready===true&&message.state.object_visuals_complete===true&&message.state.pending_batches===0&&message.state.entities+message.state.hidden===message.state.desired){actionsProbeSent=true;send({kind:'probe-ordinary-speech-visual',generation:session.areaGeneration,areaId:session.world.areaId,seconds:visualMode.seconds});}
    return;
   }
   // Dedicated received-script validation has no movement/picking claim.
   if(scriptFloatingCheck){
    if(!localCycleEnding&&!actionsProbeSent&&catalogReady&&!rawPending&&session.phase==='playing'&&message.generation===session.areaGeneration&&message.areaId===session.world.areaId&&message.nativeProcessId===native?.pid&&message.state.ready===true&&message.state.object_visuals_complete===true&&message.state.pending_batches===0&&message.state.entities+message.state.hidden===message.state.desired){
     try{report.scriptFloatingReady=scriptFloatingHarness.ready(session,lobby.connection,message);actionsProbeSent=true;send({kind:'probe-script-floating'});}catch{void finish('Actual current ScriptFloating world/source readiness was rejected');}
    }
    return;
   }
   if(localCheck&&recordLoading){
    if(!localCycleEnding&&message.state.ready&&message.state.object_visuals_complete&&message.state.native_references?.pending===0&&catalogReady){
     report.loadingSettledAt??=Date.now();if(Date.now()-report.loadingSettledAt>2000){report.loadingCheck={world:message.state,scope:'Original localhost Prelude native loading/recording only; no movement, UI action or FPS acceptance'};localCycleEnding=true;send({kind:'finish'});}
    }return;
   }
   if(localCheck&&message.state.ready&&!localCycleEnding){
    if(lastRetiredConnection>=0&&staleProbeConnection!==lobby.connection){
     staleProbeConnection=lobby.connection;const p=session.world.registry.get(session.world.localObjectId)?.replicated?.position;
     send({kind:'session-reset',connection:lastRetiredConnection});send({kind:'setup',connection:lastRetiredConnection});send({kind:'raw-world-begin',connection:lastRetiredConnection,serial:0,generation:1});send({kind:'ui-protocol',connection:lastRetiredConnection,generation:1,message:{kind:'dialog-close'}});
     if(p)send({kind:'probe-stale-world-input',oldConnection:lastRetiredConnection,position:p});
    }
    if(localStreamAbort&&!report.localAbortedCycles?.length&&message.state.pending_batches>0&&message.state.entities+message.state.hidden<message.state.desired){
     report.localAbortedCycles=[{connection:lobby.connection,generation:session.areaGeneration,nativeProcessId:message.nativeProcessId,state:message.state}];lastRetiredConnection=lobby.connection;localCycleEnding=true;send({kind:'probe-session-disconnect'});return;
    }
    if(!localWalk){
     const p=session.world.registry.get(session.world.localObjectId)?.replicated?.position;
     if(p){localWalk=true;localWalkAt=Date.now();localWalkOrigin=p.slice();localWalkGeneration=session.areaGeneration;report.firstPlayable={entities:message.state.entities,desired:message.state.desired,pendingBatches:message.state.pending_batches,playableMs:message.state.playable_ms};send({kind:'probe-walk',generation:session.areaGeneration,position:[p[0]+(actionCheck?-1.5:1.5),p[1],p[2]]});}
    }else{
     if(message.controlledDistance>0.05&&authoritativeDistance>0.05&&message.state.entities+message.state.hidden<message.state.desired&&!report.movementWhileStreaming)report.movementWhileStreaming={nativeDistance:message.controlledDistance,serverDistance:authoritativeDistance,entities:message.state.entities,desired:message.state.desired,pendingBatches:message.state.pending_batches};
     if(!localWalkProof&&message.controlledDistance>0.2&&authoritativeDistance>0.2&&authoritativeDistance<2&&Date.now()-localWalkAt>3000&&message.state.pending_batches===0&&message.state.entities+message.state.hidden===message.state.desired)localWalkProof={nativeDistance:message.controlledDistance,serverDistance:authoritativeDistance};
     if(localWalkProof){
      if(creationCheck){
       if(!report.creationPostAdmissionExportRequested){const owner=session;creationHpOwner=require('./native-creation-hp-owner.cjs').capture(owner,lobby.connection);const scope=creationHpOwner.scope;report.creationPostAdmissionExportRequested={at:Date.now(),...scope};await owner.exportCharacter();require('./native-creation-hp-owner.cjs').assertCurrent(creationHpOwner,session,lobby.connection);report.creationPostAdmissionExportComplete=true;creationCompletion.exported(scope);return;}
       if(!report.creationPostAdmissionExportComplete)return;
       const completion=creationCompletion.observe(message,{rawPending:Boolean(rawPending)});report.creationCompletion=creationCompletion.snapshot();if(!completion.ready)return;
       localCycleEnding=true;report.localWalkDistance=localWalkProof.nativeDistance;report.authoritativeDistance=localWalkProof.serverDistance;report.localCycles=[{connection:lobby.connection,generation:session.areaGeneration,creationCheck:true,areaId:session.world.areaId,nativeDistance:localWalkProof.nativeDistance,serverDistance:localWalkProof.serverDistance}];send({kind:'finish'});return;
      }
      if(levelSourceCheck){if(!actionsProbeSent){actionsProbeSent=true;send({kind:'probe-level-source'});}return;}
      if(headlessPlayersCheck){if(!actionsProbeSent){actionsProbeSent=true;send({kind:'probe-live-actions'});}return;}
      if(!report.renderSettingsProof){if(!settingsProbeSent){settingsProbeSent=true;send({kind:'probe-render-settings'});}return;}
      if(!report.desktopProof){if(!desktopProbeSent){desktopProbeSent=true;send({kind:'probe-native-desktop'});}return;}
      if(actionCheck){if(!actionsProbeSent){actionsProbeSent=true;send({kind:'probe-live-actions'});}return;}
      report.localWalkDistance=localWalkProof.nativeDistance;report.authoritativeDistance=localWalkProof.serverDistance;report.afterUiMovement={nativeDistance:message.controlledDistance,serverDistance:authoritativeDistance};localCycleEnding=true;report.localCycles??=[];report.localCycles.push({connection:lobby.connection,generation:session.areaGeneration,nativeProcessId:message.nativeProcessId,areaId:session.world.areaId,nativeDistance:localWalkProof.nativeDistance,serverDistance:localWalkProof.serverDistance,firstPlayable:report.firstPlayable,movementWhileStreaming:report.movementWhileStreaming,state:message.state});
      if(report.localCycles.length<localCycles){lastRetiredConnection=lobby.connection;send({kind:'probe-session-disconnect'});}else send({kind:'finish'});
     }
    }
   }
   return;
  }
  if(message.kind==='test-barter-peer-observed'){
   if(actionCheck&&actionBarterCheck&&ownsConnection(message)){report.peerStatusTrace??=[];if(report.peerStatusTrace.length>=128)report.peerStatusTrace.shift();report.peerStatusTrace.push({serial:message.serial,at:Date.now(),direction:'observed',invitation:Boolean(message.invitation)});}return;
  }
  if(!ownsConnection(message)){rejectRetired(message);return;}
  if(message.generation!==session.areaGeneration||message.areaId!==session.world.areaId)throw Error('Native input belongs to a retired world');
  if(message.kind==='area-ready'){if(!session.areaReadySent)await session.areaReady(message.generation);report.areas.push({connection:lobby.connection,id:message.areaId,generation:message.generation});return;}
  if(message.kind==='test-barter-peer'){
   if(!actionCheck||!actionBarterCheck||!ownsConnection(message))return;
   if(message.operation==='start-peer'){
    if(barterPeerWork)throw Error('Owned barter peer already started');
    const connection=lobby.connection;barterPeerAbort=new AbortController();
    let peerStatusSerial=0;
    const publish=value=>{if(!ending&&lobby.connection===connection){const serial=++peerStatusSerial;report.peerStatusTrace??=[];if(report.peerStatusTrace.length>=128)report.peerStatusTrace.shift();report.peerStatusTrace.push({serial,at:Date.now(),direction:'sent',ready:Boolean(value.ready),invitation:Boolean(value.partyState?.field7DC),queuedBytes:socket?.writableLength??0});send({kind:'test-barter-peer-status',serial,value});}};
    barterPeerWork=(async()=>{try{const key=barterPeerKey||await settings.cdKey();barterPeerKey='';const peer=await(await import('./native-barter-peer.mjs')).startNativeBarterPeer({install,userDirectory,cdKey:key,mainSession:session,signal:barterPeerAbort.signal,publish});if(ending){await peer.close();return;}barterPeer=peer;publish(peer.snapshot());}catch(error){publish({ready:false,error:'The second owned test peer could not enter the local server',stage:error.stage??'start',phase:error.phase??'uncreated',reasonCode:error.reasonCode??null,connectionError:error.connectionError??null,diagnosticCodes:error.diagnosticCodes??[]});}})();return;
   }
   if(!barterPeer)throw Error('Owned barter peer is not ready');await barterPeer.perform(message.operation,message.value);return;
  }
  const scope={areaId:message.areaId,areaGeneration:message.generation};if(session.phase!=='playing')throw Error('Native world is not playing');
  if(message.kind.startsWith('native-')){
	if(actionQuickbarCheck&&['native-quickbar-assign','native-emote','native-quickchat','native-barter'].includes(message.kind)){report.quickbarRequests??=[];if(report.quickbarRequests.length<128)report.quickbarRequests.push(structuredClone(message));if(message.kind==='native-quickbar-assign'&&message.button?.type===1)for(const id of [message.button.itemId,message.button.secondaryItemId])if(Number.isInteger(id)&&id!==0x7f000000)quickbarTestItemIds.add(id);}
	if(actionSpecialAttackCheck&&['native-feat','native-cancel-action'].includes(message.kind)){report.specialAttackRequests??=[];report.specialAttackRequests.push({kind:message.kind,featId:message.featId,targetId:message.targetId,auxiliary:message.auxiliary,actionId:message.actionId,groupId:message.groupId});}
    if(actionFeatCheck&&['native-feat','native-quickbar-assign','native-mode','walk'].includes(message.kind)){report.featFamilyRequests??=[];if(report.featFamilyRequests.length<16)report.featFamilyRequests.push(structuredClone(message));}
   const input={...message,...scope,actorId:session.world.localObjectId};let result;
   if(['native-map','native-party','native-chat-party','native-players','native-player-attitude','native-disengage','native-cancel-polymorph'].includes(message.kind))input.actorId=message.actorId;
   // Correlate transport refusal only. Success still waits for raw server slots.
   const preparationReply=message.kind==='native-chat-party'?{generation:message.generation,areaId:message.areaId,actorId:input.actorId}:['native-prepare','native-map','native-party','native-players','native-player-attitude'].includes(message.kind)&&Number.isSafeInteger(message.requestId)?{requestId:message.requestId,generation:message.generation,areaId:message.areaId,actorId:input.actorId}:{};
   let partyTrace,levelSourceObservation,levelReply={};
   if(actionCheck&&message.kind==='native-party'){
    report.partyRequestTrace??=[];if(report.partyRequestTrace.length>=64)report.partyRequestTrace.shift();
    const flags=session.world.registry.get(session.world.localObjectId)?.replicated?.party??{};
    partyTrace={at:Date.now(),operation:input.operation,requestId:input.requestId,flags:{singleton:flags.singleton,leader:flags.leader,invitation:flags.field7DC}};report.partyRequestTrace.push(partyTrace);
   }
   try{
    if(message.kind==='native-level-up')levelReply=require('./native-level-up-reply-scope.cjs').captureLevelUpReplyScope(message)??{};
    if(levelSourceCheck&&message.kind==='native-level-up')levelSourceObservation=levelSourceHarness.request(session,lobby.connection,input);
    const handlers={'native-barter':'barterInput','native-script-target':'selectScriptTarget','native-nui-input':'nuiInput','native-cancel-action':'cancelAction','native-rest':'rest','native-disengage':'disengage','native-cancel-polymorph':'cancelPolymorph','native-panel':'hudPanel','native-cast':'castSpell','native-spell-like':'castSpellLike','native-feat':'useFeat','native-mode':'changeMode','native-quickbar-assign':'assignQuickbar','native-quickbar-activate':'activateQuickbar','native-prepare':'prepareSpell','native-player-attitude':'playerAttitude','native-associate':'associateCommand','native-quickchat':'quickChat','native-level-up':'levelUp','native-store':'storeInput','native-item-ability':'useItem','native-possess':'possessFamiliar'};
    if(message.kind==='native-emote')result=await session.playEmote(input);
    else if(message.kind==='native-map')result=await session.mapInput(input);
    else if(message.kind==='native-party')result=await session.partyInput(input);
    else if(message.kind==='native-chat-party')result=await session.partyChatInput(input);
    else if(message.kind==='native-players')result=await session.playerListInput(input);
    else if(message.kind==='native-activity'){const actor=session.controlledActor(scope.areaId,scope.areaGeneration);result=await(await import('./activity-input.mjs')).submitNativeActivity(session,{...scope,actor,actorId:actor.id},input);if(actionRadialCheck){report.radialActivityRequests??=[];if(report.radialActivityRequests.length<32)report.radialActivityRequests.push({activityId:message.activityId,targetId:message.targetId,sent:result.sent});}}
    else if(message.kind==='native-skill'){const actor=session.controlledActor(scope.areaId,scope.areaGeneration);result=await(await import('./skill-input.mjs')).submitNativeSkill(session,{...scope,actor,actorId:actor.id},input);}else{const method=handlers[message.kind];if(!method)throw Error('That action is not connected yet');
    result=await session[method](input);}
    if(levelSourceObservation)levelSourceHarness.result(levelSourceObservation,session,lobby.connection,result,levelReply);
    if(partyTrace){partyTrace.accepted=true;partyTrace.sent=result?.sent===true;}
    send({kind:'ui-protocol',generation:message.generation,message:{kind:'native-action-result',action:message.kind,operation:message.operation,...preparationReply,...levelReply,accepted:true,result}});
   }catch(error){if(levelSourceObservation)levelSourceHarness.refused(levelSourceObservation,error,levelReply);if(partyTrace){partyTrace.accepted=false;partyTrace.error=error.message;}send({kind:'ui-protocol',generation:message.generation,message:{kind:'native-action-result',action:message.kind,operation:message.operation,...preparationReply,...levelReply,accepted:false,text:error.message}});}
  }
  else if(message.kind==='walk')await session.walkTo({...scope,position:message.position,run:false});
  else if(message.kind==='drive'){
   const result=await session.keyboardMove({...scope,actorId:message.actorId,operation:message.operation,position:message.position,heading:message.heading,flags:message.flags,transmit:message.transmit??true});
   send({kind:'drive-ack',connection:message.connection,generation:message.generation,areaId:message.areaId,actorId:message.actorId,lifetime:message.lifetime,requestId:message.requestId,...result});
  }
  else if(message.kind==='interact')await session.interact({...scope,targetId:message.targetId,action:message.action,...(message.position?{position:message.position}:{})});
  else if(message.kind==='pickup')await session.itemAction({...scope,itemId:message.targetId,operation:'pickup'});
  else if(message.kind==='examine')await session.examine({...scope,actorId:session.world.localObjectId,targetId:message.targetId});
  else if(message.kind==='chat'){
   if(scriptFloatingCheck&&message.text==='-native-script-floating'){try{scriptFloatingHarness.arm(session,lobby.connection);}catch{void finish('ScriptFloating admitted source retired before stimulus');return;}}
   if(ordinarySpeechCheck)scriptFloatingHarness.command(message,session,lobby.connection);
   if(actionNpcCombatCheck&&['-native-npc-start','-native-npc-stop'].includes(message.text)){report.npcCombatStimuli??=[];if(report.npcCombatStimuli.length<8)report.npcCombatStimuli.push({at:Date.now(),text:message.text});}
   try{await(await import('./chat-input.mjs')).submitNativeChat(session,scope,message);}
   catch(error){send({kind:'ui-protocol',generation:message.generation,message:{kind:'native-action-result',action:'native-chat',generation:message.generation,areaId:message.areaId,actorId:message.actorId,accepted:false,text:error.message}});}
  }
  else if(message.kind==='reply'){
   if(actionQuickbarCheck){report.quickbarDialogTimeline??=[];if(report.quickbarDialogTimeline.length<64)report.quickbarDialogTimeline.push({at:Date.now(),direction:'client',kind:'reply',entryId:message.entryId,replyId:message.replyId,abort:message.abort});}
   const result=await(await import('./native-dialog-input.mjs')).submitNativeDialogReply(session,{...scope,entryId:message.entryId,replyId:message.replyId,abort:message.abort},value=>send({kind:'ui-protocol',generation:message.generation,message:value}));
   if(actionQuickbarCheck&&report.quickbarDialogTimeline.length<64)report.quickbarDialogTimeline.push({at:Date.now(),direction:'result',kind:'reply',resynchronized:result.resynchronized??false});
   if(result.resynchronized)report.dialogResynchronizations=(report.dialogResynchronizations??0)+1;
  }
  else if(message.kind==='inventory-open'){const view=Object.fromEntries(['ownerId','inventoryRole','windowSerial','inventoryReceipt'].filter(key=>message[key]!==undefined).map(key=>[key,message[key]]));await session.inventoryWindow({...scope,...view,open:true});await session.inventoryPanel({...scope,...view,panel:message.page});}
  else if(message.kind==='inventory-close')await session.inventoryWindow({...scope,...Object.fromEntries(['ownerId','inventoryRole','windowSerial','inventoryReceipt'].filter(key=>message[key]!==undefined).map(key=>[key,message[key]])),open:false});
  else if(message.kind==='inventory-page')await session.inventoryPanel({...scope,...Object.fromEntries(['ownerId','inventoryRole','windowSerial','inventoryReceipt'].filter(key=>message[key]!==undefined).map(key=>[key,message[key]])),panel:message.page});
  else if(message.kind==='inventory-container')await session.containerInput({...scope,actorId:session.world.localObjectId,targetId:message.targetId,operation:message.operation});
  else if(message.kind==='inventory-gold')await session.transferGold({...scope,actorId:message.actorId,targetId:message.targetId,amount:message.amount,position:message.position,placement:message.placement??false,x:message.x??0,y:message.y??0,barterSerial:message.barterSerial});
  else if(message.kind==='item-use')await session.interact({...scope,targetId:message.itemId,action:'object.use'});
  else if(message.kind==='item-action'){if(actionQuickbarCheck){report.quickbarItemTrace??=[];if(report.quickbarItemTrace.length<128)report.quickbarItemTrace.push({at:Date.now(),direction:'client-preflight',kind:message.kind,operation:message.operation,item:quickbarTestItemState(session.world,message.itemId)});}await session.itemAction({...scope,itemId:message.itemId,operation:message.operation,...Object.fromEntries(['slot','x','y','destinationId','amount'].filter(key=>message[key]!==undefined).map(key=>[key,message[key]]))});}
  else throw Error('Unsupported native protocol command');
  if(['inventory-open','inventory-close','inventory-page','inventory-container','item-use','item-action'].includes(message.kind))send({kind:'ui-protocol',generation:message.generation,message:{kind:'inventory-command-result',requestId:message.requestId,inventoryRole:message.inventoryRole??'primary',ownerId:message.ownerId,windowSerial:message.windowSerial,accepted:true}});
 }
 const commandPump=new NativeCommandPump(command,(error,message)=>{if(directHandoffCheck)directHandoffHarness.fail(error.message);if(message.connection!==undefined&&message.connection!==lobby.connection)return;if(actionCheck){report.commandErrors??=[];if(report.commandErrors.length>=32)report.commandErrors.shift();report.commandErrors.push({at:Date.now(),kind:message.kind,operation:message.operation,error:error.message});}if(['inventory-open','inventory-close','inventory-page','inventory-container','inventory-gold','item-use','item-action'].includes(message.kind))send({kind:'ui-protocol',generation:message.generation,message:{kind:'inventory-command-result',requestId:message.requestId,inventoryRole:message.inventoryRole??'primary',ownerId:message.ownerId,windowSerial:message.windowSerial,accepted:false,reason:error.message}});send({kind:'notice',text:error.message});lobby.error=error.message;lobby.emit();});
 const token=crypto.randomBytes(32).toString('hex');temporary=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-native-session-'));
 server=net.createServer(client=>{if(socket){client.destroy();return;}socket=client;report.nativeSocketConnected=true;let buffered='';client.on('data',bytes=>{buffered+=bytes.toString('utf8');if(buffered.length>1024*1024){void finish('Native command exceeds bound');return;}let at;while((at=buffered.indexOf('\n'))>=0){const line=buffered.slice(0,at);buffered=buffered.slice(at+1);try{const message=JSON.parse(line);creationBridge('received',message.kind,Buffer.byteLength(line)+1,{connection:message.connection??null});if(authenticated&&directHandoffCheck&&message.kind==='direct-handoff-progress')directHandoffHarness.command(message,session,message.connection);else commandPump.push(message);}catch{void finish('Invalid native command');}}});
  const socketEvent=(kind,details={})=>{report.nativeSocketEvents??=[];if(report.nativeSocketEvents.length>=16)report.nativeSocketEvents.shift();report.nativeSocketEvents.push({kind,at:Date.now(),ending,read:client.bytesRead,written:client.bytesWritten,...details});if(creationApplyDiagnostic)creationApplyDiagnostic.boundary('socket',kind,{ending,read:client.bytesRead,written:client.bytesWritten,...details});};
  client.on('end',()=>socketEvent('end'));client.on('close',hadError=>{socketEvent('close',{hadError});if(actionWorldRadialCheck&&!ending)void finish('Owned WorldRadial native socket closed before completion');if(actionCombatPresentationCheck&&!combatCheckLifecycle.transportClosed(hadError)&&!ending)void finish('Owned CombatPresentation native socket closed before completion');if(actionAssociateRecordCheck&&!associateRecordLifecycle.transportClosed(hadError)&&!ending)void finish('Owned Associate Record native socket closed before completion');if(actionNpcCombatCheck&&!npcCombatLifecycle.transportClosed(hadError)&&!ending)void finish('Owned NPC combat native socket closed before completion');});client.on('error',error=>{socketEvent('error',{code:error.code});if(actionWorldRadialCheck&&!ending)void finish('Owned WorldRadial native socket failed before completion');if(actionCombatPresentationCheck&&!ending)void finish('Owned CombatPresentation native socket failed before completion');if(actionAssociateRecordCheck&&!ending)void finish('Owned Associate Record native socket failed before completion');if(actionNpcCombatCheck&&!ending)void finish('Owned NPC combat native socket failed before completion');});
 });
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});
 const preworkSources={install,profileDirectory:userDirectory,modsDirectory:startup.settings.modsDirectory,disabledMods:startup.settings.disabledMods??[],cacheDirectory,nativeDirectory:path.join(userDirectory,'nwsync'),helper:path.join(root,'tooling/native/content-reader/nwn-content-reader.exe')};
 const ticket=path.join(temporary,'ticket.json');await fs.writeFile(ticket,JSON.stringify({host:'127.0.0.1',port:server.address().port,token,preworkSources,featureSelection:performanceOptions.requested,localCharacterRoots:[path.join(install,'data/lcv'),path.join(vault.directory,'blobs')]}),{flag:'wx'});
 const runtimeSelection=(await require('./native-performance-runtime.cjs').selectPerformanceRuntime(project,performanceOptions.runtime))??await require('./native-engine-runtime.cjs').selectNativeRuntime(project,engineRuntime,enginePackage);
 report.engineRuntime=runtimeSelection;
 const executable=runtimeSelection.executable,nativeArgs=[...(engineRuntime==='editor'?['--path',project]:[]),'--rendering-method','forward_plus','--rendering-driver','vulkan',...(headless?['--headless','--max-fps','60']:scriptFloatingVisual?['--max-fps','60']:[]),'--log-file',path.join(project,'reports',run+'.engine.log'),...(engineRuntime==='editor'?['--script',directHandoffCheck?'res://tests/native_direct_handoff_world.gd':scriptFloatingVisual?'res://tests/native_ordinary_speech_visual_world.gd':scriptFloatingCheck?'res://tests/native_script_floating_world.gd':'res://native_session_world.gd']:[]),'--',...(engineRuntime==='release'?['--release-entry=res://native_session_world.gd']:[]),'--ticket='+ticket,'--report='+nativeReport,'--profile-control='+path.join(project,'reports',run+'.profile-control.json'),...(creationCheck?['--creation-class='+(arg('creation-class')??'fighter'),'--creation-package='+creationPackage]:[]),...(actionCheck?['--actions-check=true']:[]),...(actionNuiCheck?['--actions-nui-check=true']:[]),...(localCheck&&!directHandoffCheck&&!scriptFloatingOwned?['--settings-check=true']:[]),...((localCheck||actionCheck)?['--render-preferences='+path.join(project,'reports',run+'.settings.cfg'),'--menu-layout='+path.join(project,'reports',run+'.layout.cfg')]:[]),...(nativeProfile?['--profile=true']:[])];
 if(levelSourceCheck)nativeArgs.push('--level-source-check=true','--level-source-case='+levelSourceName);
 if(nativeOverheadClocks)nativeArgs.push('--native-overhead-clocks=true');
 if(scriptFloatingCheck)nativeArgs.push('--script-floating-check=true');
 if(ordinarySpeechCheck)nativeArgs.push('--ordinary-speech-check=true');
 if(scriptFloatingVisual)nativeArgs.push('--script-floating-visual=true','--visual-seconds='+visualMode.seconds);
 if(scriptFloatingOwned)nativeArgs.push('--prepared-cache='+path.join(scriptFloatingDirectory,'client/native-prepared'));
 report.headless=headless;if(creationApplyDiagnostic){nativeArgs.push('--creation-phase-trace=true');report.creationDiagnosticNativePhaseFile=nativeReport+'.phases.jsonl';report.creationDiagnosticNativeRuntimeFile=nativeReport+'.runtime.jsonl';}
 nativeArgs.push(...renderConfiguration.arguments);
 nativeArgs.unshift(...performanceOptions.engineArguments);
 nativeArgs.push(...performanceOptions.nativeArguments);
 nativeArgs.push(...loadingPipeline.arguments);
 report.nativeLoadingArguments=[...loadingPipeline.arguments];
 report.nativeLighting=renderConfiguration.summary.lighting;
 report.nativeLightHistory=renderConfiguration.summary.light_history;
 if(renderConfiguration.summary.maximum_lights!==undefined)report.nativeMaximumLights=renderConfiguration.summary.maximum_lights;
 report.nativeSurfaceOutput=renderConfiguration.summary.surface_output;
 if(renderConfiguration.summary.gamma!==undefined)report.nativeGamma=renderConfiguration.summary.gamma;
 if(menuExitCheck)nativeArgs.push('--menu-exit-check=true');
 if(!headless&&nativeScreen!==undefined)nativeArgs.unshift('--screen',nativeScreen);
 if(localCheck||menuCheck)nativeArgs.push('--lobby-preferences='+path.join(project,'reports',run+'.lobby.cfg'));
 if(localCheck&&!directHandoffCheck)nativeArgs.push('--local-ui-check=true');
 if(directHandoffCheck)nativeArgs.push('--direct-handoff-check=true','--direct-handoff-progress=true');
 if(actionCheck)nativeArgs.push('--preview-check-key='+checkedCharacterKey);
 nativeArgs.push('--preview-directory='+characterPreviewStore.directory);
 if(creationReconnectFrom)nativeArgs.push('--creation-reconnect-report='+report.creationReconnectReference.file,'--creation-reconnect-sha='+report.creationReconnectReference.sha256);
 if(preworkCheckLimit!==undefined)nativeArgs.push('--prework-check-limit='+preworkCheckLimit);
 if(preworkCheckCold)nativeArgs.push('--prepared-cache='+path.join(temporary,'prework-cold'));
 if(recordLoading)nativeArgs.push('--prepared-cache='+path.join(temporary,'prepared'),'--recording=true');
 report.startupScreen=nativeScreen===undefined?null:Number(nativeScreen);
 if(actionEffectsCheck)nativeArgs.push('--actions-effects-check=true');
 if(actionCheck&&report.actionFixture.module==='GodotJournal2'){if(report.actionFixture.journal?.tag!=='native_journal')throw Error('Journal check requires its owned JRL fixture');nativeArgs.push('--actions-journal-check=true');}
 if(actionCheck&&report.actionFixture.module==='GodotMap1'){if(report.actionFixture.map?.tag!=='native_map_note')throw Error('Map check requires its owned note/GUI fixture');nativeArgs.push('--actions-map-check=true');}
 if(actionCorrectionCheck){if(!actionCheck||report.actionFixture.module!=='GodotCorrection')throw Error('Correction check requires its owned local fixture');nativeArgs.push('--actions-correction-check=true');}
 if(actionRadialCheck){if(!actionCheck||report.actionFixture.module!=='GodotActions')throw Error('Radial check requires its owned local fixture');nativeArgs.push('--actions-radial-check=true','--actions-radial-caster='+radialCaster);}
 if(actionWorldRadialCheck){if(!actionCheck||report.actionFixture.module!=='GodotActions')throw Error('WorldRadial requires its owned durable Actions fixture');nativeArgs.push('--actions-world-radial-check=true');}
 if(actionCombatPresentationCheck){if(!actionCheck||report.actionFixture.module!=='GodotActions')throw Error('CombatPresentation requires its owned durable Actions fixture');nativeArgs.push('--actions-combat-presentation-check=true');}
 if(actionNpcCombatCheck){if(!actionCheck||report.actionFixture.module!=='GodotCombatNpc1'||!Number.isInteger(report.actionFixture.npcCombat?.actionConstants?.ACTION_INVALID))throw Error('NPC combat requires its owned script/placement fixture');nativeArgs.push('--actions-npc-combat-check=true','--npc-action-invalid='+report.actionFixture.npcCombat.actionConstants.ACTION_INVALID);}
 if(actionAssociateRecordCheck){if(!actionCheck||report.actionFixture.module!=='AssocRecordGui')throw Error('Associate Record requires its owned target GUI fixture');nativeArgs.push('--actions-associate-record-check=true');}
 if(actionPolymorphCheck){if(!actionCheck||report.actionFixture.module!=='GodotPoly1'||report.actionFixture.form!==44)throw Error('Polymorph check requires its owned local fixture');nativeArgs.push('--actions-polymorph-check=true','--polymorph-test-appearance='+report.actionFixture.appearance);}
 if(actionQuickbarCheck){if(!actionCheck||report.actionFixture.module!=='GodotQuick3'||report.actionFixture.associateProbe?.command!==-19||report.actionFixture.associateProbe?.items?.length!==3||!Number.isInteger(report.actionFixture.associateProbe?.proficiency?.id)||report.actionFixture.associateProbe.items.some(row=>row.position&&row.positionFieldType!==2))throw Error('Quickbar check requires its owned associate event and typed original-item fixture');nativeArgs.push('--actions-quickbar-check=true');}
 if(actionFeatCheck){if(!actionCheck||report.actionFixture.module!=='GodotActions')throw Error('Feat check requires its owned local fixture');nativeArgs.unshift('--max-fps','30');nativeArgs.push('--actions-feat-check=true');report.featFamilyFrameCap=30;}
 if(actionBarterCheck){if(!actionCheck||report.actionFixture.module!==(actionPlayersCheck?'GodotPlayers8':'GodotActions'))throw Error('Two-peer check requires its owned local fixture');nativeArgs.push('--actions-barter-check=true');}
 if(actionPlayersCheck)nativeArgs.push('--actions-players-check=true');
 if(actionLobbyPagesCheck)nativeArgs.push('--lobby-pages-check=true');
 if(actionLocalDeleteCheck)nativeArgs.push('--local-delete-check=true');
 if(actionParticleCrowd)nativeArgs.push('--actions-particle-crowd=true');
 if(actionRangedCheck)nativeArgs.push('--actions-ranged-check=true','--actions-ranged-weapon='+rangedWeapon);
 if(actionParryCheck)nativeArgs.push('--actions-parry-check=true');
 if(actionSpecialAttackCheck)nativeArgs.push('--actions-special-attack-check=true','--actions-special-attack-kind='+specialAttackKind);
 if(actionShieldCheck)nativeArgs.push('--actions-shield-check=true','--actions-shield-kind='+shieldKind);
 if(actionDeflectionCheck)nativeArgs.push('--actions-deflection-check=true');
 if(actionMissCheck)nativeArgs.push('--actions-miss-check=true');
 startupFeatureManifest=featureManifest.createStartupManifest({run,project,runtime:runtimeSelection,options:performanceOptions,renderConfiguration:renderConfiguration.summary,engineAndNativeArguments:nativeArgs});startupFeatureManifest.resolvedPerformancePolicy=performanceOptions.policy;startupFeatureManifest.declaredManagedOptions={...managedClientOptions,scope:'Conservative base declarations plus explicit inputs; resolvedPerformancePolicy/requested records the normal gameplay preset. Neither is proof of active native features. Actual render profile and native observations are recorded separately.'};report.startupFeatureManifest=output.replace(/\.json$/,'.startup.json');await fs.writeFile(report.startupFeatureManifest,JSON.stringify(startupFeatureManifest,null,2)+'\n');
 let launch=executable,launchArgs=nativeArgs;
 if(debuggerCheck){const commands=path.join(project,'reports',run+'.cdb.txt'),trap='.echo NATIVE_SESSION_EXCEPTION;.exr -1;.ecxr;kv;~* k;q';
  const boundedCreationTrace=creationApplyDiagnostic?require('./native-creation-socket-trace.cjs').creationSocketTrace(server.address().port):null;
  if(boundedCreationTrace)report.creationSocketDiagnostic={port:boundedCreationTrace.port,cap:boundedCreationTrace.cap,breakpointIds:boundedCreationTrace.breakpointIds,scope:boundedCreationTrace.scope};
  const socketTrace=boundedCreationTrace?boundedCreationTrace.commands:localCheck&&headless&&process.env.NWN_NATIVE_SOCKET_TRACE==='1'?['bu ws2_32!closesocket ".echo NATIVE_SOCKET_CLOSE;r rcx;k 10;gc"','bu ws2_32!shutdown ".echo NATIVE_SOCKET_SHUTDOWN;r rcx;k 10;gc"']:[];
  report.nativeSocketTrace=socketTrace.length>0;
  await fs.writeFile(commands,[...['av','bpe','0xc0000374','0xc0000409','0xc000001d'].map(value=>`sxe -c "${trap}" ${value}`),...socketTrace,'.echo NATIVE_SESSION_ARMED','g'].join('\n')+'\n',{flag:'wx'});launch='C:/Program Files (x86)/Windows Kits/10/Debuggers/x64/cdb.exe';launchArgs=['-hd','-G','-sins','-y',path.join(project,'.tools'),'-logo',path.join(project,'reports',run+'.cdb.log'),'-cf',commands,executable,...nativeArgs];}
 native=spawn(launch,launchArgs,{cwd:runtimeSelection.directory,windowsHide:true,env:{...process.env,...renderConfiguration.environment},stdio:['ignore','pipe','pipe']});
 native.stdout.on('data',bytes=>{report.nativeOutput=((report.nativeOutput??'')+bytes.toString()).slice(-5000);});native.stderr.on('data',bytes=>{report.engineErrors=((report.engineErrors??'')+bytes.toString()).slice(-12000);if(creationCheck&&/SCRIPT ERROR|Parse Error|^ERROR:/m.test(report.engineErrors))void finish('Owned creation check reported a native engine error');});native.once('error',()=>void finish('Native engine could not start'));native.once('exit',code=>{if(creationApplyDiagnostic)creationApplyDiagnostic.boundary('native','process:exit',{exitCode:code,ending});report.nativeExit=code;void finish(code===0?null:'Native engine exited with failure');});
 const runCreationOwnedHelper=observeOnly=>new Promise(resolve=>{
  const helperOutput=path.join(project,'reports',run+(observeOnly?'.owned-cpu-before.json':'.owned-stack-trigger.json'));
  const helper=spawn('pwsh.exe',['-NoProfile','-File',path.join(project,'tools/break-owned-creation-native.ps1'),'-DebuggerProcessId',String(native.pid),'-NativeExecutable',executable,'-ReportFile',nativeReport,'-Output',helperOutput,...(observeOnly?['-ObserveOnly']:[])],{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']});
  let stdout='',stderr='';const limit=setTimeout(()=>helper.kill(),10000);limit.unref();
  helper.stdout.on('data',bytes=>{stdout=(stdout+bytes).slice(-4096);});helper.stderr.on('data',bytes=>{stderr=(stderr+bytes).slice(-2048);});
  helper.once('error',error=>{clearTimeout(limit);resolve({success:false,error:error.code??'helper-start'});});
  helper.once('exit',code=>{clearTimeout(limit);try{resolve(JSON.parse(stdout));}catch{resolve({success:false,exitCode:code,error:stderr.slice(-512)});}});
 });
 const observeCreationCpu=()=>{
  if(!creationApplyDiagnostic||creationCpuWork||!native||native.exitCode!==null)return;
  creationCpuWork=runCreationOwnedHelper(true).then(value=>{report.creationCpuBefore=value;});
 };
 const takeCreationStack=()=>{
  if(!creationApplyDiagnostic||creationStackWork||!native||native.exitCode!==null)return;
  creationApplyDiagnostic.armStack();
  creationStackWork=(async()=>{
   report.creationOwnedStack=await runCreationOwnedHelper(false);
   if(creationCpuWork)await creationCpuWork;
   report.creationCpuDelta=require('./native-creation-apply-diagnostic.cjs').cpuDelta(report.creationCpuBefore,report.creationOwnedStack);
  })();
 };
 timer=setInterval(()=>{
  try{if(ending||!authenticated)return;
   directHandoffHarness?.tick();
   if(creationApplyDiagnostic?.shouldStack()){takeCreationStack();return;}
   if(localCheck&&localCycleEnding&&!session&&!lobby.busy&&!lobby.joinWork&&!localJoinPending&&(report.localCycles?.length??0)<localCycles&&Date.now()-localDisconnectedAt>2000){
    localJoinPending=true;void lobby.join({connection:lobby.connection,details:{host:'127.0.0.1',port:localPort,name:'GodotNativeLocalTest',credentials:{password:''}}}).catch(error=>finish(error.message)).finally(()=>{localJoinPending=false;});return;
   }
   if(!session||session.closed)return;
   if(scriptFloatingOwned&&session.phase==='character-rejected'){void finish('Original local server rejected the unchanged installed Wizard');return;}
   if(actionCheck&&session.phase==='character-rejected'){void finish('Original local server rejected the owned test character');return;}
   if(creationCheck&&session.phase==='character-rejected'){void finish('Original local server rejected the native first-level character: '+String(lobby.snapshot().error??''));return;}
   if(localWalkOrigin&&localWalkGeneration===session.areaGeneration){const p=session.world.registry.get(session.world.localObjectId)?.replicated?.position;if(p)authoritativeDistance=Math.max(authoritativeDistance,Math.hypot(...p.map((value,index)=>value-localWalkOrigin[index])));}
   if(localCheck&&!directHandoffCheck&&!localPlaying&&!localWork&&lobby.snapshot().canSelect&&(!creationCheck||catalogReady)&&(headlessPlayersCheck||creationCheck||report.nativeChooserReady?.success&&report.nativeChooserReady.connection===lobby.connection)&&(!actionLobbyPagesCheck||report.lobbyPages?.success)&&(!actionLocalDeleteCheck||report.localDelete?.success)){
    localPlaying=true;
    if(creationCheck)send({kind:'probe-native-creation'});
    else localWork=(async()=>{
     const connection=lobby.connection,key=checkedCharacterKey;if(lobby.selected!==key||!lobby.preview?.sha256)await lobby.choose({connection,key});
     if(actionCheck&&!headlessPlayersCheck){
      const sha256=lobby.preview?.sha256,scope={connection,key,sha256},deadline=Date.now()+45000;
      const ready=()=>report.characterPreviewProof?.success&&lobby.connection===connection&&lobby.selected===key&&lobby.preview?.sha256===sha256&&previewProofMatches(report.characterPreviewProof,scope,report.characterPreviewExpected);
      while(!ending&&!ready()&&Date.now()<deadline)await new Promise(resolve=>setTimeout(resolve,25));
      if(ending)return;if(!ready())throw Error('Current native character preview did not become ready');
     }
     await lobby.play({connection,key});
    })().catch(error=>finish(error.message));
   }
   nativeClockBridge.flush(session,lobby.connection);
   if(session.resourceResult?.ready&&setupSession!==session){send({kind:'setup',interactive:directHandoffCheck||!localCheck||recordLoading||scriptFloatingVisual,install,moduleName:session.serverInfo?.moduleName??'Multiplayer',serverLabel:`${lobby.endpoint.host}:${lobby.endpoint.port}`,resourceSources:sourceDescriptor(session)});setupSession=session;}
   if(!catalogReady)return;const area=session.world.registry.get(session.world.areaId)?.state;if(!area?.tiles)return;
   if(rawPending)return;
   const serial=++rawSerial,generation=session.areaGeneration,data={area,objects:[...session.world.registry.objects.values()].map(object=>session.world.entityDisclosures.transportRow(object,{...rawCombat.object(object),nativeActorNameState:session.world.nativeActorNameTransport(object),nativeClockOwner:session.world.nativeClockOwnerTransport(object)})),controlledId:session.world.localObjectId,actorNameHistory:session.world.nativeActorNameHistory(),entry:session.world.entry,time:session.world.time,module:session.world.module,inventory:{inventories:[...session.world.inventories],containers:[...session.world.containers],store:session.world.store,windows:session.world.inventoryWindows.snapshot()},ui:{...playerRosterHeader(session.world),guiPanelAccess:guiPanelHeaderForHost(session.world,generation),scriptTargeting:session.world.scriptTargeting,scriptTargetingData:session.world.scriptTargetingData,party:session.world.party,quickbar:session.world.quickbar,journal:{entries:[...session.world.journal.entries],worldEntries:[...session.world.journal.worldEntries],loaded:session.world.journal.loaded},barter:session.world.barter,mapPins:[...session.world.mapPins]}};
   data.ui.partyInviteNotice=session.world.partyInviteNotice;
   data.ui.playerAttitudes=[...session.world.playerAttitudes];
   data.ui.partyListRevision=session.world.partyListRevision;
   const changed=worldDeltas.plan({serial,generation,data,connection:lobby.connection});
   if(!changed)return;
   report.rawWorldUpdates??={full:0,delta:0,objects:0,removed:0};report.rawWorldUpdates[changed.bridgeMode]++;report.rawWorldUpdates.objects+=changed.objects.length;report.rawWorldUpdates.removed+=changed.removedObjectIds.length;
   let frames=worldRadialCapture&&!worldRadialCapture.work?[...rawWorldFrames({serial,generation,data:changed,connection:lobby.connection})]:rawWorldFrames({serial,generation,data:changed,connection:lobby.connection});
   if(worldRadialCapture&&!worldRadialCapture.work)void worldRadialCapture.captureFrames(frames).catch(()=>finish('Owned first native snapshot capture failed'));
   if(creationApplyDiagnostic&&!creationApplyDiagnostic.snapshot){frames=[...frames];creationApplyDiagnostic.rawFrames(frames,{connection:lobby.connection,generation,serial,areaId:session.world.areaId});observeCreationCpu();}
   if(directHandoffCheck)directRawWire={rawFrameConnection:lobby.connection,rawFrameGeneration:generation,rawFrameSerial:serial,rawFrameHeaderCount:0,rawFrameChunkCount:0,rawFrameEndCount:0,rawFrameTotalBytes:0,rawFrameNewlinePresent:true};
   for(const frame of frames){socket.write(frame);if(directHandoffCheck){const kind=/^\{"kind":"raw-world-(begin|chunk|end)"/.exec(frame.slice(0,48))?.[1];if(kind==='begin')directRawWire.rawFrameHeaderCount++;else if(kind==='chunk')directRawWire.rawFrameChunkCount++;else if(kind==='end')directRawWire.rawFrameEndCount++;directRawWire.rawFrameTotalBytes+=Buffer.byteLength(frame);directRawWire.rawFrameNewlinePresent=directRawWire.rawFrameNewlinePresent&&frame.endsWith('\n');}if(loadingRecording)loadingRecording.frame(JSON.parse(frame),frame);}
   rawPending={serial,generation};snapshotGeneration=generation;
   if(actionQuickbarCheck&&quickbarInventoryRevision>0){rawPending.inventoryRevision=quickbarInventoryRevision;report.quickbarInventoryTimings??=[];if(report.quickbarInventoryTimings.length<128)report.quickbarInventoryTimings.push({phase:'raw-world-send',at:Date.now(),serial,revision:quickbarInventoryRevision,rows:[...session.world.inventories].filter(([channel])=>['r','i'].includes(channel)).map(([channel,view])=>({channel,ids:view.entries.map(row=>row.id)}))});}
  }catch(error){send({kind:'failure',reason:error.message});void finish(error.message);}
 },200);
 console.log('DIRECT NATIVE GODOT · protocol-only host · no automatic server connection');
 report.bootStage='native-launched';clearInterval(startupStatus);
 if(menuCheck){const deadline=setTimeout(()=>void finish('Native menu check timed out'),preworkCheckLimit===undefined?20000:240000);deadline.unref();}
 if(localCheck){const deadline=setTimeout(()=>void finish('Native localhost check timed out'),(directHandoffCheck||actionCheck||creationCheck||levelSourceCheck||scriptFloatingOwned?360000:120000)*localCycles);deadline.unref();}
})().catch(error=>void finish(error.message));
