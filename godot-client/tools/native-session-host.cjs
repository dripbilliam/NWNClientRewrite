// Protocol and protected-login owner only. No BrowserWindow or render staging.
const fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os'),net=require('node:net'),crypto=require('node:crypto'),{spawn}=require('node:child_process'),{registerHooks}=require('node:module'),{fileURLToPath}=require('node:url');
const project=path.resolve(__dirname,'..'),root=path.dirname(project),loaded=new Set();
const {previewProofMatches}=require('./native-character-preview-proof.cjs');
registerHooks({resolve(specifier,context,next){const value=next(specifier,context);if(specifier==='three'||specifier.startsWith('three/')||/\/(?:character_creation|character_creation_assets|model_parser|model_hierarchy|prepared_model_geometry|network_scene|native_ui_assets|native_rich_text|network_text|nui_skin|inventory_layout|item_icon|main|model_particles|particle_[^/]+|fountain_emitter|fountain_particle_providers|burst_single_emitter|lightning_emitter|emitter_target|model_reference_assets|model_reference_scene|model_references)\.js$/.test(value.url)||/\/(?:export-room|export-rigs|export-particles|particle-simulation|particle-workers|particle-worker|staging-area|staging-content|creation-service|gameplay-text|nui-service|inventory-service)\./.test(value.url))throw Error('Rendering dependency forbidden in native session owner: '+specifier);if(value.url.startsWith('file:'))loaded.add(fileURLToPath(value.url));return value;}});
const arg=name=>process.argv.find(v=>v.startsWith('--'+name+'='))?.slice(name.length+3);
const menuCheck=process.argv.includes('--menu-check'),headless=process.argv.includes('--native-headless');
const preworkCheckLimit=arg('prework-check-limit');
if(preworkCheckLimit!==undefined&&(!menuCheck||!/^[1-9][0-9]{0,3}$/.test(preworkCheckLimit)))throw Error('Prework corpus checks require an isolated menu check and a bounded model count');
const preworkCheckCold=process.argv.includes('--prework-check-cold');if(preworkCheckCold&&preworkCheckLimit===undefined)throw Error('Cold prework requires an isolated corpus check');
const nativeScreen=arg('native-screen');if(nativeScreen!==undefined&&!/^(0|[1-9][0-9]*)$/.test(nativeScreen))throw Error('Invalid native display index');
const actionNuiCheck=process.argv.includes('--action-nui-check');
const actionCorrectionCheck=process.argv.includes('--action-correction-check');
const actionRadialCheck=process.argv.includes('--action-radial-check');
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
const creationCheck=process.argv.includes('--creation-check');
const actionCheck=process.argv.includes('--action-check'),localPort=actionCheck?5125:5121;
if(actionLobbyPagesCheck&&(!actionCheck||headless||actionBarterCheck))throw Error('Lobby page checks require the isolated graphical local action fixture');
if(actionShieldCheck&&(!actionCheck||!actionRangedCheck||rangedWeapon!=='bow'||actionDeflectionCheck||actionMissCheck))throw Error('Shield requires one isolated bow check');
if(actionParryCheck&&(!actionCheck||actionRangedCheck||actionEffectsCheck||actionNuiCheck))throw Error('Parry requires one isolated melee check');
if(actionSpecialAttackCheck&&(!actionCheck||actionRangedCheck||actionEffectsCheck||actionNuiCheck||actionParryCheck))throw Error('Special attacks require isolated melee checks');
const localCheck=creationCheck||actionCheck||process.argv.includes('--local-check');if(localCheck&&process.argv.includes('--public-servers'))throw Error('Local check forbids public endpoints');
if(actionLocalVaultCheck&&(!actionCheck||actionSpecialAttackCheck||actionParryCheck||actionRangedCheck||actionFeatCheck||actionNuiCheck||actionEffectsCheck||actionBarterCheck))throw Error('Local vault checks require the isolated standard action fixture');
if(actionLocalDeleteCheck&&(!actionLocalVaultCheck||headless||actionLobbyPagesCheck))throw Error('Local Delete requires the graphical isolated local-vault fixture');
const checkedCharacterKey=actionLocalVaultCheck?'local:nwn_local_ui.bic':actionSpecialAttackCheck?'installed:monk.bic':actionParryCheck?'installed:fighter.bic':actionRangedCheck?'installed:ranger.bic':actionFeatCheck?'installed:druid.bic':'installed:wizard.bic';
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
let session,lobby,browser,server,socket,native,temporary,timer,ending=false,authenticated=false,setupSession=null,snapshotGeneration=-1;
let catalogReady=false;
let settingsBroker,loginProfiles;
let localPlaying=false,localWork=null,localWalk=false,localWalkAt=0,localWalkProof=null;
let localWalkOrigin=null,localWalkGeneration=-1,authoritativeDistance=0;
let rawSerial=0,rawPending=null;
let localCycleEnding=false,localJoinPending=false,localDisconnectedAt=0,staleProbeConnection=-1,lastRetiredConnection=-1;
const {rawWorldFrames}=require('./raw-world-frames.cjs');
const worldDeltas=new (require('./raw-world-deltas.cjs').RawWorldDeltas)();
const rawCombat=new (require('./raw-combat-events.cjs').RawCombatEvents)();
const rawVoice=new (require('./raw-voice-events.cjs').RawVoiceEvents)(rawCombat);
const rawScriptSounds=new (require('./raw-script-sounds.cjs').RawScriptSounds)(rawCombat);
const rawVisual=new (require('./raw-visual-events.cjs').RawVisualEvents)(rawCombat);
const report={success:false,protocolOnly:true,renderingPrepared:false,publicConnections:0,states:[],areas:[],diagnostics:[],scope:'Direct native world entry; gameplay/effects/UI migration incomplete'};
let characterPreviewStore;
let localCharacterRoots=[];
report.requestedLocalCycles=localCycles;
report.localStreamAbortRequested=localStreamAbort;
const send=value=>{if(value.kind==='lobby'){
 const state=value.state;value.localCharacterRoots=localCharacterRoots;
 report.lobbyStates??=[];
 if(report.lobbyStates.length<256)report.lobbyStates.push({connection:value.connection,phase:state.phase,busy:state.busy,error:state.error,canSelect:state.canSelect,connected:state.connected,at:Date.now()});
 }if(socket&&!socket.destroyed){const scoped={connection:lobby?.connection??0,...value};if(recordLoading&&scoped.kind==='setup')scoped.recordingDirectory=path.join(recordingDirectory,'catalog-'+(++recordingCatalog));const text=JSON.stringify(scoped,(_key,v)=>typeof v==='bigint'?{native64:String(v)}:v)+'\n';socket.write(text);loadingRecording?.frame(scoped,text);}};
