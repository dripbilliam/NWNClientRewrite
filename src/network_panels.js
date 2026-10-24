import {GAME_HUD_ACTIONS} from './game_hud_actions.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {NetworkSpellbookView} from './network_spellbook_view.js';
import {NetworkMapView} from './network_map.js';
import {CharacterRecordView} from './character_record_view.js';
import {networkCharacterRecord} from './character_record_model.js';
import {networkPartyRows} from './network_party_view.js';
import {networkPortrait} from './network_portrait.js';
import {NetworkLevelUpView} from './network_level_up_view.js';
import {debugWindowOption} from './debug_shell.js';
import {raiseGameWindow,isFrontGameWindow,frontGameWindow} from './movable_windows.js';
const el=(tag,text)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;return n;};

// Read-only projections of replicated state. Every cast/item action delegates
// to the existing typed server input; opening a panel runs no local simulation.
export class NetworkPanels{
 constructor(viewport,options){
  this.viewport=viewport;this.options=options;this.views=new Map();
  window.addEventListener('keydown',event=>{
   if(!options.world()||event.defaultPrevented||event.repeat||event.ctrlKey||event.altKey||event.metaKey||event.target.closest?.('input,textarea,select,[contenteditable]'))return;
   if(event.key==='Escape'){
    const view=[...this.views.values()].find(v=>v.active&&isFrontGameWindow(v.host));if(!view)return;
    event.preventDefault();event.stopImmediatePropagation();const front=frontGameWindow(view.host);
    if(view.panel==='spells'&&front?.matches('.network-spell-window'))front.querySelector('header .network-spell-close')?.click();else view.close();return;
   }
   const action=GAME_HUD_ACTIONS.find(([id,,,key])=>id!=='inventory'&&key===event.key.toLowerCase());if(action){event.preventDefault();event.stopImmediatePropagation();void this.open(action[0]);}
  },true);
 }
 view(id){if(!this.views.has(id))this.views.set(id,new NetworkPanelWindow(this.viewport,{...this.options,openPanel:panel=>this.open(panel),onVisibility:visible=>this.options.onVisibility?.(this.active,visible?id:null)}));return this.views.get(id);}
 get active(){return[...this.views.values()].some(view=>view.active);}
 get panel(){return[...this.views.values()].find(view=>view.active&&isFrontGameWindow(view.host))?.panel??null;}
 async open(id){if(!this.options.world())return;if(id==='inventory')return this.options.inventory();if(id==='rest'){try{await this.options.rest();}catch(error){runtimeDiagnostics.error(error,'network.rest-input-failed');}return;}if(![...GAME_HUD_ACTIONS.map(a=>a[0]),'level-up'].includes(id))return;return this.view(id).open(id);}
 close(options){const view=[...this.views.values()].find(view=>view.active&&isFrontGameWindow(view.host));view?.close(options);}
 reset(){for(const view of this.views.values())view.reset();}
 async sync(){const world=this.options.world();if(world?.registry.get(world.localObjectId)?.playerState?.combat?.canLevelUp)this.view('level-up').levelUp.warm();await Promise.all([...this.views.values()].filter(view=>view.active).map(view=>view.sync().catch(error=>view.feedback(error))));}
}
class NetworkPanelWindow{
 constructor(viewport,{world,quickbar,resolve,inventory,activate,prepare,rest,panelRequest,levelUp,levelUpResources,attitude,settings,setSettings,disconnect,onVisibility,openPanel}){
  Object.assign(this,{world,quickbar,resolve,inventory,activate,rest,panelRequest,attitude,settings,setSettings,disconnect,onVisibility});this.generation=0;this.characterTab='Character';this.journalTab='Quests';
  this.openPanel=openPanel;
  this.host=el('section');this.host.className='network-panels';this.host.hidden=true;this.host.setAttribute('aria-label','Game panels');viewport.append(this.host);
  this.spellbook=new NetworkSpellbookView({world,quickbar,resolve,prepare,close:()=>this.close()});
  this.levelUp=new NetworkLevelUpView({world,request:levelUp,resources:levelUpResources,close:()=>this.close()});
  this.record=new CharacterRecordView({assets:()=>this.quickbar.assets,icon:name=>this.quickbar.icon(name),close:()=>this.close(),onTab:tab=>{if(!this.world())return;this.characterTab=tab;this.key=null;void this.panelRequest('character',true,['Character','Skills','Feats'].indexOf(tab)).catch(error=>this.feedback(error));void this.sync();},source:(node,binding)=>{const owner=this.world(),actor=owner?.registry.get(owner.localObjectId),token=this.quickbar.token;node.draggable=true;node.addEventListener('dragstart',event=>{if(this.world()!==owner||owner.registry.get(owner.localObjectId)!==actor||token!==this.quickbar.token){event.preventDefault();return;}event.dataTransfer.setData('application/x-nwn-network-action',JSON.stringify({token,actorId:actor.id,binding}));event.dataTransfer.effectAllowed='copy';});}});
  for(const type of ['pointerdown','pointerup','click','dblclick','wheel','contextmenu'])this.host.addEventListener(type,event=>event.stopPropagation());
 }
 get active(){return!this.host.hidden;}
 feedback(error){runtimeDiagnostics.error(error,'network.hud-action-failed');const node=document.querySelector('#network-feedback');if(node)node.textContent=error.message;}
 close({notify=true}={}){if(this.panel==='level-up'&&this.levelUp.sending)return;const old=this.panel;if(old==='level-up')this.levelUp.cancel();if(notify&&['character','journal'].includes(old))void this.panelRequest(old,false).catch(error=>this.feedback(error));this.generation++;this.mapView?.destroy();this.mapView=null;this.spellbook.reset();this.panel=null;this.key=null;this.host.hidden=true;this.host.replaceChildren();this.onVisibility(false);}
 reset(){this.levelUp.sending=false;this.levelUp.reset();this.close({notify:false});}
 async open(id){
  if(!this.world())return;
  if(this.levelUp.sending)return;
  if(this.panel===id&&this.active){this.close();return;}
  if(this.active)this.close();
  this.generation++;this.panel=id;this.key=null;this.host.hidden=false;this.host.dataset.panel=id;raiseGameWindow(this.host);this.onVisibility(true);if(id==='level-up'){this.host.replaceChildren(this.levelUp.host);await this.levelUp.open();return;}await this.sync();
  if(this.panel===id&&['character','journal'].includes(id))try{await this.panelRequest(id,true,id==='character'?['Character','Skills','Feats'].indexOf(this.characterTab):0);}catch(error){this.feedback(error);}
 }
 async sync(){
  if(!this.active)return;const world=this.world(),generation=this.generation,panel=this.panel,actor=world?.registry.get(world.localObjectId);if(!world||!actor){this.close();return;}
  if(panel==='level-up'){this.levelUp.sync();return;}
  if(panel==='spells'){this.host.dataset.panel=panel;if(this.host.firstChild!==this.spellbook.host)this.host.replaceChildren(this.spellbook.host);await this.spellbook.sync();return;}
  if(panel==='map'&&this.mapView){await this.mapView.sync();return;}
  const data=panel==='pvp'?[[...world.players.values()],[...world.playerAttitudes]]:panel==='character'?[actor.replicated,actor.playerState,actor.inventoryStats,actor.appearance?.equipment,world.inventories.get('I'),this.characterTab]:panel==='journal'?[[...world.journal.entries.values()],[...world.journal.worldEntries.values()],world.journal.loaded,this.journalTab]:null;
  const key=JSON.stringify([panel,world.localObjectId,world.tlkOverrideVersion,data]);if(this.key===key)return;const render=this.renderVersion=(this.renderVersion??0)+1;
  const header=el('header'),title=el('h2',GAME_HUD_ACTIONS.find(a=>a[0]===panel)?.[1]??panel),close=el('button','Close');close.type='button';close.className='tool-button';close.addEventListener('click',()=>this.close());header.append(title,close);const body=el('div');
  let recordModel;
  try{
   if(panel==='pvp'){
    const list=el('ul');for(const p of world.players.values()){const row=el('li'),label=p.character?`${await this.resolve(p.character.firstName)} ${await this.resolve(p.character.lastName)}`.trim():p.name;row.append(el('span',`${label} · ${p.name}${p.isDM?' · DM':''}`));if(p.objectId!==world.localObjectId)for(const [likes,label]of [[true,'Set friendly'],[false,'Set hostile']]){const b=el('button',label);b.type='button';b.className='tool-button';b.addEventListener('click',()=>{if(this.world()===world&&world.players.get(p.playerId)?.objectId===p.objectId)void this.attitude(p.playerId,likes).catch(error=>this.feedback(error));});row.append(b);}list.append(row);}body.append(list);if(!world.players.size)body.append(el('p','No players have been received.'));
   }else if(panel==='character'){
    recordModel=await networkCharacterRecord(world,actor,{tables:this.quickbar.tables,resolve:this.resolve,identity:this.quickbar.token+':'+actor.id,portrait:()=>networkPortrait(this.quickbar.assets,this.quickbar.tables,networkPartyRows(world).find(r=>r.self)??{},4)});
   }else if(panel==='journal'){
    const tabs=el('nav');for(const tab of ['Quests','Completed','Notes','Messages']){const b=el('button',tab);b.type='button';b.className='tool-button';b.setAttribute('aria-pressed',String(this.journalTab===tab));b.addEventListener('click',()=>{this.journalTab=tab;this.key=null;void this.sync();});tabs.append(b);}body.append(tabs);const rows=this.journalTab==='Messages'?[...world.journal.worldEntries.values()]:[...world.journal.entries.values()].filter(e=>this.journalTab==='Notes'?!e.isQuest:e.isQuest&&(this.journalTab==='Completed'?!!e.completed:!e.completed));for(const entry of rows){const item=el('article'),label=entry.title?await this.resolve(entry.title):entry.tag??'Journal entry';item.append(el('h3',label),el('p',await this.resolve(entry.description??(entry.strRef!==undefined?{strRef:entry.strRef}:null))));body.append(item);}if(!rows.length)body.append(el('p',world.journal.loaded?'No entries in this category.':'Waiting for the server journal…'));
   }else if(panel==='map'){
    // MapUi checks attachment after asynchronous resource loading. Mount its
    // skeleton before starting that load rather than presenting a detached map.
    if(generation!==this.generation||world!==this.world())return;this.host.replaceChildren(header,body);this.host.dataset.panel=panel;
    this.mapView=new NetworkMapView(body,{world:this.world,assets:this.quickbar.assets,resolve:this.resolve});await this.mapView.sync();
   }else if(panel==='options'){
    body.append(debugWindowOption());
    const goreLabel=el('label','Blood effects '),gore=el('select');for(const [value,label]of [[0,'Low'],[1,'Normal'],[2,'Full']]){const option=el('option',label);option.value=value;gore.append(option);}gore.value=this.settings().gore??1;gore.setAttribute('aria-label','Blood effects');gore.addEventListener('change',()=>this.setSettings({gore:Number(gore.value)}));body.append(goreLabel);goreLabel.append(gore);
    const settings=this.settings(),camera=el('label','Camera '),select=el('select');for(const [value,label]of [[1,'Top-down'],[0,'Chase'],[2,'Stiff chase']]){const option=el('option',label);option.value=value;select.append(option);}select.value=settings.cameraMode;select.setAttribute('aria-label','Camera mode');select.addEventListener('change',()=>this.setSettings({cameraMode:Number(select.value)}));camera.append(select);body.append(camera);
    const shadowLabel=el('label','Shadow-casting lights '),shadow=el('select');for(const value of [1,2,3]){const option=el('option',String(value));option.value=value;shadow.append(option);}shadow.value=settings.shadowCastingLights??3;shadow.setAttribute('aria-label','Shadow-casting lights');shadow.addEventListener('change',()=>this.setSettings({shadowCastingLights:Number(shadow.value)}));shadowLabel.append(shadow);body.append(shadowLabel);
    const wire=el('label'),check=el('input');check.type='checkbox';check.checked=settings.wireframe;check.addEventListener('change',()=>this.setSettings({wireframe:check.checked}));wire.append(check,el('span',' Wireframe'));body.append(wire);
    for(const [key,label,fallback]of [['showCreatureSlots','Show creature equipment slots',false],['floatingFeedback','Floating combat feedback',true],['damageTotalsOnly','Show total damage only',false]]){const row=el('label'),box=el('input');box.type='checkbox';box.checked=settings[key]??fallback;box.setAttribute('aria-label',label);box.addEventListener('change',()=>this.setSettings({[key]:box.checked}));row.append(box,el('span',' '+label));body.append(row);}
    const back=el('button','Return to game'),disconnect=el('button','Disconnect');for(const b of [back,disconnect]){b.type='button';b.className='tool-button';}back.addEventListener('click',()=>this.close());disconnect.addEventListener('click',()=>{this.close();void this.disconnect().catch(error=>this.feedback(error));});body.append(back,disconnect);
   }
  }catch(error){body.replaceChildren(el('p',error.message));runtimeDiagnostics.error(error,'network.panel-failed',{panel});}
  if(render!==this.renderVersion||generation!==this.generation||world!==this.world()||actor.id!==world.localObjectId)return;
  if(recordModel){const record=this.record.render(recordModel,this.characterTab);if(actor.playerState?.combat?.canLevelUp){const up=el('button','Level Up');up.type='button';up.className='game-button record-level-up';up.addEventListener('click',()=>void this.openPanel('level-up'));record.querySelector('.record-title').append(up);}this.host.replaceChildren(record);}else this.host.replaceChildren(header,body);this.host.dataset.panel=panel;this.key=key;
 }
}
