import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {networkPortrait} from './network_portrait.js';
import {GAME_HUD_ACTIONS} from './game_hud_actions.js';

const el=(tag,className,text)=>{const n=document.createElement(tag);n.className=className;if(text!==undefined)n.textContent=text;return n;};
export function networkPartyRows(world){
 if(!world)return[];const actor=world.registry.get(world.localObjectId),ids=[...(actor?.objectType===5?[{id:actor.id,self:true}]:[]),...world.party.map(e=>({id:e.id,self:false}))];
 return ids.map(row=>{
  const object=world.registry.get(row.id),available=object?.objectType===5&&!object.replicationRemoved,state=object?.replicated??{},player=[...world.players.values()].find(p=>p.objectId===row.id||p.character?.id===row.id),name=state.name??object?.appearance?.name??(player?.character?{firstName:player.character.firstName,lastName:player.character.lastName}:null),hp=state.hitPoints;
  return{...row,available,name,canLevelUp:Boolean(row.self&&object?.playerState?.combat?.canLevelUp),portrait:state.portrait??player?.character?.portrait,portraitRef:state.portraitRef??player?.character?.portraitRef,health:hp&&[hp.current,hp.fieldE8,hp.maximum].every(Number.isFinite)?{current:hp.current+hp.fieldE8,maximum:hp.maximum}:null};
 });
}
// Passive party presentation. Membership and control come only from server
// records; a portrait never creates a proxy, grants ownership or transfers control.
export class NetworkPartyView{
 constructor(viewport,{world,assets,tables,resolve,menu,select,action=()=>{}}){
  Object.assign(this,{world,assets,tables,resolve,menu,select,action});this.host=el('aside','network-party');this.host.hidden=true;this.host.setAttribute('aria-label','Player and party');viewport.append(this.host);this.reset();
 }
 reset(){this.generation=(this.generation??0)+1;this.render=0;this.key=null;this.encouraged=new Set();this.images=new Map();this.missing=new Set();this.host.hidden=true;this.host.replaceChildren();this.host.dataset.state='null';}
 encourage(id,enabled=true){if(enabled)this.encouraged.add(id);else this.encouraged.delete(id);const button=this.host.querySelector('[data-panel="'+id+'"]');if(button)button.dataset.encouraged=String(enabled);}
 async name(row){if(row.name?.firstName||row.name?.lastName)return(await Promise.all([row.name.firstName,row.name.lastName].map(v=>this.resolve(v,row.id)))).filter(Boolean).join(' ');return row.name?this.resolve(row.name,row.id):`Object ${row.id.toString(16)}`;}
 async portrait(row){return networkPortrait(this.assets(),this.tables(),row,row.self?3:2);}
 async sync(){
  const world=this.world(),assets=this.assets();if(!world||!assets)return;const generation=this.generation,render=++this.render,rows=networkPartyRows(world),key=JSON.stringify([world.tlkOverrideVersion,rows]);if(this.key===key)return;
  const values=await Promise.all(rows.map(async row=>({...row,label:await this.name(row),image:await this.portrait(row)})));if(generation!==this.generation||render!==this.render||world!==this.world()||assets!==this.assets())return;
  const fragment=document.createDocumentFragment();
  for(const row of values){const card=el('div','network-party-member'),button=el('button','network-party-portrait'),name=el('span','network-party-name',row.label),health=el('div','network-party-health');button.type='button';button.dataset.objectId=String(row.id);button.dataset.self=String(row.self);button.setAttribute('aria-label',row.label);button.title=row.label+(row.available?'':' · not currently available');button.setAttribute('aria-disabled',String(!row.available));card.dataset.objectId=String(row.id);card.dataset.controlled=String(row.self);card.dataset.available=String(row.available);
   if(row.image)button.style.backgroundImage=`url("${row.image}")`;else button.textContent='♙';
   button.addEventListener('contextmenu',event=>{event.preventDefault();event.stopPropagation();if(row.available)this.menu(row.id,event);});
   button.addEventListener('click',event=>{if(row.available)this.select(row.id,event);});
   if(row.health){health.setAttribute('role','meter');health.setAttribute('aria-label','Hit points');health.setAttribute('aria-valuemin','0');health.setAttribute('aria-valuemax',String(Math.max(1,row.health.maximum)));health.setAttribute('aria-valuenow',String(row.health.current));health.style.setProperty('--network-health',`${Math.max(0,Math.min(100,row.health.current/Math.max(1,row.health.maximum)*100))}%`);health.textContent=`${row.health.current}/${row.health.maximum}`;}else health.textContent='—';card.append(button,health);
   if(row.self){const actions=el('nav','game-party-buttons');actions.setAttribute('aria-label','Game panels');for(const [id,title,model,key]of GAME_HUD_ACTIONS){const b=el('button','game-hud-icon');b.type='button';b.dataset.panel=id;b.dataset.encouraged=String(this.encouraged.has(id));b.title=title+(key?` (${key.toUpperCase()})`:'');b.setAttribute('aria-label',title);b.textContent=title.slice(0,1);b.addEventListener('click',event=>{event.stopPropagation();this.encouraged.delete(id);b.dataset.encouraged='false';this.action(id);});actions.append(b);void assets.skin(model).then(skin=>{if(generation!==this.generation||assets!==this.assets()||!skin?.url)return;b.style.backgroundImage=`url("${skin.url}")`;b.dataset.nativeModel=model;b.textContent='';}).catch(error=>runtimeDiagnostics.error(error,'network.hud-icon-unavailable',{model}));}card.append(actions);}
   if(row.canLevelUp){const up=el('button','network-level-up-button','Level Up');up.type='button';up.setAttribute('aria-label','Level Up');up.addEventListener('click',event=>{event.stopPropagation();this.action('level-up');});card.append(up);}card.append(name);fragment.append(card);
  }
  this.key=key;this.host.replaceChildren(fragment);this.host.hidden=!values.length;this.host.dataset.state=JSON.stringify({controlledId:world.localObjectId,members:values.map(({image,...row})=>({...row,portraitLoaded:Boolean(image)}))});
 }
}
