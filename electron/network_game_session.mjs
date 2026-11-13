import {nativeLevelUpDraftContext} from '../src/network_level_up_context.js';
import {networkConnectionFailure,networkConnectionFailureText} from '../src/network_connection_failure.js';
import {EventEmitter} from 'node:events';
import {NetworkPortalTransfer} from './network_portal_transfer.mjs';
import {decodeServerGameMessage,serverStatusRequest,moduleReadyRequest,clientAreaReadyRequest} from '../src/network_game_messages.js';
import {resolveServerResources} from '../src/network_resources.js';
import {characterBlobRequest,characterExportRequest} from '../src/network_character.js';
import {serverCharacterListRequest,serverCharacterPreviewRequest,serverCharacterPlayRequest,lobbyPlayerListRequest} from '../src/network_character_selection.js';
import {serverCharacterPreviewSummary} from '../src/network_character_preview.js';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {NetworkWorld} from '../src/network_world.js';
import {barterRequest} from '../src/network_barter.js';
import {parseGff} from '../src/gff.js';
import {isNetworkBytes} from '../src/network_bytes.js';
import {RESOURCE_TYPE} from '../src/resource_archive.js';
import {availableCreationPortraits} from '../src/creation_portraits.js';
import {isNativeAudioResourceRef} from '../src/native_audio.js';
import {networkDoorClickState} from '../src/network_door.js';
import {deviceEchoResponse,loginWaypointResponse} from '../src/network_runtime_messages.js';
import {chatRequest} from '../src/network_chat_input.js';
import {quickbarAssignmentRequest} from '../src/network_quickbar.js';
import {emptyQuickbarButton} from '../src/quickbar.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {spellCastRequest,spellLikeCastRequest,spellPreparationRequest,spellPreparationClearRequest} from '../src/network_spell_input.js';
import {itemUseRequest} from '../src/network_item_input.js';
import {containerRequest} from '../src/network_container.js';
import {storeRequest} from '../src/network_store.js';
import {restRequest,characterSheetRequest,journalWindowRequest,playerAttitudeRequest,effectIconGuiRequest,chatFocusGuiRequest,chatReplyGuiRequest,skillDescriptionGuiRequest,featDescriptionGuiRequest} from '../src/network_hud_input.js';
import {NativeJournalEvents} from '../src/network_journal_events.js';
import {nativeRecordTarget,nativeRecordFeatPresent} from '../src/network_record_target.js';
import {guiPanelAttemptRequest} from '../src/network_gui_panel_access.js';
import {guiContextSource,guiContextPosition,guiContextOpenRequest} from '../src/network_gui_context_input.js';
import {featUseRequest,modeChangeRequest,possessFamiliarRequest} from '../src/network_feat_input.js';
import {associateCommandRequest,quickChatRequest,networkAssociateShortcut} from '../src/network_associate_input.js';
import {emoteAnimationRequest} from '../src/network_emote_input.js';
import {cancelPolymorphRequest} from '../src/network_polymorph_input.js';
import {levelUpBeginRequest,levelUpRequest,networkLevelUpSnapshot} from '../src/network_level_up.js';
import {levelUpCancelGuiRequest} from '../src/network_level_up_gui.js';
import {nuiInputRequest} from '../src/network_nui.js';
import {mapPinClickRequest,mapNoteRequest} from '../src/network_map_input.js';
import {partyRequest,playerListGuiRequest} from '../src/network_party_input.js';
import {scriptTargetSelectionRequest,scriptTargetAllowed} from '../src/network_script_targeting.js';
import {satisfiesNativeBuild} from '../src/network_build.js';
import {driveControlRequest,abortDriveRequest,driveOrientationRequest} from '../src/network_player_requests.js';
import {examineRequest,cancelActionRequest} from '../src/network_player_requests.js';
import {walkToWaypointRequest,doorActionRequest,talkToRequest,useObjectRequest,attackRequest,dialogReplyRequest,inventoryWindowRequest,inventoryPanelRequest,goldTransferRequest,equipItemRequest,unequipItemRequest,pickupItemRequest,dropItemRequest,moveItemRequest,toggleItemEquipmentRequest,splitItemRequest,learnScrollRequest} from '../src/network_player_requests.js';