const rejectRetired=message=>{if(report.retiredCommands===undefined)report.retiredCommands=[];if(report.retiredCommands.length<64)report.retiredCommands.push({kind:message.kind,connection:message.connection,current:lobby.connection});};
const ownsConnection=message=>session&&!session.closed&&Number.isSafeInteger(message.connection)&&message.connection===lobby.connection;
const movementKeys=['position','orientation','animation','path','walkRate','runRate','field8F4','field8EC','actionFlag'];let revision=0;
async function finish(reason){
 if(ending)return;ending=true;hostDelay.disable();clearInterval(timer);if(reason)report.failure=reason;
 try{cancellationSink?.close();}catch{}
 await browser?.retire().catch(()=>{});
 await loginProfiles?.retire();
 if(lobbyParticipant){report.lobbyParticipant={...lobbyParticipant.snapshot(),metadata:lobbyParticipant.metadata};await lobbyParticipant.close().catch(()=>{});}
 lobbyParticipantAbort?.abort();await lobbyParticipantWork?.catch(()=>{});
 if(native&&native.exitCode===null){send({kind:'finish'});await new Promise(resolve=>{const timeout=setTimeout(resolve,5000);native.once('exit',()=>{clearTimeout(timeout);resolve();});});if(native.exitCode===null){report.forcedNativeStop=true;native.kill();}}
 if(barterPeer){report.barterPeer={...barterPeer.snapshot(),metadata:barterPeer.metadata};await barterPeer.close().catch(()=>{});}
 barterPeerAbort?.abort();await barterPeerWork?.catch(()=>{});
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
  const value=JSON.parse(await fs.readFile(nativeReport,'utf8'));report.native={success:value.success,workersRemaining:value.workers_remaining,world:value.world,nativeCatalog:value.native_catalog,gameplayUi:value.gameplay_ui};
  if(actionCheck&&(!report.actions?.success||!report.exportedCharacter||!creationCheck&&!report.characterPreviewProof?.success))report.success=false;
  if(actionLobbyPagesCheck&&!report.lobbyPages?.success)report.success=false;
  if(actionLocalDeleteCheck&&!report.localDelete?.success)report.success=false;
  if(creationCheck&&(!report.creationProof?.success||!report.nativeCreation?.nativeGenerated||!report.exportedCharacter?.classes?.some(row=>row.level===1)))report.success=false;
  if(creationCheck&&report.creationProof?.expected){const e=report.creationProof.expected,c=report.exportedCharacter;if(!c?.classes.some(row=>row.id===e.classId&&row.level===1)||!e.known.every(id=>c.known[e.classId]?.includes(id))||!e.feats.every(id=>c.feats.includes(id)))report.success=false;}
  if(localCheck&&!recordLoading&&(!value.success||value.workers_remaining!==0||!value.protocol_finish_ack||!(report.localWalkDistance>0.2)||!(report.authoritativeDistance>0.2&&report.authoritativeDistance<2)))report.success=false;
  if(localCheck&&recordLoading&&(!value.playable||!value.object_visuals_complete||value.workers_remaining!==0||!value.protocol_finish_ack||!report.loadingRecording?.complete||!report.loadingCheck))report.success=false;
  if(localCancelCheck&&(!report.cancelCheck?.peerClosed||report.cancelCheck.elapsedMs>1000||value.session_cancel_probes!==1))report.success=false;
  const expectedRetirements=localCycles-1+(localStreamAbort?1:0);
  if(localCheck&&!recordLoading&&((report.localCycles?.length??0)!==localCycles||localStreamAbort&&(report.localAbortedCycles?.length??0)!==1||localCycles>1&&((value.stale_input_probes??0)!==expectedRetirements||(value.stale_session_messages??0)<4*expectedRetirements||(report.retiredCommands??[]).filter(row=>row.kind==='walk').length!==expectedRetirements)))report.success=false;
 }catch{report.success=false;report.failure??='Native result is unavailable';}
 if(/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m.test(report.engineErrors??'')){report.success=false;report.failure??='Native engine or lifetime errors';}
 if(debuggerCheck){const debug=await fs.readFile(path.join(project,'reports',run+'.cdb.log'),'utf8').catch(()=>'');report.debuggerArmed=/^NATIVE_SESSION_ARMED\r?$/m.test(debug);report.nativeException=/^NATIVE_SESSION_EXCEPTION\r?$/m.test(debug);if(!report.debuggerArmed||report.nativeException){report.success=false;report.failure??='Native debugger evidence failed';}}
 report.sourceUnchanged=true;for(const[file,digest]of Object.entries(report.sourceSha256??{}))if(crypto.createHash('sha256').update(await fs.readFile(path.join(project,file))).digest('hex')!==digest)report.sourceUnchanged=false;
 if(!report.sourceUnchanged){report.success=false;report.failure??='Native sources changed during the check';}
 if(characterPreviewStore&&(!characterPreviewStore.closed||characterPreviewStore.files.size||report.characterPreviewCleanupFailed))report.success=false;
 report.loadedProtocolModules=[...loaded].filter(file=>file.startsWith(root+path.sep)).map(file=>path.relative(root,file).replaceAll('\\','/')).sort();
 await fs.writeFile(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:report.success,failure:report.failure,report:output}));process.exit(report.success?0:1);
}
(async()=>{
 const chunks=[];let inputBytes=0;for await(const chunk of process.stdin){inputBytes+=chunk.length;if(inputBytes>65536)throw Error('Private native startup request exceeds bound');chunks.push(chunk);}
 let startup;try{startup=JSON.parse(Buffer.concat(chunks).toString('utf8'));}finally{for(const chunk of chunks)chunk.fill(0);}
 let savedKey=startup.cdKey??'';delete startup.cdKey;
 let barterPeerKey=startup.barterPeerCdKey??'';delete startup.barterPeerCdKey;
 if(barterPeerKey&&(!actionCheck||!actionBarterCheck&&!actionLobbyPagesCheck))throw Error('Participant credentials require an owned two-participant test');
 if(recordLoading){const parent=localCheck?os.tmpdir():path.join(startup.settingsDirectory,'native-loading-recordings');await fs.mkdir(parent,{recursive:true});recordingDirectory=await fs.mkdtemp(path.join(parent,localCheck?'nwn-native-loading-recording-':'capture-'));const {NativeLoadingRecording}=await import('./native-loading-recording.mjs');loadingRecording=new NativeLoadingRecording(recordingDirectory);report.recordingDirectory=recordingDirectory;console.log('NATIVE LOADING RECORDING: '+recordingDirectory);}
 if(actionCheck){const {actionsHome}=await import('./native-actions-fixture.mjs');startup.userDirectory=path.join(actionsHome,'client');startup.settingsDirectory=path.join(actionsHome,'client');startup.settings={...startup.settings,modsDirectory:path.join(actionsHome,'client/workshop'),disabledMods:[]};report.actionFixture=JSON.parse(await fs.readFile(path.join(actionsHome,'fixture.json')));}
 settingsBroker=require('./settings-client.cjs').createSettingsClient({initial:startup.settings,onStatus:value=>{startup.settings=value;},fallbackKey:()=>savedKey});
 const settings=require('./settings-client.cjs').credentialSettings(settingsBroker,()=>startup.settings,()=>savedKey,{fixedResources:actionCheck});
 report.bootStage='loading-protocol-modules';const startupStatus=setInterval(()=>{void fs.writeFile(output.replace(/\.json$/,'.startup.json'),JSON.stringify({bootStage:report.bootStage,loaded:[...loaded].map(file=>path.relative(root,file))}));},2000);startupStatus.unref();
 for(const file of [output,nativeReport]){try{await fs.access(file);throw Error('Native report already exists');}catch(error){if(error.code!=='ENOENT')throw error;}}
 const {NativeCharacterPreviewStore}=await import('./native-character-preview-store.mjs');characterPreviewStore=await new NativeCharacterPreviewStore(path.join(root,'runtime-logs/native-character-previews',run)).open();
 const {NativeCommandPump}=await import('./native-command-pump.mjs');
 const {NativeLobby}=await import('./native-lobby.mjs'),{ServerBrowserService}=await import('./server-browser-service.mjs'),{ServerBrowserStore}=await import('./server-browser-store.mjs'),{ServerEndpointPolicy,parseAllowedServer}=await import('./server-endpoint.mjs'),{queryNetworkServer,fetchNetworkServerList}=await import('../../electron/server_browser.mjs'),{createInstalledNetworkSession}=await import('../../electron/installed_network_session.mjs');
 const {NetworkCharacterVault}=await import('../../electron/network_character_vault.mjs');
 report.bootStage='reading-protected-settings';
 const sourceFiles=['native_live_world.gd','native_session_world.gd','tools/native-session-host.cjs','tools/native-session-bootstrap.cjs','tools/raw-world-frames.cjs','tools/raw-world-deltas.cjs','tools/raw-combat-events.cjs','systems/native_level_up.gd','systems/native_game_desktop.gd','systems/native_ui_art.gd','systems/native_render_settings.gd','systems/native_main_menu.gd','systems/draggable_panel.gd','systems/native_gameplay_ui.gd','systems/native_inventory.gd','systems/bridge_frames.gd','systems/model_rigs.gd','systems/model_reference_state.gd','systems/particle_surface.gd','systems/entity_registry.gd','systems/native_interaction_policy.gd','systems/native_hud.gd','systems/world_input.gd'];
 sourceFiles.push('project.godot','tools/native-window-screen.ps1','tools/settings-broker.cjs','tools/settings-client.cjs','tools/login-profile-service.mjs','../electron/client_settings.mjs');
 sourceFiles.push('tools/native-dialog-input.mjs','tools/native-correction-fixture.mjs');
 sourceFiles.push('tools/native-loading-recording.mjs','tools/native-loading-writer.mjs');
 for(const file of ['tools/raw-visual-events.cjs','tools/native-effects-fixture.mjs','tools/native-particle-crowd-fixture.mjs','tools/native-ranged-fixture.mjs','tools/native-parry-fixture.mjs','tools/native-special-attack-fixture.mjs','systems/native_keyboard.gd','systems/native_item_icons.gd','systems/native_ui_skin.gd','systems/camera_controller.gd','systems/area_environment.gd'])if(!sourceFiles.includes(file))sourceFiles.push(file);
 for(const file of await fs.readdir(path.join(project,'systems')))if(file.endsWith('.gd')&&!sourceFiles.includes('systems/'+file))sourceFiles.push('systems/'+file);
 sourceFiles.push('tools/native-lobby-participant.mjs','tools/native-command-pump.mjs','tools/native-lobby.mjs','tools/native-character-preview-store.mjs','systems/native_character_preview.gd','tools/server-browser-service.mjs','../electron/network_abort.mjs','../electron/network_peer.mjs','../electron/installed_network_session.mjs','../electron/server_browser.mjs','tools/skill-input.mjs','tools/native-actions-fixture.mjs','tests/native_live_actions_probe.gd','systems/native_data/feedback_descriptors.json','../electron/network_game_session.mjs');
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
 sourceFiles.push('tools/native-players-fixture.mjs','tools/test-native-actions.ps1','../src/network_hud_input.js');
 if(actionBarterCheck)sourceFiles.push('tools/native-barter-peer.mjs');
 for(const directory of ['native_data','native_render'])for(const file of await fs.readdir(path.join(project,'systems',directory)))if(file.endsWith('.gd'))sourceFiles.push('systems/'+directory+'/'+file);
 sourceFiles.push('systems/character_lobby.gd','systems/native_character_lobby.gd');
 report.compiledParticlesRequested=process.env.NWN_PARTICLE_KERNEL!=='gd';
 if(report.compiledParticlesRequested)sourceFiles.push('native/particle_kernel.cpp','native/particle_simulation.hpp','native/particle_kernel.gdextension','tools/build-particle-kernel.ps1','tools/ensure-particle-kernel.ps1','join-native.ps1','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json');
 if(report.compiledParticlesRequested)for(const file of await fs.readdir(path.join(project,'native')))if(file.endsWith('.hpp')&&!sourceFiles.includes('native/'+file))sourceFiles.push('native/'+file);
 report.sourceSha256={};for(const file of sourceFiles)report.sourceSha256[file]=crypto.createHash('sha256').update(await fs.readFile(path.join(project,file))).digest('hex');
 const install=path.resolve(root,'../FullDecomp/NwnRootInstall'),userDirectory=startup.userDirectory;
 const cacheDirectory=path.join(userDirectory,'replacement-client/server-content'),policy=new ServerEndpointPolicy({allowed:actionCheck?[{host:'127.0.0.1',port:5125}]:[],allowAny:!menuCheck&&process.argv.includes('--public-servers'),internet:!menuCheck&&process.argv.includes('--public-servers')});
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
  return{install,archives,nwsync,customTlk:tlk?{name:tlk.name,path:typeof tlk.resource==='string'?tlk.resource:null}:null,profileDirectory:userDirectory,modsDirectory:startup.settings.modsDirectory,disabledMods:startup.settings.disabledMods};
 };
 const attach=(current,connection)=>{
  current.characterPreviewEncoder=bytes=>characterPreviewStore.encode(bytes);
  session=current;setupSession=null;catalogReady=false;snapshotGeneration=-1;rawPending=null;worldDeltas.reset();send({kind:'session-reset'});
  if(localCheck){localPlaying=false;localWork=null;localWalk=false;localWalkAt=0;localWalkProof=null;localWalkOrigin=null;localWalkGeneration=-1;authoritativeDistance=0;localCycleEnding=false;report.firstPlayable=null;report.movementWhileStreaming=null;report.nativeChooserReady=null;report.characterPreviewProof=null;}
  if(actionLobbyPagesCheck){
   report.lobbyPageWire={sent:[],received:[]};const originalSend=current.peer.sendGameMessage.bind(current.peer);
   current.peer.sendGameMessage=async(bytes,...options)=>{if(bytes[0]===112&&bytes[1]===49&&[1,2].includes(bytes[2]))report.lobbyPageWire.sent.push([...bytes]);return originalSend(bytes,...options);};
  }
  current.on('state',state=>{if(current!==session)return;if(['playing','area-loading'].includes(state.phase))lobby.creating=false;report.states.push({connection,phase:state.phase});});
  current.on('message',({message,areaGeneration})=>{
   if(actionLobbyPagesCheck&&message.kind==='server-character-player'&&current===session&&connection===lobby.connection)report.lobbyPageWire.received.push({present:message.present,id:message.character.id,classes:message.character.classes??[]});
   if(actionBarterCheck&&(message.kind.startsWith('barter-')||message.kind==='object-updates'&&message.records.some(row=>row.action==='inventory'))){
    report.barterTrace??=[];if(report.barterTrace.length>=160)report.barterTrace.shift();
    report.barterTrace.push({kind:message.kind,...(message.kind==='object-updates'?{records:message.records.filter(row=>row.action==='inventory').map(({channel,operation,id,x,y,slot})=>({channel,operation,id,x,y,slot}))}:{message}),actorId:current.world.localObjectId,open:current.world.barter?.open,repositories:Object.fromEntries(['R','I','A','B'].map(channel=>[channel,(current.world.inventories.get(channel)?.entries??[]).map(row=>({id:row.id,channel:current.world.registry.get(row.id)?.inventoryLocation?.channel,ownerId:current.world.registry.get(row.id)?.inventoryLocation?.ownerId}))]))});
   }
   if(actionCheck){report.actionEventCounts??={};report.actionEventCounts[message.kind]=(report.actionEventCounts[message.kind]??0)+1;if(['spell-feedback','combat-feedback','server-speech','safe-projectile'].includes(message.kind)){report.actionProtocol??=[];if(report.actionProtocol.length>=128)report.actionProtocol.shift();report.actionProtocol.push(structuredClone(message));}}
   if(current!==session||connection!==lobby.connection||ending)return;
   if(message.kind==='voice-play'){const frame=rawVoice.frame(current.world,message,areaGeneration,connection);if(frame)send(frame);}
   if(message.kind==='script-sound'){const frame=rawScriptSounds.frame(current.world,message,areaGeneration,connection);if(frame)send(frame);}
   if(['object-updates','object-visual','area-visual','safe-projectile'].includes(message.kind)){const frame=rawVisual.frame(current.world,areaGeneration,connection,message);if(frame){send(frame);report.rawVisualEvents=(report.rawVisualEvents??0)+frame.events.length;}}
   if(message.kind.startsWith('nui-'))send({kind:'ui-protocol',generation:areaGeneration,message:{...message,...(message.kind==='nui-create'?{nativeSerial:current.world.nui.windows.get(message.token)?.serial}:{})}});
   if(message.kind.startsWith('barter-'))send({kind:'ui-protocol',generation:areaGeneration,message:{...message,nativeBarterSerial:current.world.barter?.serial??0,nativeBarterRevision:current.world.barter?.revision??0}});
   else if(['combat-feedback','spell-feedback','damage-feedback','attack-feedback','initiative-feedback','server-speech','dialog-entry','dialog-replies','dialog-selected','dialog-close','examine','custom-token','tlk-overrides','inventory-result','inventory-ack','level-up-classes','level-up-available','level-up-result','store-open','store-close','store-transaction'].includes(message.kind))send({kind:'ui-protocol',generation:areaGeneration,message});
   if(message.kind==='object-updates'){const frame=rawCombat.frame(current.world,areaGeneration,connection);if(frame){send(frame);report.rawCombatEvents=(report.rawCombatEvents??0)+frame.events.length;}}
   if(snapshotGeneration!==areaGeneration||message.kind!=='object-updates')return;
   const records=[];for(const event of current.world.presentationChanges){if(event.action!=='movement')continue;const object=current.world.registry.get(event.id);if(!object||object.objectType!==5||object.areaId!==current.world.areaId||object.replicationRemoved)continue;records.push({id:event.id,revision:++revision,created:Boolean(event.created),changes:structuredClone(event.changes),initial:Object.fromEntries(movementKeys.filter(key=>object.replicated[key]!==undefined).map(key=>[key,structuredClone(object.replicated[key])]))});}
   if(actionCorrectionCheck)for(const record of records){if(record.id!==current.world.localObjectId||!record.changes.position)continue;report.correctionWirePositions??=[];if(report.correctionWirePositions.length>=16)report.correctionWirePositions.shift();report.correctionWirePositions.push({revision:record.revision,position:record.changes.position});}
   if(records.length)send({kind:'movement',areaId:current.world.areaId,generation:areaGeneration,records});
  });
  // Handoffs need a scoped native catalog/session replacement before exposure.
  // Preserve the protocol's transfer failure rather than joining silently.
  current.portalTransfer.prepare=()=>{throw Error('Direct native server transfer integration is still pending');};
 };
 lobby=new NativeLobby({listLocal:async()=>{localCatalog.clear();const status=await settings.status(),{discoverLocalCharacterFiles}=await import('./native-local-character-discovery.mjs');const discovered=await discoverLocalCharacterFiles({install,profileDirectory:userDirectory,modsDirectory:status.modsDirectory,disabledMods:status.disabledMods}),rows=discovered.rows;localCharacterRoots=[...discovered.roots,path.join(vault.directory,'blobs')];if(!localCheck)for(const entry of await vault.list())rows.push({key:'vault:'+entry.id,label:entry.name+' (saved)',source:'vault',vaultId:entry.id,file:path.join(vault.directory,'blobs',entry.sha256+'.bic'),catalogStem:entry.id});const {localCharacterFile}=await import('./native-local-character-files.mjs');for(const row of rows){row.nativeFile=await localCharacterFile(row.file);if(row.storageSource)row.nativeFile.storageSource=row.storageSource;localCatalog.set(row.key,row);}report.localDiscovery={rows:rows.length,roots:localCharacterRoots.length,profile:rows.filter(row=>row.source==='local').length,workshop:rows.filter(row=>row.source==='workshop').length};return rows;},readLocal:async key=>{const row=localCatalog.get(key);if(!row)throw Error('Unknown local character');if(actionCheck){const input=await fs.readFile(row.file),fixture=await(await import('./native-actions-fixture.mjs')).actionTestCharacter(input,{rangedWeapon});report.actionCharacter=fixture.metadata;
  const {parseGff}=await import('../../src/gff.js'),c=parseGff(fixture.bytes,'BIC ').root;
  report.characterPreviewExpected={sha256:fixture.metadata.uploadedSha256,abilities:Object.fromEntries(['Str','Dex','Con','Int','Wis','Cha'].filter(k=>Number.isInteger(c[k])).map(k=>[k,c[k]])),classes:c.ClassList.filter(v=>Number.isInteger(v.Class)&&Number.isInteger(v.ClassLevel)).map(v=>({id:v.Class,level:v.ClassLevel})),skill_count:(c.SkillList??[]).filter(v=>Number.isInteger(v.Rank)).length,feat_count:(c.FeatList??[]).filter(v=>Number.isInteger(v.Feat)).length,spell_count:c.ClassList.flatMap(v=>Array.from({length:10},(_,level)=>v['KnownList'+level]??[]).flat()).filter(v=>Number.isInteger(v.Spell)).length};
  return fixture.bytes;}return row.source==='vault'?vault.read(row.vaultId):fs.readFile(row.file);},resolveName:async value=>value?.text??value?.entries?.[0]?.text??'',publish:send,
  connect:async(connection,details,{signal}={})=>{
   signal?.throwIfAborted();
   if(menuCheck)throw Error('Network connections forbidden in menu check');
   const endpoint=policy.require(details),credentials={...details.credentials};lobby.endpoint=endpoint;report.endpoint=`${endpoint.host}:${endpoint.port}`;if(!credentials.cdKey)credentials.cdKey=await settings.cdKey();
   if(actionCheck){if(!report.nativeAdmission?.success||details.name!=='GodotNativeLocalTest')throw Error('Owned action admission must pass through the native profile and Direct Connect controls');report.nativeAdmissionIdentity={name:details.name,...endpoint};}
   const status=await settings.status();signal?.throwIfAborted();
   const created=await createInstalledNetworkSession({signal,install,...endpoint,name:details.name,credentials,userDirectory,cacheDirectory,modsDirectory:status.modsDirectory,disabledMods:status.disabledMods,onDiagnostic:d=>{if(report.diagnostics.length<128)report.diagnostics.push(d);},persistCharacter:async message=>{
    if(!actionCheck&&!creationCheck)return vault.save(message,{id:lobby.vaultId??null});
    const {parseGff}=await import('../../src/gff.js'),c=parseGff(message.data,'BIC ').root;
    report.exportedCharacter={sha256:crypto.createHash('sha256').update(message.data).digest('hex'),classes:c.ClassList.map(v=>({id:v.Class,level:v.ClassLevel})),abilities:['Str','Dex','Con','Int','Wis','Cha'].map(k=>c[k]),skills:(c.SkillList??[]).map(v=>v.Rank),feats:(c.FeatList??[]).map(v=>v.Feat),known:Object.fromEntries(c.ClassList.map(v=>[v.Class,Array.from({length:10},(_,l)=>v['KnownList'+l]??[]).flat().map(s=>s.Spell)]))};return{id:'native-local-actions',name:'Local actions fixture'};
   }});
   if(signal?.aborted||connection!==lobby.connection){await created.session.disconnect();throw Error('Cancelled native connection');}
   lobby.previewAccountScope=crypto.createHash('sha256').update(JSON.stringify([created.session.identity.publicKey,created.metadata.name])).digest('hex');
   created.session.deferNuiResources=true; attach(created.session,connection);lobby.attach(created.session,connection);report.publicConnections+=endpoint.host==='127.0.0.1'?0:1;
   let pin;if(endpoint.host==='127.0.0.1'&&endpoint.port===localPort){const log=await fs.readFile(path.join(root,actionCheck?'runtime-logs/native-playability-actions-server/logs/nwengineLog.txt':'runtime-logs/local-multiplayer-server/logs/nwengineLog.txt'),'utf8');pin=log.match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];if(!pin)throw Error('Owned local server identity is unavailable');}
   if(signal?.aborted||connection!==lobby.connection){await created.session.disconnect();return;}
   const connecting=created.session.connect({...endpoint,metadata:created.metadata,timeout:45000,...(pin?{expectedServerPublicKey:Buffer.from(pin,'base64')}:{})});
   if(localCancelCheck&&cancellationStage===1){setTimeout(()=>{if(connection===lobby.connection&&!created.session.closed){cancellationSentAt=performance.now();send({kind:'probe-session-cancel'});}},100);}
   await connecting;
  },disconnect:async options=>{
   const retiring=options.targetSession;
   if(session===retiring){session=null;setupSession=null;catalogReady=false;rawPending=null;worldDeltas.reset();snapshotGeneration=-1;send({kind:'session-reset'});}
   try{if(options.saveCharacter&&retiring&&!retiring.closed&&['playing','area-loading'].includes(retiring.phase))await retiring.exportCharacter();}
   catch{throw Error('Disconnected, but the character could not be saved.');}
   finally{await retiring?.disconnect();localDisconnectedAt=Date.now();}
  },save:()=>session.exportCharacter()});
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
  if(!authenticated){if(message.kind!=='hello'||message.token!==token)throw Error('Native session handshake failed');authenticated=true;lobby.emit();report.startupSurface=localCheck?'browser':'main-menu';send({kind:localCheck?'browser-open':'main-menu-open'});return;}
  if(message.kind==='main-menu-observed'){
   report.startupMainMenu={ready:message.ready,mainVisible:message.mainVisible,browserHidden:message.browserHidden,lobbyHidden:message.lobbyHidden};
   if(menuCheck&&!menuCheckFinishing){menuCheckFinishing=true;if(!message.ready||!message.mainVisible||!message.browserHidden||!message.lobbyHidden){void finish('Native startup did not show Main Menu');return;}send({kind:'finish-menu-check'});}return;
  }
  if(message.kind==='browser-observed'){report.browserReady=true;if(menuCheck&&!menuCheckFinishing){menuCheckFinishing=true;send({kind:'finish-menu-check'});}else if(!menuCheck&&localCheck&&!session){
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
  if(message.kind==='lobby-disconnect'){await lobby.leave(message);return;}
  if(message.kind==='lobby-export'){report.nativeExportRequests=(report.nativeExportRequests??0)+1;await lobby.export(message);return;}
  if(message.kind==='lobby-cancel-join'){
   const retiring=session;await lobby.cancelJoin(message);
   if(localCancelCheck&&cancellationStage===1){report.cancelCheck={elapsedMs:performance.now()-cancellationSentAt,peerClosed:retiring?.peer.closed===true};cancellationStage=2;cancellationSink.close();cancellationSink=null;}
   return;
  }
  if(message.kind==='lobby-join'){send({kind:'browser-open'});return;}
  if(message.kind==='creation-proof'){if(!creationCheck||!ownsConnection(message))return;report.creationProof=message;if(!message.success)void finish('Native character creation probe failed: '+JSON.stringify(message.failures));return;}
  if(message.kind.startsWith('native-creation-')){
   if(!ownsConnection(message))throw Error('Character creation belongs to a retired connection');
   try{
    if(message.kind==='native-creation-begin'){if(!lobby.selectable()||!session.resourceResult?.ready)throw Error('Character creation is not available');lobby.creating=true;lobby.emit();}
    else if(message.kind==='native-creation-cancel'){if(session.characterUploaded||session.characterSubmitted)throw Error('Character is already submitted');lobby.creating=false;lobby.emit();}
    else if(message.kind==='native-creation-submit'){
     if(!lobby.creating||!lobby.selectable()||typeof message.data!=='string'||message.data.length>4*1024*1024)throw Error('Character submission is stale or too large');
     const bytes=Buffer.from(message.data,'base64');try{if(bytes.toString('base64')!==message.data)throw Error('Invalid character encoding');report.nativeCreation={bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),nativeGenerated:true};await session.selectCharacter(bytes,{createOnServer:session.localVaultAllowed!==true});}finally{bytes.fill(0);}
    }else throw Error('Unsupported native character operation');
    send({kind:'native-creation-result',accepted:true});
   }catch(error){send({kind:'native-creation-result',accepted:false,text:error.message});}return;
  }
  if(message.kind==='catalog-ready'){if(!ownsConnection(message)){rejectRetired(message);return;}catalogReady=true;report.catalogReady=true;return;}
  if(message.kind==='raw-world-accepted'){if(!ownsConnection(message)){rejectRetired(message);return;}if(rawPending?.serial===message.serial&&rawPending.generation===message.generation&&worldDeltas.acknowledge(message))rawPending=null;return;}
  if(message.kind==='finished'){if(message.connection!==lobby.connection){rejectRetired(message);return;}send({kind:'finish-ack'});report.success=menuCheck?Boolean(message.success&&report.browserReady&&report.publicConnections===0):Boolean(message.success);return;}
  if(message.kind==='actions-progress'){if(actionCheck&&ownsConnection(message)){report.actionProgress??=[];report.actionProgress.push(message);await fs.writeFile(output.replace(/\.json$/,'.progress.json'),JSON.stringify({last:message,checks:report.actionProgress},null,2));}return;}
  if(message.kind==='actions-finished'){if(!actionCheck||!ownsConnection(message))return;report.actions=message;if(!message.success){void finish('Native UI action checks failed: '+JSON.stringify(message.failures));return;}await session.exportCharacter();report.localWalkDistance=localWalkProof.nativeDistance;report.authoritativeDistance=localWalkProof.serverDistance;report.localCycles=[{connection:lobby.connection,generation:session.areaGeneration,actionCheck:true}];localCycleEnding=true;send({kind:'finish'});return;}
  if(message.kind==='native-desktop-proof'){if(!localCheck||!ownsConnection(message))return;report.desktopProof=message;if(!message.success)throw Error('Native gameplay desktop probe failed');return;}
  if(message.kind==='render-settings-proof'){if(!localCheck||!ownsConnection(message))return;if(!message.opened||!message.paused||!message.restored||message.emitters<1||message.objects_before!==message.objects_after)throw Error('Native graphics settings probe failed');report.renderSettingsProof=message;return;}
  if(message.kind==='observed'){
   if(message.nativeView)loadingRecording?.view(message.nativeView);
   if(!ownsConnection(message)){rejectRetired(message);return;}
   report.lastObservation=message;setHostProfiling(Boolean(message.frame_profile?.enabled!==false&&message.frame_profile?.metrics));
   if(message.frame_profile?.enabled!==false&&message.frame_profile?.metrics&&Date.now()-profileAt>=2000){
    profileAt=Date.now();const state=message.state??{},particles=state.native_particles??{};
    const sample={protocol_host:hostMetrics(),particle_visibility:message.particle_visibility,ui_startup:message.ui_startup,at:profileAt,connection:message.connection,generation:message.generation,areaId:message.areaId,fps:message.fps,ready:state.ready,pending_batches:state.pending_batches,entities:state.entities,desired:state.desired,tiles:state.terrain?.rendered_tiles,particles:Object.fromEntries(['emitters','simulated','active','vertices','failed','culled_emitters','currently_culled'].map(key=>[key,particles[key]])),frame_profile:message.frame_profile};
    loadingRecording?.baseline(sample);
    await fs.appendFile(path.join(project,'reports',run+'.performance.jsonl'),JSON.stringify(sample)+'\n');
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
      if(creationCheck){if(!report.exportedCharacter){await session.exportCharacter();}report.localWalkDistance=localWalkProof.nativeDistance;report.authoritativeDistance=localWalkProof.serverDistance;report.localCycles=[{connection:lobby.connection,generation:session.areaGeneration,creationCheck:true,areaId:session.world.areaId,nativeDistance:localWalkProof.nativeDistance,serverDistance:localWalkProof.serverDistance}];localCycleEnding=true;send({kind:'finish'});return;}
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
  if(!ownsConnection(message)){rejectRetired(message);return;}
  if(message.generation!==session.areaGeneration||message.areaId!==session.world.areaId)throw Error('Native input belongs to a retired world');
  if(message.kind==='area-ready'){if(!session.areaReadySent)await session.areaReady(message.generation);report.areas.push({connection:lobby.connection,id:message.areaId,generation:message.generation});return;}
  if(message.kind==='test-barter-peer'){
   if(!actionCheck||!actionBarterCheck||!ownsConnection(message))return;
   if(message.operation==='start-peer'){
    if(barterPeerWork)throw Error('Owned barter peer already started');
    const connection=lobby.connection;barterPeerAbort=new AbortController();
    const publish=value=>{if(!ending&&lobby.connection===connection)send({kind:'test-barter-peer-status',value});};
    barterPeerWork=(async()=>{try{const key=barterPeerKey||await settings.cdKey();barterPeerKey='';const peer=await(await import('./native-barter-peer.mjs')).startNativeBarterPeer({install,userDirectory,cdKey:key,mainSession:session,signal:barterPeerAbort.signal,publish});if(ending){await peer.close();return;}barterPeer=peer;publish(peer.snapshot());}catch(error){publish({ready:false,error:'The second owned test peer could not enter the local server',stage:error.stage??'start',phase:error.phase??'uncreated',reasonCode:error.reasonCode??null,connectionError:error.connectionError??null,diagnosticCodes:error.diagnosticCodes??[]});}})();return;
   }
   if(!barterPeer)throw Error('Owned barter peer is not ready');await barterPeer.perform(message.operation,message.value);return;
  }
  const scope={areaId:message.areaId,areaGeneration:message.generation};if(session.phase!=='playing')throw Error('Native world is not playing');
  if(message.kind.startsWith('native-')){
	if(actionSpecialAttackCheck&&['native-feat','native-cancel-action'].includes(message.kind)){report.specialAttackRequests??=[];report.specialAttackRequests.push({kind:message.kind,featId:message.featId,targetId:message.targetId,auxiliary:message.auxiliary,actionId:message.actionId,groupId:message.groupId});}
    if(actionFeatCheck&&['native-feat','native-quickbar-assign','native-mode','walk'].includes(message.kind)){report.featFamilyRequests??=[];if(report.featFamilyRequests.length<16)report.featFamilyRequests.push(structuredClone(message));}
   const input={...message,...scope,actorId:session.world.localObjectId};let result;
   if(['native-map','native-party','native-players','native-player-attitude'].includes(message.kind))input.actorId=message.actorId;
   // Correlate transport refusal only. Success still waits for raw server slots.
   const preparationReply=['native-prepare','native-map','native-party','native-players','native-player-attitude'].includes(message.kind)&&Number.isSafeInteger(message.requestId)?{requestId:message.requestId,generation:message.generation,areaId:message.areaId,actorId:input.actorId}:{};
   try{
    const handlers={'native-barter':'barterInput','native-script-target':'selectScriptTarget','native-nui-input':'nuiInput','native-cancel-action':'cancelAction','native-rest':'rest','native-panel':'hudPanel','native-cast':'castSpell','native-spell-like':'castSpellLike','native-feat':'useFeat','native-mode':'changeMode','native-quickbar-assign':'assignQuickbar','native-quickbar-activate':'activateQuickbar','native-prepare':'prepareSpell','native-player-attitude':'playerAttitude','native-associate':'associateCommand','native-quickchat':'quickChat','native-level-up':'levelUp','native-store':'storeInput','native-item-ability':'useItem','native-possess':'possessFamiliar'};
    if(message.kind==='native-map')result=await session.mapInput(input);
    else if(message.kind==='native-party')result=await session.partyInput(input);
    else if(message.kind==='native-players')result=await session.playerListInput(input);
    else if(message.kind==='native-skill'){const actor=session.controlledActor(scope.areaId,scope.areaGeneration);result=await(await import('./skill-input.mjs')).submitNativeSkill(session,{...scope,actor,actorId:actor.id},input);}else{const method=handlers[message.kind];if(!method)throw Error('That action is not connected yet');
    result=await session[method](input);}
    send({kind:'ui-protocol',generation:message.generation,message:{kind:'native-action-result',action:message.kind,operation:message.operation,...preparationReply,accepted:true,result}});
   }catch(error){send({kind:'ui-protocol',generation:message.generation,message:{kind:'native-action-result',action:message.kind,operation:message.operation,...preparationReply,accepted:false,text:error.message}});}
  }
  else if(message.kind==='walk')await session.walkTo({...scope,position:message.position,run:false});
  else if(message.kind==='drive'){
   const result=await session.keyboardMove({...scope,actorId:message.actorId,operation:message.operation,position:message.position,heading:message.heading,flags:message.flags,transmit:message.transmit??true});
   send({kind:'drive-ack',connection:message.connection,generation:message.generation,areaId:message.areaId,actorId:message.actorId,lifetime:message.lifetime,requestId:message.requestId,...result});
  }
  else if(message.kind==='interact')await session.interact({...scope,targetId:message.targetId,action:message.action,...(message.position?{position:message.position}:{})});
  else if(message.kind==='pickup')await session.itemAction({...scope,itemId:message.targetId,operation:'pickup'});
  else if(message.kind==='examine')await session.examine({...scope,actorId:session.world.localObjectId,targetId:message.targetId});
  else if(message.kind==='chat')await session.chat({...scope,actorId:session.world.localObjectId,channel:message.channel,text:message.text,...(message.recipient?{recipient:message.recipient}:{})});
  else if(message.kind==='reply'){
   const result=await(await import('./native-dialog-input.mjs')).submitNativeDialogReply(session,{...scope,entryId:message.entryId,replyId:message.replyId,abort:message.abort},value=>send({kind:'ui-protocol',generation:message.generation,message:value}));
   if(result.resynchronized)report.dialogResynchronizations=(report.dialogResynchronizations??0)+1;
  }
  else if(message.kind==='inventory-open'){await session.inventoryWindow({...scope,open:true});await session.inventoryPanel({...scope,panel:message.page});}
  else if(message.kind==='inventory-close')await session.inventoryWindow({...scope,open:false});
  else if(message.kind==='inventory-page')await session.inventoryPanel({...scope,panel:message.page});
  else if(message.kind==='inventory-container')await session.containerInput({...scope,actorId:session.world.localObjectId,targetId:message.targetId,operation:message.operation});
  else if(message.kind==='inventory-gold')await session.transferGold({...scope,actorId:message.actorId,targetId:message.targetId,amount:message.amount,position:message.position,placement:message.placement??false,x:message.x??0,y:message.y??0,barterSerial:message.barterSerial});
  else if(message.kind==='item-use')await session.interact({...scope,targetId:message.itemId,action:'object.use'});
  else if(message.kind==='item-action')await session.itemAction({...scope,itemId:message.itemId,operation:message.operation,...Object.fromEntries(['slot','x','y','destinationId','amount'].filter(key=>message[key]!==undefined).map(key=>[key,message[key]]))});
  else throw Error('Unsupported native protocol command');
  if(['inventory-open','inventory-close','inventory-page','inventory-container','item-use','item-action'].includes(message.kind))send({kind:'ui-protocol',generation:message.generation,message:{kind:'inventory-command-result',requestId:message.requestId,accepted:true}});
 }
 const commandPump=new NativeCommandPump(command,(error,message)=>{if(message.connection!==undefined&&message.connection!==lobby.connection)return;if(['inventory-open','inventory-close','inventory-page','inventory-container','inventory-gold','item-use','item-action'].includes(message.kind))send({kind:'ui-protocol',generation:message.generation,message:{kind:'inventory-command-result',requestId:message.requestId,accepted:false,reason:error.message}});send({kind:'notice',text:error.message});lobby.error=error.message;lobby.emit();});
 const token=crypto.randomBytes(32).toString('hex');temporary=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-native-session-'));
 server=net.createServer(client=>{if(socket){client.destroy();return;}socket=client;report.nativeSocketConnected=true;let buffered='';client.on('data',bytes=>{buffered+=bytes.toString('utf8');if(buffered.length>1024*1024){void finish('Native command exceeds bound');return;}let at;while((at=buffered.indexOf('\n'))>=0){const line=buffered.slice(0,at);buffered=buffered.slice(at+1);try{commandPump.push(JSON.parse(line));}catch{void finish('Invalid native command');}}});client.on('error',()=>{});});
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});
 const preworkSources={install,profileDirectory:userDirectory,modsDirectory:startup.settings.modsDirectory,disabledMods:startup.settings.disabledMods??[],cacheDirectory,nativeDirectory:path.join(userDirectory,'nwsync'),helper:path.join(root,'tooling/native/content-reader/nwn-content-reader.exe')};
 const ticket=path.join(temporary,'ticket.json');await fs.writeFile(ticket,JSON.stringify({host:'127.0.0.1',port:server.address().port,token,preworkSources,localCharacterRoots:[path.join(install,'data/lcv'),path.join(vault.directory,'blobs')]}),{flag:'wx'});
 const executable=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),nativeArgs=['--path',project,'--rendering-method','forward_plus','--rendering-driver','vulkan',...(headless?['--headless']:[]),'--log-file',path.join(project,'reports',run+'.engine.log'),'--script','res://native_session_world.gd','--','--ticket='+ticket,'--report='+nativeReport,'--profile-control='+path.join(project,'reports',run+'.profile-control.json'),...(creationCheck?['--creation-class='+(arg('creation-class')??'fighter')]:[]),...(actionCheck?['--actions-check=true']:[]),...(actionNuiCheck?['--actions-nui-check=true']:[]),...(localCheck?['--settings-check=true']:[]),...((localCheck||actionCheck)?['--render-preferences='+path.join(project,'reports',run+'.settings.cfg'),'--menu-layout='+path.join(project,'reports',run+'.layout.cfg')]:[]),...(nativeProfile?['--profile=true']:[])];
 if(!headless&&nativeScreen!==undefined)nativeArgs.unshift('--screen',nativeScreen);
 if(localCheck||menuCheck)nativeArgs.push('--lobby-preferences='+path.join(project,'reports',run+'.lobby.cfg'));
 if(localCheck)nativeArgs.push('--local-ui-check=true');
 if(actionCheck)nativeArgs.push('--preview-check-key='+checkedCharacterKey);
 nativeArgs.push('--preview-directory='+characterPreviewStore.directory);
 if(preworkCheckLimit!==undefined)nativeArgs.push('--prework-check-limit='+preworkCheckLimit);
 if(preworkCheckCold)nativeArgs.push('--prepared-cache='+path.join(temporary,'prework-cold'));
 if(recordLoading)nativeArgs.push('--prepared-cache='+path.join(temporary,'prepared'),'--recording=true');
 report.startupScreen=nativeScreen===undefined?null:Number(nativeScreen);
 if(actionEffectsCheck)nativeArgs.push('--actions-effects-check=true');
 if(actionCheck&&report.actionFixture.module==='GodotJournal2'){if(report.actionFixture.journal?.tag!=='native_journal')throw Error('Journal check requires its owned JRL fixture');nativeArgs.push('--actions-journal-check=true');}
 if(actionCheck&&report.actionFixture.module==='GodotMap1'){if(report.actionFixture.map?.tag!=='native_map_note')throw Error('Map check requires its owned note/GUI fixture');nativeArgs.push('--actions-map-check=true');}
 if(actionCorrectionCheck){if(!actionCheck||report.actionFixture.module!=='GodotCorrection')throw Error('Correction check requires its owned local fixture');nativeArgs.push('--actions-correction-check=true');}
 if(actionRadialCheck){if(!actionCheck||report.actionFixture.module!=='GodotActions')throw Error('Radial check requires its owned local fixture');nativeArgs.push('--actions-radial-check=true');}
 if(actionFeatCheck){if(!actionCheck||report.actionFixture.module!=='GodotActions')throw Error('Feat check requires its owned local fixture');nativeArgs.unshift('--max-fps','30');nativeArgs.push('--actions-feat-check=true');report.featFamilyFrameCap=30;}
 if(actionBarterCheck){if(!actionCheck||report.actionFixture.module!==(actionPlayersCheck?'GodotPlayers1':'GodotActions'))throw Error('Two-peer check requires its owned local fixture');nativeArgs.push('--actions-barter-check=true');}
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
 let launch=executable,launchArgs=nativeArgs;
 if(debuggerCheck){const commands=path.join(project,'reports',run+'.cdb.txt'),trap='.echo NATIVE_SESSION_EXCEPTION;.exr -1;.ecxr;kv;~* k;q';await fs.writeFile(commands,[...['av','bpe','0xc0000374','0xc0000409','0xc000001d'].map(value=>`sxe -c "${trap}" ${value}`),'.echo NATIVE_SESSION_ARMED','g'].join('\n')+'\n',{flag:'wx'});launch='C:/Program Files (x86)/Windows Kits/10/Debuggers/x64/cdb.exe';launchArgs=['-hd','-G','-sins','-y',path.join(project,'.tools'),'-logo',path.join(project,'reports',run+'.cdb.log'),'-cf',commands,executable,...nativeArgs];}
 native=spawn(launch,launchArgs,{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']});
 native.stdout.on('data',bytes=>{report.nativeOutput=((report.nativeOutput??'')+bytes.toString()).slice(-5000);});native.stderr.on('data',bytes=>{report.engineErrors=((report.engineErrors??'')+bytes.toString()).slice(-12000);});native.once('error',()=>void finish('Native engine could not start'));native.once('exit',code=>{report.nativeExit=code;void finish(code===0?null:'Native engine exited with failure');});
 timer=setInterval(()=>{
  try{if(ending||!authenticated)return;
   if(localCheck&&localCycleEnding&&!session&&!lobby.busy&&!lobby.joinWork&&!localJoinPending&&(report.localCycles?.length??0)<localCycles&&Date.now()-localDisconnectedAt>2000){
    localJoinPending=true;void lobby.join({connection:lobby.connection,details:{host:'127.0.0.1',port:localPort,name:'GodotNativeLocalTest',credentials:{password:''}}}).catch(error=>finish(error.message)).finally(()=>{localJoinPending=false;});return;
   }
   if(!session||session.closed)return;
   if(localWalkOrigin&&localWalkGeneration===session.areaGeneration){const p=session.world.registry.get(session.world.localObjectId)?.replicated?.position;if(p)authoritativeDistance=Math.max(authoritativeDistance,Math.hypot(...p.map((value,index)=>value-localWalkOrigin[index])));}
   if(localCheck&&!localPlaying&&!localWork&&lobby.snapshot().canSelect&&(!creationCheck||catalogReady)&&(creationCheck||report.nativeChooserReady?.success&&report.nativeChooserReady.connection===lobby.connection)&&(!actionLobbyPagesCheck||report.lobbyPages?.success)&&(!actionLocalDeleteCheck||report.localDelete?.success)){
    localPlaying=true;
    if(creationCheck)send({kind:'probe-native-creation'});
    else localWork=(async()=>{
     const connection=lobby.connection,key=checkedCharacterKey;if(lobby.selected!==key||!lobby.preview?.sha256)await lobby.choose({connection,key});
     if(actionCheck){
      const sha256=lobby.preview?.sha256,scope={connection,key,sha256},deadline=Date.now()+45000;
      const ready=()=>report.characterPreviewProof?.success&&lobby.connection===connection&&lobby.selected===key&&lobby.preview?.sha256===sha256&&previewProofMatches(report.characterPreviewProof,scope,report.characterPreviewExpected);
      while(!ending&&!ready()&&Date.now()<deadline)await new Promise(resolve=>setTimeout(resolve,25));
      if(ending)return;if(!ready())throw Error('Current native character preview did not become ready');
     }
     await lobby.play({connection,key});
    })().catch(error=>finish(error.message));
   }
   if(session.resourceResult?.ready&&setupSession!==session){send({kind:'setup',interactive:!localCheck||recordLoading,install,moduleName:session.serverInfo?.moduleName??'Multiplayer',serverLabel:`${lobby.endpoint.host}:${lobby.endpoint.port}`,resourceSources:sourceDescriptor(session)});setupSession=session;}
   if(!catalogReady)return;const area=session.world.registry.get(session.world.areaId)?.state;if(!area?.tiles)return;
   if(rawPending)return;
   const serial=++rawSerial,generation=session.areaGeneration,data={area,objects:[...session.world.registry.objects.values()].map(object=>rawCombat.object(object)),controlledId:session.world.localObjectId,entry:session.world.entry,time:session.world.time,module:session.world.module,inventory:{inventories:[...session.world.inventories],containers:[...session.world.containers],store:session.world.store},ui:{scriptTargeting:session.world.scriptTargeting,scriptTargetingData:session.world.scriptTargetingData,party:session.world.party,quickbar:session.world.quickbar,players:[...session.world.players],journal:{entries:[...session.world.journal.entries],worldEntries:[...session.world.journal.worldEntries],loaded:session.world.journal.loaded},barter:session.world.barter,mapPins:[...session.world.mapPins]}};
   data.ui.partyInviteNotice=session.world.partyInviteNotice;
   data.ui.playerAttitudes=[...session.world.playerAttitudes];
   data.ui.partyListRevision=session.world.partyListRevision;
   const changed=worldDeltas.plan({serial,generation,data,connection:lobby.connection});
   if(!changed)return;
   report.rawWorldUpdates??={full:0,delta:0,objects:0,removed:0};report.rawWorldUpdates[changed.bridgeMode]++;report.rawWorldUpdates.objects+=changed.objects.length;report.rawWorldUpdates.removed+=changed.removedObjectIds.length;
   for(const frame of rawWorldFrames({serial,generation,data:changed,connection:lobby.connection})){socket.write(frame);if(loadingRecording)loadingRecording.frame(JSON.parse(frame),frame);}
   rawPending={serial,generation};snapshotGeneration=generation;
  }catch(error){send({kind:'failure',reason:error.message});void finish(error.message);}
 },200);
 console.log('DIRECT NATIVE GODOT · protocol-only host · no automatic server connection');
 report.bootStage='native-launched';clearInterval(startupStatus);
 if(menuCheck){const deadline=setTimeout(()=>void finish('Native menu check timed out'),preworkCheckLimit===undefined?20000:240000);deadline.unref();}
 if(localCheck){const deadline=setTimeout(()=>void finish('Native localhost check timed out'),(actionCheck?360000:120000)*localCycles);deadline.unref();}
})().catch(error=>void finish(error.message));
