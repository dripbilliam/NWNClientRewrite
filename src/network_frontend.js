import {networkSystemNotices} from './network_system_notices.js';
import {NetworkWorld} from './network_world.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {NetworkText} from './network_text.js';
import {parse2da} from './area.js';
import {RESOURCE_TYPE,decodeResourceText} from './resource_archive.js';
import {NetworkLobby} from './network_lobby.js';

// Narrow application requests; no local game simulation is attached here.
export class NetworkFrontend {
 constructor({bridge,canEnter,onEnter,onExit,onArea,onUpdates,onState,onMovementSent=()=>{},onCreateCharacter=null,onDialog=()=>{},onInventoryResult=()=>{},onProjectile=()=>{},onObjectVisual=()=>{},onAreaVisual=()=>{},onQuickbar=()=>{},onParty=()=>{},onCamera=()=>{},onHud=()=>{},onAudio=()=>{}}){
  Object.assign(this,{bridge,canEnter,onEnter,onExit,onArea,onUpdates,onState,onMovementSent,onCreateCharacter,onDialog,onInventoryResult,onProjectile,onObjectVisual,onAreaVisual,onQuickbar,onParty,onCamera,onHud,onAudio});this.id=null;this.queue=Promise.resolve();
  this.button=document.querySelector('#multiplayer-button');this.dialog=document.querySelector('#multiplayer-dialog');this.form=this.dialog.querySelector('form');this.status=document.querySelector('#multiplayer-status');
  this.button.disabled=!bridge;
  this.dialog.addEventListener('close',()=>{this.form.elements.cdkey.value='';this.form.elements.password.value='';});
  this.lobby=bridge?.serverCharacters?new NetworkLobby(this):null;
  if(this.lobby)for(const field of ['character','savedCharacter']){const control=this.form.elements[field];if(control?.closest('label'))control.closest('label').hidden=true;}
  this.button.addEventListener('click',()=>{if(this.lobby&&!this.id){void this.lobby.showBrowser();return;}this.dialog.showModal();void this.refreshSavedCharacters().catch(e=>this.showError(e));});
  document.querySelector('#multiplayer-cancel').addEventListener('click',()=>this.dialog.close());
  document.querySelector('#multiplayer-disconnect').addEventListener('click',()=>{void this.disconnect().catch(e=>this.showError(e));});
  this.exportButton=document.querySelector('#multiplayer-export');this.forceDisconnect=document.querySelector('#multiplayer-disconnect-unsaved');this.characterStatus=document.querySelector('#multiplayer-character-status');
  this.exportButton?.addEventListener('click',()=>{void this.saveCharacter().catch(e=>this.showError(e));});
  this.forceDisconnect?.addEventListener('click',()=>{void this.disconnect({saveCharacter:false}).catch(e=>this.showError(e));});
  this.form.elements.savedCharacter?.addEventListener('change',()=>{this.savedRefresh=(this.savedRefresh??0)+1;if(this.form.elements.savedCharacter.value)this.form.elements.character.value='';});
  this.form.elements.character.addEventListener('change',()=>{this.savedRefresh=(this.savedRefresh??0)+1;if(this.form.elements.character.files[0]&&this.form.elements.savedCharacter)this.form.elements.savedCharacter.value='';});
  document.querySelector('#multiplayer-install').addEventListener('click',()=>{void bridge.chooseInstall().then(r=>{if(r.selected)this.status.textContent='Installation selected';}).catch(e=>this.showError(e));});
  this.form.addEventListener('submit',event=>{event.preventDefault();void this.connect().catch(e=>this.showError(e));});
  this.unsubscribe=bridge?.subscribe(event=>this.receive(event));
 }
 showError(error){this.status.textContent=error.message;if(this.lobby&&!this.lobby.root.hidden)this.lobby.status.textContent=error.message;runtimeDiagnostics.error(error,'network.ui-failed');}
 async refreshLoginSettings(){if(!this.bridge.clientSettings)return;const settings=await this.bridge.clientSettings();this.form.elements.cdkey.required=!settings.hasSavedCdKey;this.form.elements.cdkey.placeholder=settings.hasSavedCdKey?'Use saved key (enter a key to override)':'CD key';}
 syncCharacterControls(){if(this.exportButton)this.exportButton.disabled=!this.id||this.phase!=='playing'||this.savingCharacter;if(this.forceDisconnect)this.forceDisconnect.hidden=!this.id;}
 async refreshSavedCharacters(selected=null){
  const list=this.form.elements.savedCharacter;if(!list||!this.bridge?.savedCharacters)return;const revision=this.savedRefresh=(this.savedRefresh??0)+1,id=this.id,current=selected??list.value,entries=await this.bridge.savedCharacters();if(revision!==this.savedRefresh||id!==this.id)return;list.replaceChildren();const empty=document.createElement('option');empty.value='';empty.textContent='Choose a character file below';list.append(empty);
  for(const e of entries){const option=document.createElement('option');option.value=e.id;option.textContent=e.name+' · '+new Date(e.savedAt).toLocaleString();list.append(option);}list.value=entries.some(e=>e.id===current)?current:'';
 }
 async saveCharacter(){
  if(!this.id||this.savingCharacter||!this.bridge?.exportCharacter)throw new Error('Character export is unavailable');const id=this.id;this.savingCharacter=true;this.syncCharacterControls();if(this.characterStatus)this.characterStatus.textContent='Saving character…';
  try{const entry=await this.bridge.exportCharacter(id);if(id===this.id){await this.refreshSavedCharacters(entry.id);this.form.elements.character.value='';if(this.characterStatus)this.characterStatus.textContent='Saved '+entry.name;}return entry;}
  catch(error){if(this.characterStatus)this.characterStatus.textContent=error.message;throw error;}finally{this.savingCharacter=false;this.syncCharacterControls();}
 }
 async connect(){
  if(this.id)throw new Error('Disconnect the current multiplayer session first');this.canEnter();
  const file=this.lobby?null:this.form.elements.character.files[0],vaultId=this.lobby?null:this.form.elements.savedCharacter?.value;if(!file&&!vaultId&&!this.lobby)throw new Error('Select a saved character or a BIC file');
  const character=file?new Uint8Array(await file.arrayBuffer()):null,credentials={cdKey:this.form.elements.cdkey.value,password:this.form.elements.password.value};
  this.form.elements.cdkey.value='';this.form.elements.password.value='';
  const request={host:this.form.elements.host.value,port:Number(this.form.elements.port.value),name:this.form.elements.playerName.value,credentials,...(character?{character}:vaultId?{vaultId}:{})};this.status.textContent='Connecting…';this.form.querySelector('[type=submit]').disabled=true;
  try{const pending=this.bridge.connect(request);delete request.credentials;credentials.cdKey='';credentials.password='';character?.fill(0);await pending;this.dialog.close();}
  finally{delete request.credentials;credentials.cdKey='';credentials.password='';character?.fill(0);this.form.querySelector('[type=submit]').disabled=false;}
 }
 receive(event){
  if(event.kind==='state'&&event.state.phase==='connecting'&&event.sessionId!==this.id){
   try{this.canEnter();this.id=event.sessionId;this.inventoryRules=null;this.world=new NetworkWorld({onDiagnostic:d=>runtimeDiagnostics.record(d.code,d.reason,d)});const id=this.id;this.text=new NetworkText({world:this.world,getResource:(ref,type)=>this.bridge.getResource(id,ref,type),talkString:(ref,gender)=>this.bridge.talkString(id,ref,gender),diagnose:(...args)=>runtimeDiagnostics.record(...args)});this.onEnter();}
   catch(error){void this.bridge.disconnect().catch(()=>{});this.showError(error);return;}
  }
  if(event.sessionId!==this.id)return;
  if(event.kind==='diagnostic'){const d=event.diagnostic;runtimeDiagnostics.record(d.code,d.reason,d);if(d.code.startsWith('network.character-')){if(this.characterStatus)this.characterStatus.textContent=d.reason;if(this.lobby){this.lobby.status.textContent=d.reason;if(d.strRef!==undefined){const id=this.id;void this.text.raw({strRef:d.strRef}).then(text=>{if(id===this.id&&text)this.lobby.status.textContent=text;});}}}return;}
  if(event.kind==='state'){
   this.phase=event.state.phase;
   if(this.lobby){if(event.state.closed){this.lobby.reset();if(!this.lobby.root.hidden)this.lobby.showMain();}else if(['character-selection','character-rejected'].includes(event.state.phase))this.lobby.characterScreen(event.state);else if(['connecting','resources','character','transferring'].includes(event.state.phase)){if(this.lobby.view==='loading'&&!this.lobby.root.hidden)this.lobby.updateLoading(event.state);else this.lobby.loading(event.state);}else if(['area-loading','playing'].includes(event.state.phase))this.lobby.close();}
   const progress=event.state.resourceProgress,loading=event.state.phase==='resources'&&progress,progressLabel=progress?.phase==='server-manifest'?'server manifest':`server content ${progress?.completed}/${progress?.total}`;this.status.textContent=loading?`${progressLabel} · ${(progress.downloadedBytes/1048576).toFixed(1)} MiB downloaded`:event.state.phase;this.button.textContent=event.state.closed?'Multiplayer':'Multiplayer · '+(loading?progressLabel:event.state.phase);this.onState(event.state);
   if(event.state.closed){this.id=null;this.queue=this.queue.then(()=>{if(!this.id)return this.onExit();}).catch(e=>this.showError(e));}this.syncCharacterControls();return;
  }
  if(event.kind!=='message')return;
  // Scripted toolbar target selection must arm before the next world click,
  // independent of asynchronous model/chat work in an already-ready area.
  if((event.message.kind.startsWith('script-targeting')||event.message.kind==='spell-targeting-data')&&this.phase==='playing'&&event.areaGeneration===this.areaGeneration){
   const id=this.id,world=this.world;try{world.apply(event.message);Promise.resolve(this.onHud(event.message)).catch(error=>{if(id===this.id&&world===this.world)this.showError(error);});}catch(error){this.showError(error);}return;
  }
  // NUI has connection ownership and ordered IPC delivery. It must not wait
  // behind area model preparation, portrait reads or chat/TLK presentation.
  // Apply its state synchronously so create/bind/layout order is preserved.
  if(event.message.kind.startsWith('nui-')){
   const id=this.id,world=this.world;if(!world)return;
   try{world.apply(event.message);if(event.message.kind==='nui-create')runtimeDiagnostics.record('network.nui-window-dispatch','NUI window reached independent frontend dispatch',{token:event.message.token,rendererQueueMs:0,sinceMainReceiveMs:event.message.nuiTiming?Date.now()-event.message.nuiTiming.receivedAt:null});Promise.resolve(this.onHud(event.message)).catch(error=>{if(id===this.id&&world===this.world)this.showError(error);});}catch(error){this.showError(error);}return;
  }
  const id=this.id,queuedAt=performance.now();
  this.queue=this.queue.then(async()=>{
   if(id!==this.id)return;
   if(event.message.kind.startsWith('server-character-')){this.lobby?.receive(event.message);return;}
   if(event.message.kind==='character-saved'){await this.refreshSavedCharacters(event.message.entry.id);if(id===this.id&&this.characterStatus)this.characterStatus.textContent='Saved '+event.message.entry.name;return;}
   const notices=networkSystemNotices(event.message,{previousPlayers:this.world.players,ready:this.phase==='playing'});this.world.apply(event.message);
   for(const notice of notices){if(id!==this.id)return;await this.onHud({kind:'system-notice',...notice});}
   if(event.message.kind==='client-area'){
    const generation=this.areaGeneration=event.areaGeneration,areaId=event.message.area.id,prepared=await this.onArea(event.message,this.world,{resourceContext:id,getResource:(ref,type)=>this.bridge.getResource(id,ref,type),...(this.bridge.getModelSource?{getModelSource:(ref,knownKey)=>this.bridge.getModelSource(id,ref,knownKey)}:{}),...(this.bridge.getTextureResource?{getTextureResource:ref=>this.bridge.getTextureResource(id,ref)}:{})},()=>id===this.id);
    const current=()=>id===this.id&&this.areaGeneration===generation&&this.world.areaId===areaId;
    if(prepared?.graphics){
     //4/3 places the player into the server area. Keep that acknowledgement
     // behind graphics readiness while allowing queued canonical state import.
     this.areaAdmissionWork=Promise.resolve(prepared.graphics).then(ready=>{if(ready&&current())return this.bridge.areaReady(id,generation);}).catch(error=>{if(current())this.showError(error);});
    }else if(current())await this.bridge.areaReady(id,generation);
   }
   else if(event.message.kind==='object-updates')await this.onUpdates(event.message,this.world);
   else if(event.message.kind.startsWith('dialog-'))await this.onDialog(event.message);
   else if(event.message.kind==='container-status'||event.message.kind.startsWith('store-'))await this.onHud(event.message);
   else if(event.message.kind==='inventory-result')await this.onInventoryResult(event.message);
   else if(event.message.kind==='safe-projectile')await this.onProjectile(event.message.header);
   else if(event.message.kind==='object-visual')await this.onObjectVisual(event.message);
   else if(event.message.kind==='area-visual')await this.onAreaVisual(event.message);
   else if(event.message.kind==='quickbar')await this.onQuickbar();
   else if(['combat-feedback','spell-feedback','damage-feedback','attack-feedback','initiative-feedback'].includes(event.message.kind))await this.onHud(event.message);
   else if(event.message.kind==='server-speech')await this.onHud(event.message);
   else if(['script-sound','voice-play','quick-chat','ambient-command','sound-object'].includes(event.message.kind))await this.onAudio(event.message);
   else if(['examine','script-targeting','script-targeting-data','spell-targeting-data'].includes(event.message.kind))await this.onHud(event.message);
   else if(['tlk-overrides','gui-timing','journal','player-attitude','map-pin-created','map-pin-enabled'].includes(event.message.kind))await this.onHud(event.message);
   else if(event.message.kind.startsWith('camera-'))await this.onCamera(event.message);
   else if(event.message.kind==='party-list'||event.message.kind==='object-control'||event.message.kind.startsWith('player-list-'))await this.onParty();
  }).catch(e=>{if(id===this.id)this.showError(e);});
 }
 async disconnect(options){await this.bridge.disconnect(options);await this.refreshSavedCharacters();this.dialog.close();}
 async walkTo(position,run=true){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');const id=this.id,generation=this.areaGeneration,result=await this.bridge.walkTo(this.id,{areaId:this.world.areaId,areaGeneration:generation,position,run});if(this.id===id&&this.areaGeneration===generation)this.onMovementSent?.(result.sequence);return result;}
 async interact(targetId,action,run=true){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.interact(this.id,{areaId:this.world.areaId,areaGeneration:this.areaGeneration,targetId,action,run});}
 async replyDialog(value){if(!this.id)throw new Error('Multiplayer is not connected');return this.bridge.replyDialog(this.id,{areaId:this.world.areaId,areaGeneration:this.areaGeneration,...value});}
 async chat(request){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');if(['-tb','-nui'].includes(request.text?.trim()))runtimeDiagnostics.record('network.nui-trigger','NUI chat trigger submitted',{command:request.text.trim()});return this.bridge.chat(this.id,{...request,actorId:this.world.localObjectId,areaId:this.world.areaId,areaGeneration:this.areaGeneration});}
 async inventoryWindow(open){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.inventoryWindow(this.id,{areaId:this.world.areaId,areaGeneration:this.areaGeneration,open});}
 async storeInput(request){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');const id=this.id,world=this.world,generation=this.areaGeneration,store=world.store;if(!store?.open)throw new Error('Native store is closed');const result=await this.bridge.storeInput(id,{...request,areaId:world.areaId,areaGeneration:generation,actorId:world.localObjectId,storeGeneration:store.generation});if(id!==this.id||world!==this.world||generation!==this.areaGeneration||world.store!==store)return result;if(request.operation==='close')world.apply({kind:'store-close'});else if(request.operation==='panel'||request.operation==='page'){world.inventories.get('M').entries=[];if(request.operation==='panel'){store.panel=request.panel;store.page=0;}else store.page=request.page;}return result;}
 async inventoryPanel(panel){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');this.world.clearRepositoryView();return this.bridge.inventoryPanel(this.id,{areaId:this.world.areaId,areaGeneration:this.areaGeneration,panel});}
 async containerInput(operation){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');const id=this.id,world=this.world,generation=this.areaGeneration,targetId=world.containers.get('C'),result=await this.bridge.containerInput(id,{areaId:world.areaId,areaGeneration:generation,actorId:world.localObjectId,targetId,operation});if(operation==='close'&&id===this.id&&world===this.world&&generation===this.areaGeneration&&world.containers.get('C')===targetId){const close={kind:'container-status',targetId:0x7f000000,primary:1};world.apply(close);await this.onHud(close);}return result;}
 async itemAction(request){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.itemAction(this.id,{...request,areaId:this.world.areaId,areaGeneration:this.areaGeneration});}
 async assignQuickbar(index,button){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');const id=this.id,generation=this.areaGeneration,result=await this.bridge.assignQuickbar(id,{areaId:this.world.areaId,areaGeneration:generation,index,button});if(id!==this.id||generation!==this.areaGeneration)throw new Error('Quickbar assignment belongs to an old area');this.world.applyQuickbar({entries:[{index,button:result.button,items:[]}]});await this.onQuickbar();return result;}
 async activateQuickbar(index){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.activateQuickbar(this.id,{areaId:this.world.areaId,areaGeneration:this.areaGeneration,index});}
 async prepareSpell(request){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.prepareSpell(this.id,{...request,actorId:this.world.localObjectId,areaId:this.world.areaId,areaGeneration:this.areaGeneration});}
 async rest(){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.rest(this.id,{actorId:this.world.localObjectId,areaId:this.world.areaId,areaGeneration:this.areaGeneration});}
 async levelUp(request){if(!this.id||!this.world)throw Error('Multiplayer is not connected');return this.bridge.levelUp(this.id,{...request,actorId:this.world.localObjectId,areaId:this.world.areaId,areaGeneration:this.areaGeneration});}
 async nuiInput(request){if(!this.id||!this.world)throw Error('Multiplayer is not connected');const id=this.id,world=this.world,window=world.nui.windows.get(request.token);if(window?.serial!==request.serial)throw Error('NUI window was replaced');const result=await this.bridge.nuiInput(id,request);if(id===this.id&&world===this.world&&world.nui.windows.get(request.token)?.serial===request.serial&&(request.events??[]).some(e=>e.type==='close')){world.nui.apply({kind:'nui-destroy',token:request.token});await this.onHud({kind:'nui-destroy',token:request.token});}return result;}
 async selectScriptTarget(request){if(!this.id||!this.world)throw Error('Multiplayer is not connected');const id=this.id,world=this.world,result=await this.bridge.selectScriptTarget(id,{...request,actorId:world.localObjectId,areaId:world.areaId,areaGeneration:this.areaGeneration});if(id===this.id&&world===this.world&&world.scriptTargeting?.version===request.version)world.scriptTargeting=null;return result;}
 async cancelAction(actionId,groupId){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.cancelAction(this.id,{actorId:this.world.localObjectId,areaId:this.world.areaId,areaGeneration:this.areaGeneration,actionId,groupId});}
 async examine(targetId){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.examine(this.id,{targetId,actorId:this.world.localObjectId,areaId:this.world.areaId,areaGeneration:this.areaGeneration});}
 async hudPanel(panel,open,page=0){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.hudPanel(this.id,{panel,open,page,actorId:this.world.localObjectId,areaId:this.world.areaId,areaGeneration:this.areaGeneration});}
 async playerAttitude(playerId,likes){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.playerAttitude(this.id,{playerId,likes,actorId:this.world.localObjectId,areaId:this.world.areaId,areaGeneration:this.areaGeneration});}
 async castSpell(request){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.castSpell(this.id,{...request,areaId:this.world.areaId,areaGeneration:this.areaGeneration});}
 async useItem(request){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.useItem(this.id,{...request,areaId:this.world.areaId,areaGeneration:this.areaGeneration});}
 async castSpellLike(request){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.castSpellLike(this.id,{...request,areaId:this.world.areaId,areaGeneration:this.areaGeneration});}
 async useFeat(request){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.useFeat(this.id,{...request,areaId:this.world.areaId,areaGeneration:this.areaGeneration});}
 async changeMode(request){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.changeMode(this.id,{...request,areaId:this.world.areaId,areaGeneration:this.areaGeneration});}
 async possessFamiliar(){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.possessFamiliar(this.id,{areaId:this.world.areaId,areaGeneration:this.areaGeneration});}
 async associateCommand(targetId,command){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.associateCommand(this.id,{areaId:this.world.areaId,areaGeneration:this.areaGeneration,actorId:this.world.localObjectId,targetId,command});}
 async quickChat(quickChat){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.quickChat(this.id,{areaId:this.world.areaId,areaGeneration:this.areaGeneration,actorId:this.world.localObjectId,quickChat});}
 async inventoryBaseItems(){if(!this.id)throw new Error('Multiplayer is not connected');const id=this.id;this.inventoryRules??=this.bridge.getResource(id,'baseitems',RESOURCE_TYPE.TWO_DA).then(bytes=>parse2da(decodeResourceText(bytes)));const table=await this.inventoryRules;if(id!==this.id)throw new Error('Native inventory resources are stale');return table;}
 async resolveText(value,contextId=this.world.localObjectId,options){return this.text.resolve(value,contextId,options);}
}