// Application admission/presentation owner, distinct from the reliable peer.
// Area-ready is acknowledged by the renderer after loading, never by a timer.
// This owner does not instantiate ModuleSession, scripts, AI or local rules.
const clientFailureText=value=>typeof value==='string'?value.replace(/\b[A-Z0-9]{5}(?:-[A-Z0-9]{5}){6}\b/gi,'[protected key]').replace(/[\x00-\x1f\x7f]/g,' ').slice(0,384):'';
export class NetworkGameSession extends EventEmitter {
 constructor({peer,identity,build,resources,language,openModule,onDiagnostic=()=>{},decodeMessage=decodeServerGameMessage,loadRules=loadNetworkObjectRules,loginWaypoint='',persistCharacter=null,characterExportTimeoutMs=15000,serverInfo=null,localVaultAllowed=true,preparePortal=null,portalTimeoutMs=15000}){
  super();loginWaypointResponse(loginWaypoint);this.loginWaypoint=loginWaypoint;this.deviceEchoReplies=0;this.loginWaypointRequests=0;this.tlkOverrideMessages=0;Object.assign(this,{peer,identity,build,resources,language,openModule,onDiagnostic,decodeMessage,loadRules});
  this.world=new NetworkWorld({onDiagnostic:d=>this.diagnose(d)});this.delivery=Promise.resolve();this.phase='new';this.closed=false;this.areaGeneration=0;this.objectRules={};this.movementSequences=new Map();this.persistCharacter=persistCharacter;this.characterExportTimeoutMs=characterExportTimeoutMs;
  resources.setProgress?.(progress=>{if(!this.closed){this.resourceProgress=progress;this.publish();}});
  this.serverInfo=serverInfo;this.localVaultAllowed=localVaultAllowed;this.serverCharacters=[];this.characterListGeneration=0;
  this.portalTransfer=new NetworkPortalTransfer(this,{prepare:preparePortal,timeout:portalTimeoutMs});
  peer.on('message',bytes=>{
   const receivedAt=Date.now();this.delivery=this.delivery.then(()=>this.receive(bytes,receivedAt)).catch(error=>{
    if(!this.closed){
     const reason=clientFailureText(error?.message)||'Native game-message processing failed';
     this.clientFailure??={code:'network.game-session-failed',reason:'The client could not process a server update.',cause:{code:this.lastImportFailure?.reason===reason?this.lastImportFailure.code:'network.message-processing-failed',reason},phase:this.phase,areaGeneration:this.areaGeneration};
     this.diagnose({code:'network.game-session-failed',reason:'Native game-message delivery failed',clientFailure:structuredClone(this.clientFailure)});void this.disconnect();
    }
   });
  });
  peer.on('closed',event=>{if(event?.reason)this.disconnectReason={...event.reason};if(event?.failed&&this.portalTransfer.pending){this.portalTransfer.fail('The old connection failed during its portal handoff');return;}if(event?.failed&&!this.closed&&!this.disconnectReason)this.clientFailure??={code:'network.peer-failed',reason:'The game connection was lost.',cause:{code:'network.peer-failed',reason:'Native network peer failed'},phase:this.phase,areaGeneration:this.areaGeneration};if(!this.portalTransfer.peerClosed())this.finish();});
 }
 diagnose(d){if(d.code==='network.object-import-failed')this.lastImportFailure={code:d.code,reason:clientFailureText(d.reason)};this.onDiagnostic(d);this.emit('diagnostic',d);}
 state(){return{phase:this.phase,closed:this.closed,...(this.disconnectReason?{disconnectReason:{...this.disconnectReason}}:{}),...(this.clientFailure?{clientFailure:structuredClone(this.clientFailure)}:{}),resourceProgress:this.resourceProgress??null,resourcesReady:Boolean(this.resourceResult?.ready&&this.resolver),characterUploaded:Boolean(this.characterUploaded),characterSubmitted:Boolean(this.characterSubmitted||this.characterUploaded),characterConfirmed:Boolean(this.characterConfirmed),localVaultAllowed:this.localVaultAllowed,serverInfo:this.serverInfo,areaGeneration:this.areaGeneration,areaReady:Boolean(this.areaReadySent),deviceEchoReplies:this.deviceEchoReplies,loginWaypointRequests:this.loginWaypointRequests,tlkOverrideMessages:this.tlkOverrideMessages,world:this.world.snapshot()};}
 publish(){if(!this.closed)this.emit('state',this.state());}
 async connect(options){
  if(this.phase!=='new'||this.closed)throw new Error('Native game session has already started');
  // NetworkPeer.connect forwards metadata to NetworkLogin. A top-level
  // connectionType is not an effective handshake input and must not set role.
  if(options?.metadata?.connectionType===16)this.world.beginClientConnection(16);
  this.phase='connecting';this.publish();
  try{const remote=await this.peer.connect(this.identity,options);if(this.closed)throw new Error('Native game session is closed');this.serverBuild=remote.build;this.phase='resources';this.publish();await this.peer.sendGameMessage(serverStatusRequest());return remote;}
  catch(error){const failure=this.peer.connectionFailure??networkConnectionFailure(error,'session-connect');if(!this.peer.disconnecting)this.diagnose({code:'network.session-connect-failed',reason:'Native session connection failed',failure});await this.disconnect();throw new Error(networkConnectionFailureText(failure),{cause:error});}
 }
 async selectCharacter(bytes,{createOnServer=false}={}){
  if(this.closed||this.characterUploaded||this.characterSubmitted)throw new Error('Native character selection is unavailable');
  if(typeof createOnServer!=='boolean'||(!createOnServer&&this.localVaultAllowed!==true))throw new Error('This server requires server-vault character selection');
  if(!isNetworkBytes(bytes)||bytes.length===0||bytes.length>948*65535-16)throw new Error('Invalid native character selection');
  parseGff(bytes,'BIC ');const owned=Uint8Array.from(bytes);this.character?.fill(0);this.character=owned;this.characterUploadSubtype=createOnServer?19:1;
  if(this.lobbyPlayersOpen)await this.lobbyPlayers(false);
  await this.uploadCharacter();
 }
 acceptPortalCharacter(character){
  if(this.closed||this.phase!=='new')throw Error('Portal destination session is stale');
  if(character.data){parseGff(character.data,'BIC ');this.character=Uint8Array.from(character.data);this.characterUploadSubtype=1;}
  else{serverCharacterPlayRequest(character);this.portalCharacter={source:character.source,resref:character.resref};}
 }
 async uploadCharacter(){
  if(this.closed||!this.resourceResult?.ready||!this.resolver||!this.character||this.characterUploaded)return;
  // Set before awaiting: duplicate native requests must not upload twice.
  const bytes=this.character;this.character=null;this.characterUploaded=this.characterSubmitted=true;
  try{await this.peer.sendGameMessage(characterBlobRequest(bytes,{subtype:this.characterUploadSubtype??1}));if(!this.closed){this.phase='character';this.publish();}}finally{bytes.fill(0);}
 }
 async requestServerCharacters(){
  if(this.closed||!this.resolver||this.characterSubmitted||this.characterUploaded)throw new Error('Server character selection is unavailable');
  if(this.serverCharacterListPending)return{pending:true};this.serverCharacterListPending=true;this.selectedServerCharacter=null;
  this.emit('message',{message:{kind:'server-character-loading'},areaGeneration:this.areaGeneration});await this.peer.sendGameMessage(serverCharacterListRequest());return{requested:true};
 }
 async lobbyPlayers(open){
  if(this.closed||!this.resolver||typeof open!=='boolean'||this.characterSubmitted)throw new Error('Character lobby is unavailable');if(Boolean(this.lobbyPlayersOpen)===open)return;
  const previous=Boolean(this.lobbyPlayersOpen),serial=(this.lobbyPlayersSerial??0)+1;this.lobbyPlayersSerial=serial;this.lobbyPlayersOpen=open;
  try{await this.peer.sendGameMessage(lobbyPlayerListRequest(open));return{requested:open};}
  catch(error){if(this.lobbyPlayersSerial===serial)this.lobbyPlayersOpen=previous;throw error;}
 }
 async previewLocalCharacter(bytes){
  if(this.localVaultAllowed!==true||this.closed||!this.resolver||this.characterSubmitted)throw new Error('Local character selection is unavailable');if(!isNetworkBytes(bytes)||!bytes.length||bytes.length>948*65535-16)throw new Error('Invalid native character preview');const resolver=this.resolver;
  if(this.characterPreviewEncoder){const value=await this.characterPreviewEncoder(bytes);if(this.closed||this.resolver!==resolver)throw new Error('Local character preview is stale');return value;}
  this.previewRules??=import('../src/character.js').then(m=>m.loadCharacterRules(resolver));const rules=await this.previewRules;if(this.closed||this.resolver!==resolver)throw new Error('Local character preview is stale');return serverCharacterPreviewSummary(bytes,rules);
 }
 serverCharacter(request){
  if(this.closed||!['character-selection','character-rejected'].includes(this.phase)||this.serverCharacterListPending||this.characterSubmitted||this.characterUploaded||request.generation!==this.characterListGeneration)throw new Error('Server character selection is stale');
  const entry=this.serverCharacters.find(row=>row.source===request.source&&row.resref===request.resref);if(!entry)throw new Error('Server character is not in the current server list');return entry;
 }
 async previewServerCharacter(request){
  const entry=this.serverCharacter(request);this.selectedServerCharacter=entry;await this.peer.sendGameMessage(serverCharacterPreviewRequest(entry));return{selected:true};
 }
 async playServerCharacter(request){
  const entry=this.serverCharacter(request);if(this.lobbyPlayersOpen)await this.lobbyPlayers(false);this.serverCharacter(request);this.characterSubmitted=true;this.selectedServerCharacter=entry;this.phase='character';this.publish();await this.peer.sendGameMessage(serverCharacterPlayRequest(entry));return{submitted:true};
 }
 async receive(bytes,receivedAt=Date.now()){
  if(this.closed)return;
  let message;
  try{message=this.decodeMessage(bytes,{clientBuild:this.build.build,serverBuild:this.serverBuild,objectRules:{...this.objectRules,objectState:id=>this.world.registry.get(id)?.replicated}});}
  catch(error){this.diagnose({code:'network.game-message-invalid',reason:error.message,length:bytes.length,major:bytes[1],minor:bytes[2],...(error.objectUpdate?{objectUpdate:error.objectUpdate}:{})});return;}
  if(await this.portalTransfer.receive(message))return;
  // Direct native clients load JUI resources on their native asset workers.
  if(message.kind==='nui-create'&&message.format===0&&this.deferNuiResources)message={...message,layout:{}};
  if(message.kind==='nui-create'&&message.format===0&&!this.deferNuiResources){const resolver=this.resolver;if(!resolver)return;try{const data=await resolver.getResource(message.resref,2083);if(this.closed||this.resolver!==resolver)return;message={...message,layout:JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(data))};}catch(error){this.diagnose({code:'network.nui-resource-unavailable',reason:error.message,resref:message.resref});return;}}
  if(message.kind==='level-up-classes'||message.kind==='level-up-result'){
   const pending=this.pendingLevelUp;
   this.levelUpUncertain=false;
   if(!pending)return;
   if(pending.operation==='begin'&&message.kind==='level-up-classes'){
    pending.available=message.available;this.completeLevelUpBegin();return;
   }
   if(message.kind==='level-up-result'){clearTimeout(pending.timer);this.pendingLevelUp=null;this.levelUpDraft=null;if(pending.operation==='begin')pending.reject(Error('The server did not allow leveling up'));else pending.resolve({accepted:message.accepted});return;}
  }
  if(message.kind==='server-character-player'){if(this.lobbyPlayersOpen&&!this.characterSubmitted)this.emit('message',{message,areaGeneration:this.areaGeneration});return;}
  if(message.kind==='server-character-list'){
   if(!this.resolver||this.characterSubmitted||this.characterUploaded||!this.serverCharacterListPending){this.diagnose({code:'network.character-list-stale',reason:'Unrequested or stale server character list was ignored'});return;}
   this.serverCharacterListPending=false;this.serverCharacters=message.characters;this.characterListGeneration++;this.selectedServerCharacter=null;
   this.emit('message',{message:{...message,generation:this.characterListGeneration},areaGeneration:this.areaGeneration});this.publish();return;
  }
  if(message.kind==='server-character-preview'){
   try{const selected=this.selectedServerCharacter,type=selected?.source===17?5:selected?.source===14?4:1;if(!selected||this.closed||this.characterSubmitted||message.resref!==selected.resref||message.previewType!==type)return;
    if(this.characterPreviewEncoder){const preview=message.data.length?await this.characterPreviewEncoder(message.data):null;if(this.closed||this.characterSubmitted||this.selectedServerCharacter!==selected)return;this.emit('message',{message:{kind:'server-character-preview',resref:message.resref,source:selected.source,generation:this.characterListGeneration,preview},areaGeneration:this.areaGeneration});return;}
    let rules=null;if(message.data.length&&typeof this.resolver?.getResource==='function'){try{this.previewRules??=import('../src/character.js').then(({loadCharacterRules})=>loadCharacterRules(this.resolver));rules=await this.previewRules;}catch{if(!this.closed)this.diagnose({code:'network.character-preview-rules-unavailable',reason:'Derived character-record rules could not be loaded'});}}
    if(this.closed||this.characterSubmitted||this.selectedServerCharacter!==selected)return;const preview=message.data.length?serverCharacterPreviewSummary(message.data,rules):null;this.emit('message',{message:{kind:'server-character-preview',resref:message.resref,source:selected.source,generation:this.characterListGeneration,preview},areaGeneration:this.areaGeneration});
   }catch{this.diagnose({code:'network.character-preview-invalid',reason:'The server character preview could not be read'});}finally{message.data.fill(0);}return;
  }
  if(message.kind==='character-export'){
   try{
    if(!this.characterConfirmed||!this.persistCharacter)throw new Error('Native character vault is unavailable');
    const entry=await this.persistCharacter(message);this.savedCharacter=entry;this.exportUncertain=false;
    const pending=this.pendingCharacterExport;this.pendingCharacterExport=null;if(pending){clearTimeout(pending.timer);pending.resolve(entry);}
    if(!this.closed){this.emit('message',{message:{kind:'character-saved',entry},areaGeneration:this.areaGeneration});this.publish();}
   }catch(error){this.exportUncertain=false;const pending=this.pendingCharacterExport;this.pendingCharacterExport=null;if(pending){clearTimeout(pending.timer);pending.reject(error);}this.diagnose({code:'network.character-save-failed',reason:'The server character export could not be saved',detail:error.message});}
   finally{message.data.fill(0);}return;
  }
  if(message.kind==='device-echo-request'){await this.peer.sendGameMessage(deviceEchoResponse(message.data));if(!this.closed){this.deviceEchoReplies++;this.publish();}return;}
  if(message.kind==='login-waypoint-request'){this.loginWaypointRequests++;const response=loginWaypointResponse(this.loginWaypoint);if(response)this.loginWaypoint='';if(response)await this.peer.sendGameMessage(response);if(!this.closed)this.publish();return;}
  if(message.kind==='tlk-overrides')this.tlkOverrideMessages++;
  this.world.apply(message);
  if(message.kind==='object-updates')this.completeLevelUpBegin();
  if(message.kind==='dialog-entry')this.dialog={...message,replies:null};
  if(message.kind==='dialog-replies'&&this.dialog)this.dialog.replies=message;
  if(message.kind==='dialog-close')this.dialog=null;
  if(message.kind==='server-resources'){
   // Native LoadModuleResources7cdd20 refuses to initialize the same module
   // owner twice. A new connection owns a new resource context.
   if(this.resolver){this.diagnose({code:'network.resource-repeat-ignored',reason:'Repeated module resource initialization was ignored'});return;}
   const result=await resolveServerResources(message.requirements,{...this.resources,language:this.language,onDiagnostic:d=>this.diagnose(d)});
   if(this.closed)return;
   this.resourceResult=result;
   if(result.ready){
    const module=result.resolved.find(r=>r.kind==='nwm');
    try{
     // Custom servers need not advertise a local campaign NWM. Their area
     // data arrives on the wire; client assets come from the resource stack.
     const resolver=await this.openModule(module?.resource??null,result.resolved,message.requirements);if(this.closed)return;
     const rules=await this.loadRules(resolver);if(this.closed)return;
     this.resolver=resolver;this.objectRules=rules;this.phase='character-selection';
     if(this.portalCharacter){const selected=this.portalCharacter;this.portalCharacter=null;this.selectedServerCharacter=selected;this.characterSubmitted=true;this.phase='character';await this.peer.sendGameMessage(serverCharacterPlayRequest(selected));}
     else await this.uploadCharacter();
     if(!this.characterSubmitted&&!this.characterUploaded)await this.requestServerCharacters();
    }catch{if(!this.closed){this.resolver=null;this.objectRules={};this.phase='resources-unavailable';this.diagnose({code:'network.resource-context-failed',reason:'Server resource archives or rule tables could not be loaded'});}}
   }else this.phase='resources-unavailable';
  }
  if(this.closed)return;
  if(message.kind==='character-confirmed'&&(this.characterSubmitted||this.characterUploaded))this.characterConfirmed=true;
  if(message.kind==='character-rejected'){this.characterSubmitted=this.characterUploaded=this.characterConfirmed=false;this.phase='character-rejected';this.diagnose({code:'network.character-rejected',reason:'The server rejected the selected character',strRef:message.reason});}
  if(message.kind==='module-info'&&this.characterConfirmed&&!this.moduleReadySent){this.moduleReadySent=true;await this.peer.sendGameMessage(moduleReadyRequest());}
  if(this.closed)return;
  if(message.kind==='client-area'){this.areaGeneration++;this.areaReadySent=false;this.phase='area-loading';this.dialog=null;}
  if(message.kind==='unsupported')this.diagnose({code:'network.game-message-unhandled',reason:'Native game-message handler is unavailable',major:message.major,minor:message.minor,length:message.length});
  if(message.kind==='object-updates'&&!message.complete)this.diagnose({code:'network.object-record-unhandled',...message.unhandled});
  // Parsed wire values only: no filesystem paths, authentication material or
  // original peer packets cross into a renderer through this event.
  if(message.kind.startsWith('nui-')){message.nuiTiming={receivedAt,emittedAt:Date.now()};if(message.kind==='nui-create')this.diagnose({code:'network.nui-window-received',reason:'Native NUI create decoded and published',token:message.token,format:message.format,queueAndDecodeMs:Date.now()-receivedAt});}
  this.emit('message',{message,areaGeneration:this.areaGeneration});this.publish();
 }
 completeLevelUpBegin(){const pending=this.pendingLevelUp;if(pending?.operation!=='begin'||!pending.available)return;let actor,snapshot,protocolFeatures;try{actor=this.controlledActor(pending.areaId,pending.areaGeneration);if(actor.id!==pending.actorId)throw Error('Level-up creature changed');snapshot=networkLevelUpSnapshot(actor);protocolFeatures={multiclassRuleset:satisfiesNativeBuild(this.serverBuild??this.build.build,{number:8193,revision:35,postfix:0})};}catch{return;}const token=this.levelUpToken=(this.levelUpToken??0)+1;this.levelUpDraft={actorId:pending.actorId,areaId:pending.areaId,areaGeneration:pending.areaGeneration,snapshot,available:pending.available,token};clearTimeout(pending.timer);this.pendingLevelUp=null;pending.resolve({token,snapshot,available:pending.available,protocolFeatures,draftContext:nativeLevelUpDraftContext(actor)});}
 async areaReady(generation){
  if(this.closed||this.phase!=='area-loading'||generation!==this.areaGeneration||this.areaReadySent)throw new Error('Native area presentation acknowledgement is stale');
  this.areaReadySent=true;
  try{await this.peer.sendGameMessage(clientAreaReadyRequest());if(!this.closed&&generation===this.areaGeneration){this.phase='playing';this.publish();}}
  catch(error){if(!this.closed&&generation===this.areaGeneration)this.areaReadySent=false;throw error;}
 }
 async getResource(resref,type){
  if(this.closed||!this.resolver)throw new Error('Native session resources are unavailable');
  // Resource references are archive keys. They are never filesystem paths.
  // CResRef::InitFromCharArray190d30 copies without trimming. Live catalogs
  // contain space-padded names; archive lookup must preserve those keys too.
  if(typeof resref!=='string'||!/^[^\x00-\x1f/\\:]{1,32}$/.test(resref)||!Object.values(RESOURCE_TYPE).includes(type))throw new Error('Invalid native resource request');
  const resolver=this.resolver,result=type===RESOURCE_TYPE.WAV&&this.resources.waveResource?await this.resources.waveResource(resolver,resref):await resolver.getResource(resref,type);if(this.closed||resolver!==this.resolver)throw new Error('Native resource request is stale');return result;
 }
 async getTextureResource(resref){
  if(this.closed||!this.resolver)throw new Error('Native session resources are unavailable');
  if(typeof resref!=='string'||!/^[^\x00-\x1f/\\:]{1,32}$/.test(resref))throw new Error('Invalid native texture request');
  const resolver=this.resolver,result=await resolver.getTextureResource(resref);
  if(this.closed||resolver!==this.resolver)throw new Error('Native texture request is stale');return result;
 }
 async getAudioResource(resref,type){
  if(this.closed||!this.resolver)throw new Error('Native session resources are unavailable');
  if(!isNativeAudioResourceRef(resref)||![4,8].includes(type))throw new Error('Invalid native audio resource request');
  const resolver=this.resolver,result=await this.resources.audioResource(resolver,resref,type);
  if(this.closed||resolver!==this.resolver)throw new Error('Native audio resource request is stale');return result;
 }
 async talkString(ref,gender=0){
  if(this.closed||!this.resourceResult?.ready||!Number.isInteger(ref)||ref<0||ref>0xffffffff||![0,1].includes(gender))throw new Error('Native talk-table request is unavailable');
  if(ref!==0xffffffff&&this.world.tlkOverrides.has(ref))return{status:1,text:this.world.tlkOverrides.get(ref),sound:'',durationBits:0,gender};
  const value=await this.resources.talkString(ref,gender,this.resourceResult.resolved,d=>this.diagnose(d));if(this.closed)throw new Error('Native game session is closed');return value;
 }
 async getTalkTable(custom){
  if(this.closed||!this.resolver||typeof custom!=='boolean'||!this.resources.talkTableData)throw new Error('Native talk table is unavailable');const resolver=this.resolver,data=await this.resources.talkTableData(custom,this.resourceResult.resolved);if(this.closed||resolver!==this.resolver)throw new Error('Native talk table is stale');return data;
 }
 async creationModels(){if(this.closed||!this.resolver?.resourceNames||!this.resourceResult?.ready)throw new Error('Character creation models are unavailable');return this.resolver.resourceNames(RESOURCE_TYPE.MDL);}
  async creationPortraits(){if(this.closed||!this.resolver||!this.resourceResult?.ready)throw new Error('Character creation portraits are unavailable');return this.resolver.portraitNames?.()??[];}
 async creationPortraitAvailability(refs){
  if(this.closed||!this.resolver||!this.resourceResult?.ready)throw new Error('Character creation portrait catalog is unavailable');
  const resolver=this.resolver,result=await availableCreationPortraits(resolver,refs);
  if(this.closed||resolver!==this.resolver)throw new Error('Character creation portrait catalog is stale');return result;
 }
 async chat({areaId,areaGeneration,actorId,playerAccount,...request}){
  const actor=this.controlledActor(areaId,areaGeneration);if(actor.id!==actorId)throw new Error('Chat belongs to an old controlled creature');
  if(playerAccount!==undefined&&(request.channel!==4||typeof playerAccount!=='string'||this.world.players.get(request.playerId)?.name!==playerAccount))throw Error('That native Tell player has changed');
  await this.peer.sendGameMessage(chatRequest(request));return{sent:true};
 }
 async replyDialog({areaId,areaGeneration,entryId,replyId,abort=false}){
  this.controlledActor(areaId,areaGeneration);const dialog=this.dialog,choices=dialog?.replies;
  if(!choices||choices.entryId!==entryId||![true,false].includes(abort)||(!abort&&!choices.replies.some(r=>r.id===replyId)&&!(choices.replies.length===0&&replyId===0xffffffff)))throw new Error('Native dialog reply is stale or unavailable');
  // Native Escape chooses the first reply instead of aborting when the
  // secondary reply count equals one (6f81e0 / panel fieldbc0).
  if(abort&&choices.secondCount===1){replyId=choices.replies[0]?.id??0xffffffff;abort=false;}
  await this.peer.sendGameMessage(dialogReplyRequest({ownerId:dialog.ownerId,entryId,replyId:abort?0xffffffff:replyId,abort}));return{sent:true};
 }
 controlledActor(areaId,areaGeneration){
  const id=this.world.localObjectId,actor=this.world.registry.get(id);
  if(this.closed||this.phase!=='playing'||!this.areaReadySent||areaGeneration!==this.areaGeneration||areaId!==this.world.areaId||actor?.objectType!==5||actor.areaId!==areaId||actor.replicationRemoved)throw new Error('Native controlled creature is not ready for input');
  return actor;
 }
 async cancelAction({areaId,areaGeneration,actorId,actionId,groupId}){
  const actor=this.controlledActor(areaId,areaGeneration),packet=cancelActionRequest({actionId,groupId});
  if(actorId!==actor.id)throw new Error('Action cancellation belongs to an old controlled creature');
  if(!actor.playerState?.actionQueue?.some(e=>e.type===actionId&&e.group===groupId))return{sent:false,stale:true};
  await this.peer.sendGameMessage(packet);return{sent:true};
 }
 async inventoryWindow({areaId,areaGeneration,open,ownerId=this.world.localObjectId,inventoryRole='primary',windowSerial,inventoryReceipt}){
  const actor=this.controlledActor(areaId,areaGeneration);
  if(typeof open!=='boolean')throw new Error('Native inventory owner is unavailable');
  let token=null,rejected=null;
  if(inventoryRole==='alternate')token=this.world.inventoryWindows.requireAlternate(this.world,actor,ownerId,windowSerial,inventoryReceipt);
  else if(inventoryRole==='rejected'){
   rejected=this.world.inventoryWindows.rejected;
   if(open||!rejected||rejected.ownerId!==ownerId||rejected.receiptSerial!==inventoryReceipt||rejected.actorId!==actor.id||rejected.areaId!==this.world.areaId)throw Error('Native inventory rejection reply is retired');
  }else if(inventoryRole!=='primary'||ownerId!==actor.id)throw new Error('Native inventory owner is unavailable');
  await this.peer.sendGameMessage(inventoryWindowRequest({ownerId,open}));
  const current=this.controlledActor(areaId,areaGeneration);if(current.id!==actor.id)throw Error('Native inventory controlled actor changed');
  if(token){this.world.inventoryWindows.requireAlternate(this.world,current,ownerId,token.serial,token.receiptSerial);if(!open)this.world.inventoryWindows.closeAlternate(this.world,current,token);}
  if(rejected){if(this.world.inventoryWindows.rejected!==rejected)throw Error('Native inventory rejection reply changed');this.world.inventoryWindows.rejected=null;}
  return{sent:true};
 }
 async inventoryPanel({areaId,areaGeneration,panel,ownerId=this.world.localObjectId,inventoryRole='primary',windowSerial,inventoryReceipt}){
  const actor=this.controlledActor(areaId,areaGeneration),alternate=inventoryRole==='alternate';
  const token=alternate?this.world.inventoryWindows.requireAlternate(this.world,actor,ownerId,windowSerial,inventoryReceipt):null;
  if(!alternate&&(inventoryRole!=='primary'||ownerId!==actor.id))throw Error('Native inventory panel owner is unavailable');
  const packet=inventoryPanelRequest({panel,self:!alternate});this.world.clearRepositoryView(!alternate);await this.peer.sendGameMessage(packet);
  const current=this.controlledActor(areaId,areaGeneration);if(current.id!==actor.id)throw Error('Native inventory controlled actor changed');
  if(token)this.world.inventoryWindows.requireAlternate(this.world,current,ownerId,token.serial,token.receiptSerial);
  return{sent:true};
 }
 async assignQuickbar({areaId,areaGeneration,index,button}){
  const actor=this.controlledActor(areaId,areaGeneration),b=button??{type:0},normalized=Object.fromEntries(Object.keys(emptyQuickbarButton()).filter(k=>Object.hasOwn(b,k)).map(k=>[k,structuredClone(b[k])]));
  // The wire's omitted secondary-item field means OBJECT_INVALID. Reflect
  // that same value in the client-owned layout rather than retaining a zero
  // constructor field or a previous pair through Object.assign.
  if(b.type===1)normalized.secondaryItemId=b.secondaryItemId??OBJECT_INVALID;
  if(b.type===1)for(const id of [b.itemId,b.secondaryItemId??0x7f000000]){if(id===0x7f000000)continue;const item=this.world.registry.get(id),location=item?.inventoryLocation,existing=this.world.quickbar.some(q=>q.type===1&&(q.itemId===id||q.secondaryItemId===id));if(item?.objectType!==6||item.replicationRemoved||!(existing||location?.ownerId===actor.id&&['R','I'].includes(location.channel)))throw new Error('Native quickbar item is unavailable');}
  const packet=quickbarAssignmentRequest({index,button:normalized});await this.peer.sendGameMessage(packet);this.controlledActor(areaId,areaGeneration);
  // Native8602a0 sends after the local widget changes and suppresses sends
  // during server refresh. This is a client-owned shortcut layout, not a
  // fabricated server packet or a local gameplay action/result.
  this.world.applyQuickbar({entries:[{index,button:normalized,items:[]}]});return{sent:true,button:normalized};
 }
 async prepareSpell({areaId,areaGeneration,actorId,clear=false,...request}){
  const actor=this.controlledActor(areaId,areaGeneration);if(actorId!==actor.id||typeof clear!=='boolean')throw new Error('Native preparation belongs to an old controlled creature');
  await this.peer.sendGameMessage(clear?spellPreparationClearRequest(request):spellPreparationRequest(request));return{sent:true};
 }
 async rest({areaId,areaGeneration,actorId}){
  const actor=this.controlledActor(areaId,areaGeneration);if(actorId!==actor.id)throw new Error('Rest belongs to an old controlled creature');
  await this.peer.sendGameMessage(restRequest());return{sent:true};
 }
 async disengage({areaId,areaGeneration,actorId}){
  const actor=this.controlledActor(areaId,areaGeneration);if(actorId!==actor.id)throw Error('Disengage belongs to an old controlled creature');
  // Original world callback996250 calls attack writer7bf180 with INVALID.
  // Server6/2 owns action removal; sending is not an acknowledged combat result.
  await this.peer.sendGameMessage(attackRequest({targetId:OBJECT_INVALID}));return{sent:true,serverAcknowledged:false};
 }
 async cancelPolymorph({areaId,areaGeneration,actorId}){
  const actor=this.controlledActor(areaId,areaGeneration);if(actorId!==actor.id)throw Error('Cancel shape belongs to an old controlled creature');
  // Direct world9960c0→804cc0→7bf460. No quickbar index, local effect
  // removal or appearance prediction; the native server decides the result.
  await this.peer.sendGameMessage(cancelPolymorphRequest({actorId:actor.id}));return{sent:true,serverAcknowledged:false};
 }
 async selectScriptTarget({areaId,areaGeneration,actorId,version,targetId=OBJECT_INVALID,position}){
  const actor=this.controlledActor(areaId,areaGeneration),mode=this.world.scriptTargeting;
  if(actor.id!==actorId||!mode||mode.version!==version||mode.areaId!==areaId||mode.actorId!==actor.id)throw Error('Server target selection is stale');
  const target=targetId===OBJECT_INVALID?null:this.world.registry.get(targetId);
  const ownedItem=target?.objectType===6&&(target.equipmentOwnerId===actor.id||target.inventoryLocation?.ownerId===actor.id);
  if(targetId!==OBJECT_INVALID&&(!target||target.replicationRemoved||target.areaId!==areaId&&!ownedItem))throw Error('Server target is unavailable');
  if(!scriptTargetAllowed(mode,target))throw Error('Server target type is not allowed');
  const packet=scriptTargetSelectionRequest({targetId,position});this.world.scriptTargeting=null;await this.peer.sendGameMessage(packet);return{sent:true};
 }
 async nuiInput({token,serial,events=[],binds=[]}){
  const window=this.world.nui?.windows.get(token);if(this.closed||!this.resolver||!window||window.serial!==serial)throw Error('NUI input belongs to a closed or replaced window');
  if(!Array.isArray(events)||!Array.isArray(binds))throw Error('Invalid NUI input');
  const packet=nuiInputRequest({events:events.map(e=>({...e,token})),binds:binds.map(b=>({...b,token}))},{indexedBinds:satisfiesNativeBuild(this.serverBuild??this.build.build,{number:8193,revision:35,postfix:0})});
  // Apply before yielding: a server reply received during send may supersede
  // this input and must never be overwritten by a late local completion.
  // Native list edits carry the complete binding value plus a changed-row
  // index for the server watch callback. The native presentation opts into
  // wholeValue so optimistic state does not nest that array inside one row.
  for(const b of binds)this.world.nui.localBind(token,b.bind,b.value,b.wholeValue?-1:b.index??-1);
  await this.peer.sendGameMessage(packet);if(this.closed||this.world.nui.windows.get(token)?.serial!==serial)return{sent:true};if(events.some(e=>e.type==='close'))this.world.nui.apply({kind:'nui-destroy',token});return{sent:true};
 }
 levelUp({areaId,areaGeneration,actorId,operation,token,proposal}){
  const actor=this.controlledActor(areaId,areaGeneration);if(actor.id!==actorId)throw Error('Level-up belongs to an old controlled creature');
  if(operation==='cancel'){
   const world=this.world,peer=this.peer,draft=this.levelUpDraft;
   const includePosition=satisfiesNativeBuild(this.serverBuild??this.build.build,{number:8193,revision:35,postfix:0});
   return peer.sendGameMessage(levelUpCancelGuiRequest({includePosition})).then(()=>{
    if(this.world!==world||this.peer!==peer||this.controlledActor(areaId,areaGeneration)!==actor)throw Error('Level-up cancellation scope retired');
    // Closing the original summary does not revoke an already sent proposal.
    // Only its genuine result may resolve/retire that pending transaction.
    if(!this.pendingLevelUp&&this.levelUpDraft===draft)this.levelUpDraft=null;
    return{cancelled:true,sent:true,serverAcknowledged:false};
   });
  }
  if(this.pendingLevelUp||this.levelUpUncertain)throw Error('Waiting for the previous server level-up reply');
  let packet;
  if(operation==='begin'){if(!actor.playerState?.combat?.canLevelUp)throw Error('The server has not made level-up available');this.levelUpDraft=null;packet=levelUpBeginRequest();}
  else if(operation==='submit'){
   const draft=this.levelUpDraft,snapshot=networkLevelUpSnapshot(actor);
   if(!draft||token!==draft.token||draft.actorId!==actorId||draft.areaGeneration!==areaGeneration||JSON.stringify(snapshot)!==JSON.stringify(draft.snapshot))throw Error('Character changed; reopen Level Up');
   if(!draft.available[proposal?.classId])throw Error('The server has not made this class available');
   const schema=this.objectRules.classInfo?.(proposal.classId);if(!schema)throw Error('Level-up class rules are unavailable');
   packet=levelUpRequest(proposal,{level:snapshot.classes.reduce((n,c)=>n+c.level,0),skillCount:this.objectRules.skillCount,...schema});
  }else throw Error('Invalid level-up operation');
  return new Promise((resolve,reject)=>{const pending={operation,actorId,areaId,areaGeneration,resolve,reject};this.pendingLevelUp=pending;pending.timer=setTimeout(()=>{if(this.pendingLevelUp!==pending)return;this.levelUpUncertain=true;reject(Error('The server has not confirmed level-up; waiting for its reply'));},15000);Promise.resolve().then(async()=>{if(operation==='begin')await this.peer.sendGameMessage(characterSheetRequest({targetId:actor.id,page:0}));await this.peer.sendGameMessage(packet);}).catch(error=>{if(this.pendingLevelUp!==pending)return;clearTimeout(pending.timer);this.pendingLevelUp=null;reject(error);});});
 }
 async examine({areaId,areaGeneration,actorId,targetId}){
  const actor=this.controlledActor(areaId,areaGeneration),target=this.world.registry.get(targetId);if(actor.id!==actorId||!target||target.replicationRemoved||![5,6,7,9,10].includes(target.objectType)||!(target.areaId===areaId||target.objectType===6&&(target.inventoryLocation?.ownerId===actor.id||target.equipmentOwnerId===actor.id||target.inventoryLocation?.channel==='C'&&target.inventoryLocation.ownerId===this.world.containers.get('C')||target.inventoryLocation?.channel==='M'&&this.world.store?.open&&this.world.inventories.get('M')?.entries.some(v=>v.id===targetId)||this.world.barter?.open&&['A','B'].includes(target.inventoryLocation?.channel)&&this.world.inventories.get(target.inventoryLocation.channel)?.entries.some(v=>v.id===targetId))))throw new Error('Native examination target is stale or unavailable');
  await this.peer.sendGameMessage(examineRequest({targetId}));return{sent:true};
 }
 async mapInput({areaId,areaGeneration,actorId,operation,reference,position,text}){
  const actor=this.controlledActor(areaId,areaGeneration),area=this.world.registry.get(areaId)?.state;
  if(actor.id!==actorId||!area)throw Error('Native map owner is stale');
  const states=actor.playerState?.mapExploration?.[areaId]??[],visible=point=>{
   if(!Array.isArray(point)||point.length!==3||!point.every(Number.isFinite))return false;
   const x=Math.floor(point[0]/10),y=Math.floor(point[1]/10);return x>=0&&x<area.width&&y>=0&&y<area.height&&states[y*area.width+x]===1;
  };
  let packet;
  if(operation==='click'){
   const pin=this.world.mapPins.get(reference);if(!pin||!pin.enabled||!visible(pin.position))throw Error('Native server map pin is unavailable');
   packet=mapPinClickRequest({reference,includePosition:satisfiesNativeBuild(this.serverBuild??this.build.build,{number:8193,revision:35,postfix:0})});
  }else{
   if(operation==='add'){if(!visible(position))throw Error('Map notes require an explored map position');}
   else {const pin=area.playerMapPins?.find(pin=>(pin.index>>>0)===reference);if(!pin||!visible(pin.position))throw Error('Native personal map note is stale');if(operation==='change'&&(!Array.isArray(position)||position.some((n,i)=>Math.fround(n)!==Math.fround(pin.position[i]))))throw Error('Native map-note editor cannot move this note');}
   packet=mapNoteRequest({operation,reference,position,text});
  }
  await this.peer.sendGameMessage(packet);return{sent:true,serverAcknowledged:false};
 }
 async hudPanel({areaId,areaGeneration,actorId,panel,open,page=0,effectId,mode,playerId,targetId,skillId,featId,journalLifetime,guiPanelId,accessRevision,attemptSerial,sourceKind,position,recordActorLifetime,recordTargetLifetime}){
  const actor=this.controlledActor(areaId,areaGeneration);if(actorId!==actor.id||typeof open!=='boolean')throw new Error('Native panel request is stale');
  const recordWorld=this.world,recordPeer=this.peer,recordRequest={targetId,recordActorLifetime,recordTargetLifetime};let recordScope=null,recordRow=()=>true;
  const recordTarget=()=>{const next=nativeRecordTarget(recordWorld,actor,recordRequest);if(recordScope&&next.target!==recordScope.target)throw Error('Native character-record target has retired');recordScope=next;return next.target;};
  const assertRecordCurrent=()=>{if(!recordScope?.scoped)return;if(this.world!==recordWorld||this.peer!==recordPeer||this.controlledActor(areaId,areaGeneration)!==actor)throw Error('Native character-record session has retired');recordTarget();if(!recordRow())throw Error('Native character-record row has retired');};
  let packet;
  if(panel==='context-attempt'){
   const source=guiContextSource(sourceKind),world=this.world,peer=this.peer;
   if(!open||!source||guiPanelId!==source.panelId||!guiContextPosition(position)||sourceKind==='ground'&&targetId!==OBJECT_INVALID||sourceKind!=='ground'&&position.some(n=>n!==0)||!Number.isSafeInteger(accessRevision)||accessRevision!==world.guiPanelAccess.sequence||!Number.isSafeInteger(attemptSerial)||attemptSerial<=0)throw Error('Native world-context attempt is stale or unavailable');
   const target=sourceKind==='ground'?null:world.registry.get(targetId);
   if(sourceKind!=='ground'&&(!target||target.id!==targetId||target.objectType!==source.objectType||target.areaId!==areaId||target.replicationRemoved||target.destroyed))throw Error('Native world-context target is unavailable');
   if(!this.guiPanelAttempt||this.guiPanelAttempt.world!==world||this.guiPanelAttempt.peer!==peer||this.guiPanelAttempt.actor!==actor||this.guiPanelAttempt.areaGeneration!==areaGeneration)this.guiPanelAttempt={world,peer,actor,areaGeneration,last:0};
   if(attemptSerial<=this.guiPanelAttempt.last)throw Error('Native world-context attempt has retired');
   this.guiPanelAttempt.last=attemptSerial;
   const blocked=world.guiPanelAccess.matches(guiPanelId,targetId),includePosition=satisfiesNativeBuild(this.serverBuild??this.build.build,{number:8193,revision:35,postfix:0});
   await peer.sendGameMessage(blocked?guiPanelAttemptRequest({panelId:guiPanelId,targetId,includePosition}):guiContextOpenRequest({sourceKind,targetId,position,includePosition}));
   if(this.peer!==peer||this.world!==world||this.controlledActor(areaId,areaGeneration)!==actor||target&&(world.registry.get(targetId)!==target||target.objectType!==source.objectType||target.areaId!==areaId||target.replicationRemoved||target.destroyed))throw Error('Native world-context owner has retired');
   return{sent:true,blocked,serverAcknowledged:false};
  }else if(panel==='blocked-attempt'){
   const displayed=guiPanelId===8?recordTarget():null;
   if(!open||![5,6,7,8].includes(guiPanelId)||targetId!==(guiPanelId===8?displayed.id:OBJECT_INVALID)||!Number.isSafeInteger(accessRevision)||accessRevision!==this.world.guiPanelAccess.sequence||!this.world.guiPanelAccess.matches(guiPanelId,targetId)||!Number.isSafeInteger(attemptSerial)||attemptSerial<=0)throw Error('Native blocked-panel attempt is stale or unavailable');
   const world=this.world,peer=this.peer;
   if(!this.guiPanelAttempt||this.guiPanelAttempt.world!==world||this.guiPanelAttempt.peer!==peer||this.guiPanelAttempt.actor!==actor||this.guiPanelAttempt.areaGeneration!==areaGeneration)this.guiPanelAttempt={world,peer,actor,areaGeneration,last:0};
   if(attemptSerial<=this.guiPanelAttempt.last)throw Error('Native blocked-panel attempt has retired');
   this.guiPanelAttempt.last=attemptSerial;
   await peer.sendGameMessage(guiPanelAttemptRequest({panelId:guiPanelId,targetId,includePosition:satisfiesNativeBuild(this.serverBuild??this.build.build,{number:8193,revision:35,postfix:0})}));
   if(this.peer!==peer||this.world!==world||this.controlledActor(areaId,areaGeneration)!==actor)throw Error('Native blocked-panel owner has retired');
   assertRecordCurrent();
   return{sent:true};
  }else if(panel==='journal'&&journalLifetime!==undefined){
   const peer=this.peer,world=this.world,policy=this.nativeJournalEvents??=new NativeJournalEvents();
   return policy.transition({open,journalLifetime,includePosition:satisfiesNativeBuild(this.serverBuild??this.build.build,{number:8193,revision:35,postfix:0}),scope:{world,peer,actor,areaId,areaGeneration}},{
    assertCurrent:()=>{if(this.peer!==peer||this.world!==world||actor.id!==actorId||this.controlledActor(areaId,areaGeneration)!==actor)throw Error('Native journal owner or scope has retired');},
    send:packet=>peer.sendGameMessage(packet)
   });
  }else if(panel==='skill'){
   const displayed=recordTarget();recordRow=()=>displayed.inventoryStats?.skills?.some(row=>row.index===skillId&&row.flag);
   if(!open||targetId!==displayed.id||!Number.isInteger(skillId)||skillId<0||skillId>65535||!recordRow())throw Error('That native skill row is no longer present');
   packet=skillDescriptionGuiRequest({skillId,targetId,includePosition:satisfiesNativeBuild(this.serverBuild??this.build.build,{number:8193,revision:35,postfix:0})});
  }else if(panel==='feat'){
   const displayed=recordTarget();recordRow=()=>nativeRecordFeatPresent(displayed,featId);
   if(!open||targetId!==displayed.id||!Number.isInteger(featId)||featId<0||featId>65535)throw Error('That native feat row is no longer present');
   // Match native record_entries' raw primary/secondary precedence exactly.
   // Empty authoritative lists suppress fallbacks. Successor/table admission
   // stays in native GameUiRules; transport only checks disclosed membership.
   if(!recordRow())throw Error('That native feat row is no longer present');
   packet=featDescriptionGuiRequest({featId,targetId,includePosition:satisfiesNativeBuild(this.serverBuild??this.build.build,{number:8193,revision:35,postfix:0})});
  }else if(panel==='effect'){
   if(!open||!Number.isInteger(effectId)||effectId<0||effectId>65535||!Object.hasOwn(actor.playerState?.effectIcons??{},effectId))throw Error('That native effect icon is no longer present');
   packet=effectIconGuiRequest({effectId,includePosition:satisfiesNativeBuild(this.serverBuild??this.build.build,{number:8193,revision:35,postfix:0})});
  }else if(panel==='chat-reply'){
   const player=this.world.players.get(playerId);if(!open||!Number.isInteger(playerId)||!player||targetId!==(player.objectId??OBJECT_INVALID))throw Error('That native chat reply player is no longer available');
   packet=chatReplyGuiRequest({targetId,includePosition:satisfiesNativeBuild(this.serverBuild??this.build.build,{number:8193,revision:35,postfix:0})});
  }else if(panel==='chat-focus')packet=chatFocusGuiRequest({mode,focused:open,includePosition:satisfiesNativeBuild(this.serverBuild??this.build.build,{number:8193,revision:35,postfix:0})});
  else if(panel==='character'){const displayed=recordTarget();if(recordScope.foreign&&open&&(!Number.isInteger(page)||page<0||page>2))throw Error('Native character-record page is unavailable');packet=characterSheetRequest({targetId:displayed.id,page:open?page:-1});}
  else packet=panel==='journal'?journalWindowRequest(open):null;if(!packet)throw new Error('Unsupported native panel request');
  await (recordScope?.scoped?recordPeer:this.peer).sendGameMessage(packet);assertRecordCurrent();return{sent:true};
 }
 async playerAttitude({areaId,areaGeneration,actorId,playerId,likes}){
  const actor=this.controlledActor(areaId,areaGeneration),player=this.world.players.get(playerId);if(actorId!==actor.id||!player||player.isDM||player.objectId===actor.id||player.character?.id===actor.id)throw new Error('Native player attitude target is stale');
  const targetId=player.character?.id;if(!Number.isInteger(targetId)||targetId===OBJECT_INVALID)throw Error('That player character is not yet available');
  await this.peer.sendGameMessage(playerAttitudeRequest({targetId,likes}));return{sent:true,serverAcknowledged:false};
 }
 async playerListInput({areaId,areaGeneration,actorId,operation,playerId,targetId}){
  const actor=this.controlledActor(areaId,areaGeneration),player=this.world.players.get(playerId);
  if(actorId!==actor.id||!player||player.isDM||player.objectId===actor.id||player.character?.id===actor.id||!['select','tell'].includes(operation))throw Error('Native player-list selection is stale');
  const expected=operation==='tell'?player.objectId:player.character?.id;
  if(!Number.isInteger(expected)||expected===OBJECT_INVALID||targetId!==expected)throw Error('Native player-list target changed');
  const includePosition=satisfiesNativeBuild(this.serverBuild??this.build.build,{number:8193,revision:35,postfix:0});
  await this.peer.sendGameMessage(playerListGuiRequest({operation,targetId,includePosition}));return{sent:true,serverAcknowledged:false};
 }
 async partyChatInput({areaId,areaGeneration,actorId,operation,playerId,playerAccount,targetId}){
  const actor=this.controlledActor(areaId,areaGeneration);if(actorId!==actor.id)throw Error('Native chat party owner is stale');
  if(operation==='accept'){if(targetId!==OBJECT_INVALID||playerId!==undefined||playerAccount!==undefined)throw Error('Invalid native chat acceptance');}
  else if(operation==='invite'){
   const player=this.world.players.get(playerId);if(!Number.isInteger(playerId)||!player||typeof playerAccount!=='string'||player.name!==playerAccount||targetId!==(player.character?.id??OBJECT_INVALID))throw Error('Native chat invitation target changed');
  }else throw Error('Unsupported native chat party operation');
  await this.peer.sendGameMessage(partyRequest({operation,targetId}));return{sent:true,serverAcknowledged:false};
 }
 async partyInput({areaId,areaGeneration,actorId,operation,playerId,targetId}){
  const actor=this.controlledActor(areaId,areaGeneration);if(actorId!==actor.id)throw Error('Native party owner is stale');
  const flags=actor.replicated?.party??{};let target;
  if(operation==='list'){if(playerId!==undefined||targetId!==undefined)throw Error('Party-list refresh has no target');}
  else if(['accept','reject','ignore'].includes(operation)){
   target=flags.field7D8;if(![true,1].includes(flags.field7DC)||!Number.isInteger(target)||target===OBJECT_INVALID||targetId!==target)throw Error('That party invitation is no longer current');
  }else if(operation==='leave'){
   // Original888c30 sends the selected player's +38 identity without consulting
   // the separately replicated singleton flag. Server45b4a0 acts on the sender.
   // A party-list update can precede the creature flags; do not reject a visible
   // Leave action merely because that second packet has not arrived yet.
   if(playerId===undefined&&targetId===undefined)target=actor.id;
   else{
    const player=this.world.players.get(playerId);target=player?.character?.id;
    if(!player||player.isDM||!Number.isInteger(target)||target===OBJECT_INVALID||targetId!==target)throw Error('Native party target is stale');
   }
  }else if(['invite','kick','transfer'].includes(operation)){
   const player=this.world.players.get(playerId);target=player?.character?.id;
   if(!player||player.isDM||target===actor.id||targetId!==target||!Number.isInteger(target)||target===OBJECT_INVALID)throw Error('Native party target is stale');
   const member=this.world.party.some(row=>row.id===target);
   if(operation==='invite'&&member)throw Error('That player is already in your group');
   if(operation!=='invite'&&(!member||![true,1].includes(flags.leader)))throw Error('Only the current group leader can perform that action');
  }else throw Error('Unsupported native party operation');
  await this.peer.sendGameMessage(partyRequest({operation,...(target!==undefined?{targetId:target}:{})}));return{sent:true,serverAcknowledged:false};
 }
 async castSpell({areaId,areaGeneration,spellId,classIndex=0,domainLevel=0,metamagic=0,spontaneous=false,targetId=OBJECT_INVALID,position=[0,0,0]}){
  const actor=this.controlledActor(areaId,areaGeneration),spell=this.objectRules.spellInputInfo?.(spellId);if(!spell)throw new Error('Native spell input metadata is unavailable');
  this.validateCastTarget(areaId,actor,targetId);
  await this.peer.sendGameMessage(spellCastRequest({spellId,classIndex,domainLevel,metamagic,spontaneous,targetId,position,targetType:spell.targetType}));return{sent:true};
 }
 validateCastTarget(areaId,actor,targetId){if(targetId!==OBJECT_INVALID){const target=this.world.registry.get(targetId),ownedItem=target?.objectType===6&&(target.inventoryLocation?.ownerId===actor.id||this.world.quickbar.some(b=>b.type===1&&(b.itemId===targetId||b.secondaryItemId===targetId)));if(!target||target.replicationRemoved||!(target.areaId===areaId||ownedItem))throw new Error('Native spell target is unavailable');}}
 async useItem({areaId,areaGeneration,itemId,propertyIndex,variant=255,targetId=OBJECT_INVALID,position=[0,0,0]}){
  const actor=this.controlledActor(areaId,areaGeneration),item=this.world.registry.get(itemId),location=item?.inventoryLocation,shortcut=this.world.quickbar.some(b=>b.type===1&&b.itemId===itemId);
  if(item?.objectType!==6||item.replicationRemoved||!(shortcut||location?.ownerId===actor.id&&['R','I'].includes(location.channel)))throw new Error('Native item-use source is unavailable');
  this.validateCastTarget(areaId,actor,targetId);
  await this.peer.sendGameMessage(itemUseRequest({itemId,propertyIndex,variant,targetId,position}));return{sent:true};
 }
 async castSpellLike({areaId,areaGeneration,spellId,casterLevel,targetId=OBJECT_INVALID,position=[0,0,0]}){
  const actor=this.controlledActor(areaId,areaGeneration);if(!this.objectRules.spellInputInfo?.(spellId))throw new Error('Native innate spell metadata is unavailable');this.validateCastTarget(areaId,actor,targetId);await this.peer.sendGameMessage(spellLikeCastRequest({spellId,casterLevel,targetId,position}));return{sent:true};
 }
 async useFeat({areaId,areaGeneration,featId,auxiliary=0,targetId=OBJECT_INVALID,position=null}){
  const actor=this.controlledActor(areaId,areaGeneration);if(!this.objectRules.featInputInfo?.(featId))throw new Error('Native feat input metadata is unavailable');this.validateCastTarget(areaId,actor,targetId);await this.peer.sendGameMessage(featUseRequest({featId,auxiliary,targetId,position}));return{sent:true};
 }
 async changeMode({areaId,areaGeneration,modeId,targetId=OBJECT_INVALID}){
  const actor=this.controlledActor(areaId,areaGeneration);if(modeId===5)this.validateCastTarget(areaId,actor,targetId);await this.peer.sendGameMessage(modeChangeRequest({modeId,targetId}));return{sent:true};
 }
 async possessFamiliar({areaId,areaGeneration}){this.controlledActor(areaId,areaGeneration);await this.peer.sendGameMessage(possessFamiliarRequest());return{sent:true};}
 async associateCommand({areaId,areaGeneration,actorId,targetId,command}){
  const actor=this.controlledActor(areaId,areaGeneration),target=this.world.registry.get(targetId);
  if(actorId!==actor.id)throw new Error('Associate command belongs to an old controlled creature');
  if(target?.objectType!==5||target.replicationRemoved)throw new Error('Native associate command target is unavailable');
  await this.peer.sendGameMessage(associateCommandRequest({targetId,command}));return{sent:true};
 }
 async quickChat({areaId,areaGeneration,actorId,quickChat}){
  const actor=this.controlledActor(areaId,areaGeneration);if(actorId!==actor.id)throw new Error('Quick chat belongs to an old controlled creature');
  await this.peer.sendGameMessage(quickChatRequest({quickChat}));return{sent:true};
 }
 async activateQuickbar({areaId,areaGeneration,index}){
  const actor=this.controlledActor(areaId,areaGeneration);if(!Number.isInteger(index)||index<0||index>=36)throw new Error('Invalid native quickbar index');const b=this.world.quickbar[index];
  if(b.type===43){await this.peer.sendGameMessage(cancelPolymorphRequest({actorId:actor.id}));return{sent:true};}
  if(b.type===38){await this.peer.sendGameMessage(possessFamiliarRequest());return{sent:true};}
  if(b.type===42){await this.peer.sendGameMessage(quickChatRequest({quickChat:b.intParam&65535}));return{sent:true};}
  if(b.type===39){const request=networkAssociateShortcut(b,actor);if(request)await this.peer.sendGameMessage(associateCommandRequest(request));return{sent:Boolean(request)};}
  // Original item widget85bec0 opens containers first; only equipable items
  // with property WORD255 route through805500 -> native12/11. A default
  // packed value alone does not make a potion/container an equipment action.
  const info=b.type===1?this.objectRules.quickbarItemInfo?.(this.world.registry.get(b.itemId)?.item?.baseItem):null;
  if(b.type===1&&info?.container===0&&info.equipableSlots!==0&&(b.intParam&65535)===255){for(const id of [b.itemId,b.secondaryItemId??OBJECT_INVALID]){if(id===OBJECT_INVALID)continue;const item=this.world.registry.get(id);if(item?.objectType!==6||item.replicationRemoved)throw new Error('Native shortcut item is unavailable');}await this.peer.sendGameMessage(toggleItemEquipmentRequest({itemId:b.itemId,secondId:b.secondaryItemId??OBJECT_INVALID}));return{sent:true};}
  if(b.type===1&&info?.container!==0&&info?.container!==undefined){const item=this.world.registry.get(b.itemId);if(item?.inventoryLocation?.ownerId!==actor.id)throw new Error('Native shortcut container is unavailable');await this.peer.sendGameMessage(useObjectRequest({targetId:b.itemId,flag0:false,flag1:false}));return{sent:true};}
  this.diagnose({code:'network.quickbar-action-unhandled',reason:'Native quickbar activation request is not connected',index,type:b.type,parameter:b.intParam});throw new Error('This shortcut action is not connected yet');
 }
 async playEmote({areaId,areaGeneration,actorId,animation,position,duration,voice=65535}){
  const actor=this.controlledActor(areaId,areaGeneration);if(actor.id!==actorId||!Number.isInteger(voice)||voice<0||voice>65535)throw Error('Native emote belongs to an old controlled creature');
  await this.peer.sendGameMessage(emoteAnimationRequest({actorId,animation,position,duration}));
  if(voice!==65535)await this.peer.sendGameMessage(quickChatRequest({quickChat:voice}));return{sent:true};
 }
 async storeInput({areaId,areaGeneration,actorId,storeGeneration,operation,itemId,panel,page,x,y}){
  const actor=this.controlledActor(areaId,areaGeneration),store=this.world.store,item=this.world.registry.get(itemId),location=item?.inventoryLocation;
  if(actor.id!==actorId||!store?.open||store.generation!==storeGeneration)throw new Error('Native store request is stale');
  if(['buy','sell','identify'].includes(operation)){
   const owned=location?.ownerId===actor.id&&['R','I'].includes(location.channel),stock=location?.channel==='M'&&this.world.inventories.get('M')?.entries.some(v=>v.id===itemId);
   if(item?.objectType!==6||item.replicationRemoved||!(operation==='buy'?stock:owned))throw new Error('Native store item is unavailable');
  }else if(operation==='panel'){if(!Number.isInteger(panel)||panel<0||panel>=5)throw new Error('Invalid native store panel');}
  else if(operation==='page'){const count=this.world.inventories.get('M')?.pageCount??1;if(!Number.isInteger(page)||page<0||page>=count)throw new Error('Invalid native store page');}
  else if(operation!=='close')throw new Error('Invalid native store operation');
  await this.peer.sendGameMessage(storeRequest({operation,itemId,panel,page,x,y}));
  // Original Identify callback140898d30 sends7/7 followed by a fresh6/5
  // examination. No local identification/property/gold prediction is made.
  if(operation==='identify')await this.examine({areaId,areaGeneration,actorId,targetId:itemId});
  // Only GUI navigation is local. Gold, items and transaction outcomes remain
  // server-owned. No store OBJECT_ID is fabricated from the speaking NPC.
  if(operation==='close')this.world.apply({kind:'store-close'});
  else if(operation==='panel'||operation==='page'){this.world.inventories.get('M').entries=[];if(operation==='panel'){store.panel=panel;store.page=0;}else store.page=page;}
  return{sent:true};
 }
 async containerInput({areaId,areaGeneration,actorId,targetId,operation}){
  const actor=this.controlledActor(areaId,areaGeneration);if(actor.id!==actorId||!Number.isInteger(targetId)||targetId!==this.world.containers.get('C')||targetId===OBJECT_INVALID)throw new Error('Native container request is stale');
  const packet=containerRequest({operation});if(operation!=='close')this.world.clearContainerView();await this.peer.sendGameMessage(packet);if(operation==='close'&&this.world.containers.get('C')===targetId)this.world.apply({kind:'container-status',targetId:OBJECT_INVALID,primary:1});return{sent:true};
 }
 async barterInput({areaId,areaGeneration,actorId,serial,operation,targetId=OBJECT_INVALID,itemId=OBJECT_INVALID,value=false,x=255,y=255}){
  const actor=this.controlledActor(areaId,areaGeneration),state=this.world.barter;
  if(actor.id!==actorId)throw Error('Native barter belongs to an old controlled creature');
  if(operation==='start'){
   const target=this.world.registry.get(targetId),item=this.world.registry.get(itemId);
   if(target?.objectType!==5||target.areaId!==areaId||target.replicationRemoved)throw Error('Native barter target is unavailable');
   if(itemId!==OBJECT_INVALID&&(item?.inventoryLocation?.ownerId!==actor.id||item.inventoryLocation.channel!=='R'||item.replicationRemoved))throw Error('Native barter item is unavailable');
  }else{
   if(!state||state.serial!==serial||state.actorId!==actorId||state.areaId!==areaId||!state.open&&!(operation==='window'&&!value)||targetId!==OBJECT_INVALID&&targetId!==state.partnerId)throw Error('Native barter view is stale');
   if(['add','remove','move'].includes(operation)){
    const item=this.world.registry.get(itemId),channel=operation==='add'?'R':'B';
    if(state.ownLocked||item?.inventoryLocation?.ownerId!==actor.id||item.inventoryLocation.channel!==channel||item.replicationRemoved||!this.world.inventories.get(channel)?.entries.some(e=>e.id===itemId))throw Error('Native barter item selection is stale or locked');
   }else if(operation==='accept'&&(!state.ownLocked||!state.otherLocked))throw Error('Both native barter offers must be locked');
  }
  await this.peer.sendGameMessage(barterRequest({operation,targetId,itemId,value,x,y}));return{sent:true};
 }
 async transferGold({areaId,areaGeneration,actorId,targetId=OBJECT_INVALID,amount,position,placement=false,x=0,y=0,barterSerial}){
  const actor=this.controlledActor(areaId,areaGeneration),balance=actor.playerState?.combat?.field898;
  if(actorId!==actor.id||!Number.isInteger(balance)||!Number.isInteger(amount)||amount<=0||amount>balance)throw Error('Native gold selection is stale');
  if(targetId!==OBJECT_INVALID){
   const target=this.world.registry.get(targetId),container=this.world.containers.get('C'),location=target?.inventoryLocation,ownedContainer=target?.objectType===6&&(container!==undefined&&container!==OBJECT_INVALID&&targetId===container||location?.ownerId===actor.id&&['R','I'].includes(location.channel)||container!==undefined&&container!==OBJECT_INVALID&&location?.channel==='C'&&location.ownerId===container);
   if(!target||target.replicationRemoved||!ownedContainer&&target.areaId!==areaId||![5,6,9].includes(target.objectType)||target.objectType===6&&!this.objectRules.quickbarItemInfo?.(target.item?.baseItem)?.container)throw Error('Native gold destination is unavailable');
   if(placement&&(!this.world.barter?.open||this.world.barter.serial!==barterSerial||this.world.barter.partnerId!==targetId||this.world.barter.ownLocked))throw Error('Native gold barter placement is stale or locked');
  }else if(placement)throw Error('Native gold ground placement is unavailable');
  await this.peer.sendGameMessage(goldTransferRequest({targetId,amount,position,placement,x,y}));return{sent:true};
 }
 async itemAction({areaId,areaGeneration,itemId,operation,slot,x=255,y=255,position,destinationId,amount}){
  const actor=this.controlledActor(areaId,areaGeneration),item=this.world.registry.get(itemId),location=item?.inventoryLocation;
  if(item?.objectType!==6||item.replicationRemoved)throw new Error('Native item is unavailable');
  const equipped=item.equipmentOwnerId===actor.id,owned=equipped||location?.ownerId===actor.id&&['R','I'].includes(location.channel),container=this.world.containers.get('C'),fromContainer=container!==undefined&&container!==OBJECT_INVALID&&location?.channel==='C'&&location.ownerId===container;destinationId??=actor.id;if(destinationId!==actor.id&&(destinationId!==container||container===OBJECT_INVALID||container===undefined))throw new Error('Native destination container is not open');let packet;
  if(operation==='pickup'){
   if(owned||item.equipmentOwnerId!=null||!fromContainer&&item.areaId!==areaId)throw new Error('Native pickup item is unavailable');
   packet=pickupItemRequest({itemId,destinationId:actor.id,x,y});
  }else{
   const ownedContainer=fromContainer&&this.world.registry.get(container)?.inventoryLocation?.ownerId===actor.id;
   if(!owned&&!(fromContainer&&operation==='move')&&!(ownedContainer&&operation==='split'))throw new Error('Native inventory item is unavailable');
   if(operation==='learn')packet=learnScrollRequest({itemId});
   else if(operation==='split'){
    if(!Number.isInteger(amount)||amount<1||amount>Math.min(65535,item.item.stackSize??item.item.field454??0))throw Error('Native item split amount is unavailable');
    packet=splitItemRequest({itemId,amount});
   }else if(operation==='toggle')packet=toggleItemEquipmentRequest({itemId});
   else if(operation==='equip'){
    if(!Number.isInteger(slot)||slot<=0||slot>0x20000||(slot&(slot-1))!==0)throw new Error('Native equipment slot is unavailable');
    packet=equipItemRequest({itemId,slot,destinationId:actor.id});
   }else if(operation==='unequip'){
    if(!equipped)throw new Error('Native equipped item is unavailable');
    packet=unequipItemRequest({itemId,destinationId,x,y});
   }else if(operation==='move'){
    if(location.channel!=='R'&&!fromContainer)throw new Error('Native repository item is unavailable');
    packet=moveItemRequest({itemId,destinationId,x,y});
   }else if(operation==='drop')packet=dropItemRequest({itemId,position:position??actor.replicated.position});
   else throw new Error('Native item action is unavailable');
  }
  // Native server455f50 queues the action. No local CanUseItem, cursed-item,
  // slot fit, ownership transfer, stack split, equip or drop is performed.
  await this.peer.sendGameMessage(packet);return{sent:true};
 }
 async interact({areaId,areaGeneration,targetId,action,run=true,position=null}){
  const actor=this.controlledActor(areaId,areaGeneration);
  const target=this.world.registry.get(targetId),ownedItem=action==='object.use'&&target?.objectType===6&&target.inventoryLocation?.ownerId===actor.id;
  if(!target||!ownedItem&&target.areaId!==areaId||target.replicationRemoved)throw new Error('Native interaction target is unavailable');
  let packet;
  if(action==='trigger.transition'){
   // Legacy frontend approach geometry is optional, not a protocol startup
   // dependency. Native frontends will supply their native-selected approach
   // through the separate input adapter; this fallback preserves old behavior.
   if(target.objectType!==7||!target.replicated?.hasTransition||target.replicated?.isTrap)throw Error('Native transition trigger is unavailable');
   let destination=position;
   if(destination===null){const {networkTriggerSurface}=await import('../src/network_trigger.js');destination=networkTriggerSurface(target)?.destination;}
   if(!Array.isArray(destination)||destination.length!==3||!destination.every(Number.isFinite))throw Error('Native transition trigger approach is unavailable');
   // Client click1406f02c0 copies the non-trap trigger ID at1406f0660,
   // passes it at1406f0cf3 to ground input1406f3650, and its waypoint sender
   //1407c0970 retains that target. Walking into the polygon without this ID
   // does not request the server's transition action.
   const sequence=((this.movementSequences.get(actor.id)??0)+1)&255;
   this.movementSequences.set(actor.id,sequence);
   packet=walkToWaypointRequest({areaId,position:destination,targetId:target.id,sequence,run,clientPath:false,fractional:0});
  }else if(action==='door.open'||action==='door.close'){
   if(target.objectType!==10)throw new Error('Native door target is unavailable');
   packet=doorActionRequest({targetId,action:action==='door.open'?21:22});
  }else if(action==='door.transition'){
   const state=networkDoorClickState(target);
   if(target.objectType!==10||state===null||state===0||!target.replicated?.hasTransition)throw new Error('Native door transition is unavailable');
   // Original click wrappers6efca0/6efec0 send the door position/ID with
   // sequence0 and no client path. Native server action processing owns
   // approach, transition scripts and any resulting area change.
   packet=walkToWaypointRequest({areaId,position:target.replicated.position,targetId,sequence:0,run,clientPath:false,fractional:0});
  }else if(action==='conversation.start')packet=talkToRequest({targetId});
  else if(action==='object.use')packet=useObjectRequest({targetId,flag0:false,flag1:target.objectType===9});
  else if(action==='combat.attack')packet=attackRequest({targetId});
  else throw new Error('Native interaction request is not implemented');
  await this.peer.sendGameMessage(packet);return{sent:true};
 }
 async walkTo({areaId,areaGeneration,position,run=true}){
  const {id}=this.controlledActor(areaId,areaGeneration);
  // Client initializer1407fb4b2 zeroes sequence2d2/last-sent2d3. Ground
  // input1406f3650 increments the BYTE before calling the packet sender.
  const sequence=((this.movementSequences.get(id)??0)+1)&255;
  const packet=walkToWaypointRequest({areaId,position,sequence,run,clientPath:false,fractional:0});
  // No client-computed path is advertised: authoritative updates own motion.
  // Sequence is presentation/request state, never a new object identity.
  this.movementSequences.set(id,sequence);await this.peer.sendGameMessage(packet);return{sequence};
 }
 async keyboardMove({areaId,areaGeneration,actorId,operation,position,heading,flags,transmit=true}){
  const actor=this.controlledActor(areaId,areaGeneration);
  if(actor.id!==actorId)throw new Error('Keyboard input belongs to an old controlled creature');
  let packet,sequence;
  if(operation==='drive'){
   if(typeof transmit!=='boolean')throw new Error('Invalid native drive transmission flag');
   sequence=((this.movementSequences.get(actor.id)??0)+1)&255;
   packet=driveControlRequest({areaId,position,heading,flags,sequence});this.movementSequences.set(actor.id,sequence);
  }else if(operation==='stop')packet=abortDriveRequest();
  else if(operation==='turn')packet=driveOrientationRequest({orientation:position});
  else throw new Error('Invalid native keyboard operation');
  if(operation!=='drive'||transmit)await this.peer.sendGameMessage(packet);return{sent:operation!=='drive'||transmit,...(sequence===undefined?{}:{sequence})};
 }
 exportCharacter(){
  if(this.closed||!['playing','area-loading'].includes(this.phase)||!this.characterConfirmed||!this.persistCharacter)throw new Error('Native character export is unavailable');
  if(this.characterExportPromise)return this.characterExportPromise;
  if(this.exportUncertain)throw new Error('The previous character export is still awaiting its server reply');
  let pending;const reply=new Promise((resolve,reject)=>{pending={resolve,reject};});this.pendingCharacterExport=pending;
  pending.timer=setTimeout(()=>{if(this.pendingCharacterExport!==pending)return;this.pendingCharacterExport=null;this.exportUncertain=true;this.diagnose({code:'network.character-export-timeout',reason:'The server character export did not arrive before the save deadline'});pending.reject(new Error('Timed out waiting for the server character export; the connection remains open'));},this.characterExportTimeoutMs);
  Promise.resolve().then(()=>this.peer.sendGameMessage(characterExportRequest())).catch(error=>{if(this.pendingCharacterExport!==pending)return;clearTimeout(pending.timer);this.pendingCharacterExport=null;pending.reject(error);});
  this.characterExportPromise=reply.finally(()=>{this.characterExportPromise=null;});return this.characterExportPromise;
 }
 disconnect(){
  if(this.disconnectPromise)return this.disconnectPromise;
  // Mark closed immediately, so outstanding resource I/O cannot upload or
  // publish state after cancellation. Peer cleanup has its own serial queue.
  this.finish();this.disconnectPromise=Promise.resolve().then(()=>this.peer.disconnect());return this.disconnectPromise;
 }
 finish(){
  if(this.closed)return;this.portalTransfer.dispose();if(this.pendingLevelUp){clearTimeout(this.pendingLevelUp.timer);this.pendingLevelUp.reject(Error('Connection closed before level-up completed'));this.pendingLevelUp=null;}this.levelUpDraft=null;this.closed=true;this.phase='closed';this.resources.close?.();if(this.pendingCharacterExport){clearTimeout(this.pendingCharacterExport.timer);this.pendingCharacterExport.reject(new Error('Connection closed before the character export completed'));this.pendingCharacterExport=null;}this.character?.fill(0);this.character=null;this.resolver=null;this.objectRules={};this.identity.dispose();this.build.dispose();this.emit('state',this.state());this.emit('closed');
 }
}
