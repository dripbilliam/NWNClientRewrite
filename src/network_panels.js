import {GAME_HUD_ACTIONS} from './game_hud_actions.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {NetworkSpellbookView} from './network_spellbook_view.js';
import {NetworkMapView} from './network_map.js';
const el=(tag,text)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;return n;};

// Read-only projections of replicated state. Every cast/item action delegates
// to the existing typed server input; opening a panel runs no local simulation.
export class NetworkPanels{
 constructor(viewport,{world,quickbar,resolve,inventory,activate,prepare,rest,panelRequest,attitude,settings,setSettings,disconnect,onVisibility}){
  Object.assign(this,{world,quickbar,resolve,inventory,activate,rest,panelRequest,attitude,settings,setSettings,disconnect,onVisibility});this.generation=0;this.characterTab='Character';this.journalTab='Quests';
  this.host=el('section');this.host.className='network-panels';this.host.hidden=true;this.host.setAttribute('aria-label','Game panels');viewport.append(this.host);
  this.spellbook=new NetworkSpellbookView({world,quickbar,resolve,prepare,close:()=>this.close()});
  for(const type of ['pointerdown','pointerup','click','dblclick','wheel','contextmenu'])this.host.addEventListener(type,event=>event.stopPropagation());
  window.addEventListener('keydown',event=>{if(!this.world()||event.repeat||event.ctrlKey||event.altKey||event.metaKey||/^(INPUT|TEXTAREA|SELECT)$/.test(event.target.tagName))return;
   if(event.key==='Escape'&&this.active){event.preventDefault();event.stopImmediatePropagation();if(this.panel==='spells'&&this.spellbook.examine!==null&&this.spellbook.examine!==undefined){this.spellbook.examine=null;this.spellbook.refresh();}else this.close();return;}
   const action=GAME_HUD_ACTIONS.find(([id,,,key])=>id!=='inventory'&&key===event.key.toLowerCase());if(action){event.preventDefault();event.stopImmediatePropagation();void this.open(action[0]);}
  },true);
 }
 get active(){return!this.host.hidden;}
 feedback(error){runtimeDiagnostics.error(error,'network.hud-action-failed');const node=document.querySelector('#network-feedback');if(node)node.textContent=error.message;}
 close({notify=true}={}){const old=this.panel;if(notify&&['character','journal'].includes(old))void this.panelRequest(old,false).catch(error=>this.feedback(error));this.generation++;this.mapView?.destroy();this.mapView=null;this.spellbook.reset();this.panel=null;this.key=null;this.host.hidden=true;this.host.replaceChildren();this.onVisibility(false);}
 reset(){this.close({notify:false});}
 async open(id){
  if(!this.world())return;
  if(id==='inventory'){this.close();await this.inventory();return;}
  if(id==='rest'){this.close();try{await this.rest();}catch(error){runtimeDiagnostics.error(error,'network.rest-input-failed');const feedback=document.querySelector('#network-feedback');if(feedback)feedback.textContent=error.message;}return;}
  if(this.panel===id&&this.active){this.close();return;}
  if(this.active)this.close();
  this.generation++;this.panel=id;this.key=null;this.host.hidden=false;this.onVisibility(true);await this.sync();
  if(this.panel===id&&['character','journal'].includes(id))try{await this.panelRequest(id,true,id==='character'?['Character','Skills','Feats'].indexOf(this.characterTab):0);}catch(error){this.feedback(error);}
 }
 async sync(){
  if(!this.active)return;const world=this.world(),generation=this.generation,panel=this.panel,actor=world?.registry.get(world.localObjectId);if(!world||!actor){this.close();return;}
  if(panel==='spells'){this.host.dataset.panel=panel;if(this.host.firstChild!==this.spellbook.host)this.host.replaceChildren(this.spellbook.host);await this.spellbook.sync();return;}
  if(panel==='map'&&this.mapView){await this.mapView.sync();return;}
  const data=panel==='pvp'?[[...world.players.values()],[...world.playerAttitudes]]:panel==='character'?[actor.replicated,actor.playerState,actor.inventoryStats,this.characterTab]:panel==='journal'?[[...world.journal.entries.values()],[...world.journal.worldEntries.values()],world.journal.loaded,this.journalTab]:null;
  const key=JSON.stringify([panel,world.localObjectId,data]);if(this.key===key)return;const render=this.renderVersion=(this.renderVersion??0)+1;
  const header=el('header'),title=el('h2',GAME_HUD_ACTIONS.find(a=>a[0]===panel)?.[1]??panel),close=el('button','Close');close.type='button';close.className='tool-button';close.addEventListener('click',()=>this.close());header.append(title,close);const body=el('div');
  try{
   if(panel==='pvp'){
    const list=el('ul');for(const p of world.players.values()){const row=el('li'),label=p.character?`${await this.resolve(p.character.firstName)} ${await this.resolve(p.character.lastName)}`.trim():p.name;row.append(el('span',`${label} · ${p.name}${p.isDM?' · DM':''}`));if(p.objectId!==world.localObjectId)for(const [likes,label]of [[true,'Set friendly'],[false,'Set hostile']]){const b=el('button',label);b.type='button';b.className='tool-button';b.addEventListener('click',()=>{if(this.world()===world&&world.players.get(p.playerId)?.objectId===p.objectId)void this.attitude(p.playerId,likes).catch(error=>this.feedback(error));});row.append(b);}list.append(row);}body.append(list);if(!world.players.size)body.append(el('p','No players have been received.'));
   }else if(panel==='character'){
    const tabs=el('nav');for(const [page,tab]of ['Character','Skills','Feats'].entries()){const b=el('button',tab);b.type='button';b.className='tool-button';b.setAttribute('aria-pressed',String(this.characterTab===tab));b.addEventListener('click',()=>{if(this.world()!==world)return;this.characterTab=tab;this.key=null;void this.panelRequest('character',true,page).catch(error=>this.feedback(error));void this.sync();});tabs.append(b);}body.append(tabs);
    if(this.characterTab==='Character'){const stats=actor.replicated?.stats,list=el('dl');for(const cls of stats?.classes??[])list.append(el('dt',await this.quickbar.ruleName('classes',cls.id)),el('dd',`Level ${cls.level}`));const hp=actor.replicated?.hitPoints;if(hp)list.append(el('dt','Hit points'),el('dd',`${hp.current} / ${hp.maximum}`));const ac=actor.playerState?.combat?.armorClass;if(ac!==undefined)list.append(el('dt','Armor class'),el('dd',ac));const abilities=actor.playerState?.abilities?.current;if(abilities)for(const [i,label]of ['Strength','Dexterity','Constitution','Intelligence','Wisdom','Charisma'].entries())list.append(el('dt',label),el('dd',abilities[i]));body.append(list);}
    else if(this.characterTab==='Skills'){const list=el('dl');for(const s of actor.inventoryStats?.skills??[])list.append(el('dt',await this.quickbar.ruleName('skills',s.index)),el('dd',s.value));body.append(list);if(!list.children.length)body.append(el('p','Waiting for server skill details.'));}
    else {const list=el('ul');for(const id of new Set([...(actor.playerState?.feats??[]),...(actor.playerState?.bonusFeats??[]),...(actor.inventoryStats?.feats??[]).map(f=>f.id)]))list.append(el('li',await this.quickbar.ruleName('feat',id,'FEAT')));body.append(list);}
   }else if(panel==='journal'){
    const tabs=el('nav');for(const tab of ['Quests','Completed','Notes','Messages']){const b=el('button',tab);b.type='button';b.className='tool-button';b.setAttribute('aria-pressed',String(this.journalTab===tab));b.addEventListener('click',()=>{this.journalTab=tab;this.key=null;void this.sync();});tabs.append(b);}body.append(tabs);const rows=this.journalTab==='Messages'?[...world.journal.worldEntries.values()]:[...world.journal.entries.values()].filter(e=>this.journalTab==='Notes'?!e.isQuest:e.isQuest&&(this.journalTab==='Completed'?!!e.completed:!e.completed));for(const entry of rows){const item=el('article'),label=entry.title?await this.resolve(entry.title):entry.tag??'Journal entry';item.append(el('h3',label),el('p',await this.resolve(entry.description??(entry.strRef!==undefined?{strRef:entry.strRef}:null))));body.append(item);}if(!rows.length)body.append(el('p',world.journal.loaded?'No entries in this category.':'Waiting for the server journal…'));
   }else if(panel==='map'){
    // MapUi checks attachment after asynchronous resource loading. Mount its
    // skeleton before starting that load rather than presenting a detached map.
    if(generation!==this.generation||world!==this.world())return;this.host.replaceChildren(header,body);this.host.dataset.panel=panel;
    this.mapView=new NetworkMapView(body,{world:this.world,assets:this.quickbar.assets,resolve:this.resolve});await this.mapView.sync();
   }else if(panel==='options'){
    const settings=this.settings(),camera=el('label','Camera '),select=el('select');for(const [value,label]of [[1,'Top-down'],[0,'Chase'],[2,'Stiff chase']]){const option=el('option',label);option.value=value;select.append(option);}select.value=settings.cameraMode;select.setAttribute('aria-label','Camera mode');select.addEventListener('change',()=>this.setSettings({cameraMode:Number(select.value)}));camera.append(select);body.append(camera);
    const wire=el('label'),check=el('input');check.type='checkbox';check.checked=settings.wireframe;check.addEventListener('change',()=>this.setSettings({wireframe:check.checked}));wire.append(check,el('span',' Wireframe'));body.append(wire);const back=el('button','Return to game'),disconnect=el('button','Disconnect');for(const b of [back,disconnect]){b.type='button';b.className='tool-button';}back.addEventListener('click',()=>this.close());disconnect.addEventListener('click',()=>{this.close();void this.disconnect().catch(error=>this.feedback(error));});body.append(back,disconnect);
   }
  }catch(error){body.replaceChildren(el('p',error.message));runtimeDiagnostics.error(error,'network.panel-failed',{panel});}
  if(render!==this.renderVersion||generation!==this.generation||world!==this.world()||actor.id!==world.localObjectId)return;
  this.host.replaceChildren(header,body);this.host.dataset.panel=panel;this.key=key;
 }
}
