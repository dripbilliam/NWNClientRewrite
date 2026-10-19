import {NetworkWorld} from './network_world.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {NetworkText} from './network_text.js';
import {parse2da} from './area.js';
import {RESOURCE_TYPE,decodeResourceText} from './resource_archive.js';

// Narrow application requests; no local game simulation is attached here.
export class NetworkFrontend {
 constructor({bridge,canEnter,onEnter,onExit,onArea,onUpdates,onState,onDialog=()=>{},onInventoryResult=()=>{},onProjectile=()=>{},onObjectVisual=()=>{},onAreaVisual=()=>{},onQuickbar=()=>{},onParty=()=>{},onCamera=()=>{},onHud=()=>{}}){
  Object.assign(this,{bridge,canEnter,onEnter,onExit,onArea,onUpdates,onState,onDialog,onInventoryResult,onProjectile,onObjectVisual,onAreaVisual,onQuickbar,onParty,onCamera,onHud});this.id=null;this.queue=Promise.resolve();
  this.button=document.querySelector('#multiplayer-button');this.dialog=document.querySelector('#multiplayer-dialog');this.form=this.dialog.querySelector('form');this.status=document.querySelector('#multiplayer-status');
  this.button.disabled=!bridge;
  this.dialog.addEventListener('close',()=>{this.form.elements.cdkey.value='';this.form.elements.password.value='';});
  this.button.addEventListener('click',()=>this.dialog.showModal());
  document.querySelector('#multiplayer-cancel').addEventListener('click',()=>this.dialog.close());
  document.querySelector('#multiplayer-disconnect').addEventListener('click',()=>{void this.disconnect().catch(e=>this.showError(e));});
  document.querySelector('#multiplayer-install').addEventListener('click',()=>{void bridge.chooseInstall().then(r=>{if(r.selected)this.status.textContent='Installation selected';}).catch(e=>this.showError(e));});
  this.form.addEventListener('submit',event=>{event.preventDefault();void this.connect().catch(e=>this.showError(e));});
  this.unsubscribe=bridge?.subscribe(event=>this.receive(event));
 }
 showError(error){this.status.textContent=error.message;runtimeDiagnostics.error(error,'network.ui-failed');}
 async connect(){
  if(this.id)throw new Error('Disconnect the current multiplayer session first');this.canEnter();
  const file=this.form.elements.character.files[0];if(!file)throw new Error('Select a character BIC file');
  const character=new Uint8Array(await file.arrayBuffer()),credentials={cdKey:this.form.elements.cdkey.value,password:this.form.elements.password.value};
  this.form.elements.cdkey.value='';this.form.elements.password.value='';
  const request={host:this.form.elements.host.value,port:Number(this.form.elements.port.value),name:this.form.elements.playerName.value,credentials,character};this.status.textContent='Connecting…';this.form.querySelector('[type=submit]').disabled=true;
  try{const pending=this.bridge.connect(request);delete request.credentials;credentials.cdKey='';credentials.password='';character.fill(0);await pending;this.dialog.close();}
  finally{delete request.credentials;credentials.cdKey='';credentials.password='';character.fill(0);this.form.querySelector('[type=submit]').disabled=false;}
 }
 receive(event){
  if(event.kind==='state'&&event.state.phase==='connecting'&&event.sessionId!==this.id){
   try{this.canEnter();this.id=event.sessionId;this.inventoryRules=null;this.world=new NetworkWorld({onDiagnostic:d=>runtimeDiagnostics.record(d.code,d.reason,d)});const id=this.id;this.text=new NetworkText({world:this.world,getResource:(ref,type)=>this.bridge.getResource(id,ref,type),talkString:(ref,gender)=>this.bridge.talkString(id,ref,gender),diagnose:(...args)=>runtimeDiagnostics.record(...args)});this.onEnter();}
   catch(error){void this.bridge.disconnect().catch(()=>{});this.showError(error);return;}
  }
  if(event.sessionId!==this.id)return;
  if(event.kind==='diagnostic'){const d=event.diagnostic;runtimeDiagnostics.record(d.code,d.reason,d);return;}
  if(event.kind==='state'){
   this.status.textContent=event.state.phase;this.button.textContent=event.state.closed?'Multiplayer':'Multiplayer · '+event.state.phase;this.onState(event.state);
   if(event.state.closed){this.id=null;this.queue=this.queue.then(()=>{if(!this.id)return this.onExit();}).catch(e=>this.showError(e));}return;
  }
  if(event.kind!=='message')return;
  const id=this.id;
  this.queue=this.queue.then(async()=>{
   if(id!==this.id)return;this.world.apply(event.message);
   if(event.message.kind==='client-area'){this.areaGeneration=event.areaGeneration;await this.onArea(event.message,this.world,{getResource:(ref,type)=>this.bridge.getResource(id,ref,type)},()=>id===this.id);if(id===this.id)await this.bridge.areaReady(id,event.areaGeneration);}
   else if(event.message.kind==='object-updates')await this.onUpdates(event.message,this.world);
   else if(event.message.kind.startsWith('dialog-'))await this.onDialog(event.message);
   else if(event.message.kind==='inventory-result')await this.onInventoryResult(event.message);
   else if(event.message.kind==='safe-projectile')await this.onProjectile(event.message.header);
   else if(event.message.kind==='object-visual')await this.onObjectVisual(event.message);
   else if(event.message.kind==='area-visual')await this.onAreaVisual(event.message);
   else if(event.message.kind==='quickbar')await this.onQuickbar();
   else if(event.message.kind==='examine')await this.onHud(event.message);
   else if(['gui-timing','journal','player-attitude','map-pin-created','map-pin-enabled'].includes(event.message.kind))await this.onHud(event.message);
   else if(event.message.kind.startsWith('camera-'))await this.onCamera(event.message);
   else if(event.message.kind==='party-list'||event.message.kind==='object-control'||event.message.kind.startsWith('player-list-'))await this.onParty();
   else if(event.message.kind==='quick-chat')runtimeDiagnostics.record('network.quickchat-presentation-unhandled','Native quick-chat audio and text presentation are not connected',{objectId:event.message.objectId,quickChat:event.message.quickChat});
  }).catch(e=>{if(id===this.id)this.showError(e);});
 }
 async disconnect(){await this.bridge.disconnect();this.dialog.close();}
 async walkTo(position,run=true){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.walkTo(this.id,{areaId:this.world.areaId,areaGeneration:this.areaGeneration,position,run});}
 async interact(targetId,action,run=true){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.interact(this.id,{areaId:this.world.areaId,areaGeneration:this.areaGeneration,targetId,action,run});}
 async replyDialog(value){if(!this.id)throw new Error('Multiplayer is not connected');return this.bridge.replyDialog(this.id,{areaId:this.world.areaId,areaGeneration:this.areaGeneration,...value});}
 async inventoryWindow(open){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.inventoryWindow(this.id,{areaId:this.world.areaId,areaGeneration:this.areaGeneration,open});}
 async inventoryPanel(panel){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');this.world.clearRepositoryView();return this.bridge.inventoryPanel(this.id,{areaId:this.world.areaId,areaGeneration:this.areaGeneration,panel});}
 async itemAction(request){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.itemAction(this.id,{...request,areaId:this.world.areaId,areaGeneration:this.areaGeneration});}
 async assignQuickbar(index,button){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');const id=this.id,generation=this.areaGeneration,result=await this.bridge.assignQuickbar(id,{areaId:this.world.areaId,areaGeneration:generation,index,button});if(id!==this.id||generation!==this.areaGeneration)throw new Error('Quickbar assignment belongs to an old area');this.world.applyQuickbar({entries:[{index,button:result.button,items:[]}]});await this.onQuickbar();return result;}
 async activateQuickbar(index){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.activateQuickbar(this.id,{areaId:this.world.areaId,areaGeneration:this.areaGeneration,index});}
 async prepareSpell(request){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.prepareSpell(this.id,{...request,actorId:this.world.localObjectId,areaId:this.world.areaId,areaGeneration:this.areaGeneration});}
 async rest(){if(!this.id||!this.world)throw new Error('Multiplayer is not connected');return this.bridge.rest(this.id,{actorId:this.world.localObjectId,areaId:this.world.areaId,areaGeneration:this.areaGeneration});}
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
 async resolveText(value,contextId=this.world.localObjectId){return this.text.resolve(value,contextId);}
}
