import {NativeUiAssets} from './native_ui_assets.js';
import {RESOURCE_TYPE,decodeResourceText} from './resource_archive.js';
import {parse2da} from './area.js';
import {intEntry} from './combat_stats.js';
import {nativeStringEntry} from './spell_metadata.js';
import {quickbarAssignmentMenu} from './quickbar_menu.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {configureNetworkItemShortcut,networkItemQuickbarProviders} from './network_quickbar_items.js';
import {updateItemQuickbarCount} from './item_quickbar.js';
import {metamagicLevelCost} from './spell_book.js';
import {networkSpellUsesLeft,networkSpellLikeUses,networkPreparationEntries} from './network_spellbook.js';
import {networkFeatUses} from './network_feat_input.js';
import {networkAssociateShortcutChoices,networkAssociateShortcutPresentation} from './network_associate_input.js';
const MIME='application/x-nwn-network-quickbar',ITEM='application/x-nwn-network-item',ACTION='application/x-nwn-network-action';
const el=(tag,className,text)=>{const n=document.createElement(tag);n.className=className;if(text!==undefined)n.textContent=text;return n;};

// Client-owned shortcut widgets backed by replicated character/items/spells.
// Assignment uses native30/2; activation delegates to typed multiplayer input.
export class NetworkQuickbarView{
 constructor(viewport,{world,assign,use,resolve,menu,inventoryToken,canUse=()=>true}){
  Object.assign(this,{world,requestAssign:assign,use,resolve,menu,inventoryToken,canUse});this.generation=0;this.pending=new Set();this.icons=new Map();this.labels=new Map();this.page=0;
  this.host=el('div','game-quickbar network-quickbar');this.host.hidden=true;this.host.setAttribute('aria-label','Multiplayer quickbar');viewport.append(this.host);this.pages=el('nav','game-quick-pages');this.host.append(this.pages);this.slots=el('div','game-quick-slots');this.host.append(this.slots);
  for(let page=0;page<3;page++){const b=el('button','game-button game-quick-page',String(page+1));b.type='button';b.addEventListener('click',()=>{this.page=page;void this.sync(page);});this.pages.append(b);}
  for(let i=0;i<12;i++){
   const b=el('button','game-button game-quick-slot');b.type='button';b.dataset.slot=String(i);b.append(el('span','game-slot-number','F'+(i+1)),el('span','game-slot-icon'),el('span','game-slot-uses'));b.draggable=true;this.slots.append(b);
   b.addEventListener('click',()=>this.activate(this.currentPage()*12+i));
   b.addEventListener('contextmenu',event=>{event.preventDefault();void this.openMenu(this.currentPage()*12+i,event);});
   b.addEventListener('dragstart',event=>{const sourceIndex=this.currentPage()*12+i,binding=this.world()?.quickbar[sourceIndex];if(!binding?.type){event.preventDefault();return;}event.dataTransfer.setData(MIME,JSON.stringify({token:this.token,sourceIndex,binding}));event.dataTransfer.effectAllowed='move';});
   b.addEventListener('dragover',event=>{if([MIME,ITEM,ACTION].some(t=>event.dataTransfer.types.includes(t))){event.preventDefault();b.classList.add('drag-over');}});b.addEventListener('dragleave',()=>b.classList.remove('drag-over'));
   b.addEventListener('drop',event=>{event.preventDefault();event.stopPropagation();b.classList.remove('drag-over');void this.drop(this.currentPage()*12+i,event);});
  }
  window.addEventListener('keydown',event=>{if(this.host.hidden||!this.canUse()||event.target.closest?.('input,textarea,select,[contenteditable=true]'))return;if(event.key==='Shift'||event.key==='Control')void this.sync(event.ctrlKey?2:event.shiftKey?1:this.page);const match=/^F([1-9]|1[0-2])$/.exec(event.key);if(match&&!event.repeat){event.preventDefault();event.stopImmediatePropagation();this.activate((event.ctrlKey?2:event.shiftKey?1:this.page)*12+Number(match[1])-1);}},true);
  window.addEventListener('keyup',event=>{if(['Shift','Control'].includes(event.key)&&!this.host.hidden)void this.sync(event.ctrlKey?2:event.shiftKey?1:this.page);});window.addEventListener('blur',()=>{if(!this.host.hidden)void this.sync(this.page);});
 }
 currentPage(){return this.displayPage??this.page;}
 reset(){this.generation++;this.renderGeneration=0;this.host.hidden=true;this.host.dataset.state='null';this.assets?.dispose();this.assets=null;this.tables=null;this.icons.clear();this.labels.clear();this.pending.clear();this.page=0;this.displayPage=0;this.token=crypto.randomUUID();}
 async attach(resolver){
  this.reset();const generation=this.generation,assets=this.assets=new NativeUiAssets(resolver),names=['baseitems','appearance','iprp_spells','spells','classes','feat','skills','ruleset','domains','racialtypes','portraits'];
  try{
   const [tables,skin]=await Promise.all([Promise.all(names.map(async name=>[name,parse2da(decodeResourceText(await resolver.getResource(name,RESOURCE_TYPE.TWO_DA)))])),assets.skin('qb_but66'),assets.initializeFonts()]);
   if(this.generation!==generation){assets.dispose();return;}
   this.tables=Object.fromEntries(tables);if(skin?.url)for(const b of this.slots.children){b.style.backgroundImage=`url("${skin.url}")`;b.dataset.nativeModel='qb_but66';}this.host.hidden=false;await this.sync();
  }catch(error){assets.dispose();if(this.generation===generation){this.reset();throw error;}}
 }
 async ruleName(table,id,column='Name'){const key=table+':'+id+':'+column;if(!this.labels.has(key)){const v=intEntry(this.tables[table],id,column);this.labels.set(key,v.found?this.resolve({strRef:v.value>>>0}):Promise.resolve('Action '+id));}return this.labels.get(key);}
 async describe(b){
  if(!b?.type)return null;const world=this.world();
  if([38,39,42].includes(b.type))return networkAssociateShortcutPresentation(b,world);
  if(b.type===1){const o=world.registry.get(b.itemId);if(!o?.item)return{label:'Unavailable item'};const presentation={},p=networkItemQuickbarProviders(world,this.tables,presentation);updateItemQuickbarCount(b,p);return{label:await this.resolve(o.item.name),...presentation};}
  const table=b.type===2||b.type===44?'spells':b.type===4?'feat':b.type===3?'skills':null;
  if(table){const id=b.type===4?b.intParam&65535:b.intParam,result={label:await this.ruleName(table,id,table==='feat'?'FEAT':'Name'),icon:nativeStringEntry(this.tables[table],id,table==='spells'?'IconResRef':'Icon').value};if(b.type===2||b.type===44||b.type===4){const actor=world.registry.get(world.localObjectId),count=b.type===4?networkFeatUses(actor,this.tables,id):b.type===44?networkSpellLikeUses(actor,b.intParam,b.domainLevel&15):networkSpellUsesLeft(actor,this.tables,b.intParam,b.classIndex&7,b.domainLevel&15,b.metamagic&63);result.uses=b.type===4&&count===100?'':String(count);result.enabled=count!==0;}return result;}
  return{label:b.commandLabel||b.toolTip||'Quickbar action '+b.type};
 }
 async icon(name){if(!name||name==='****')return null;const assets=this.assets;if(!this.icons.has(name))this.icons.set(name,(async()=>{const {image}=await assets.texture(name),c=document.createElement('canvas');c.width=image.width;c.height=image.height;c.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(image.data),image.width,image.height),0,0);return c.toDataURL();})());return this.icons.get(name);}
 async sync(page=this.currentPage()){
  if(this.host.hidden||!this.tables||!this.world())return;const generation=this.generation,render=this.renderGeneration=(this.renderGeneration??0)+1;this.displayPage=page;const world=this.world(),entries=world.quickbar.slice(page*12,page*12+12),descriptions=await Promise.all(entries.map(b=>this.describe(b)));if(generation!==this.generation||render!==this.renderGeneration)return;
  for(const [i,b]of [...this.slots.children].entries()){const value=entries[i],d=descriptions[i],index=page*12+i,icon=b.querySelector('.game-slot-icon');b.dataset.quickbarIndex=String(index);b.dataset.quickbarType=String(value?.type??0);b.title=d?.label??`F${i+1} · Assign shortcut`;b.setAttribute('aria-label',b.title);b.disabled=this.pending.has(index)||d?.enabled===false;b.setAttribute('aria-disabled',String(d?.enabled===false));b.dataset.equipped=String(d?.animation==='qbEquip');b.querySelector('.game-slot-uses').textContent=d?.uses??'';const key=JSON.stringify([value,d]);if(b.dataset.binding!==key){b.dataset.binding=key;icon.replaceChildren();if(d){icon.textContent=d.label.slice(0,4);if(d.icon)void this.icon(d.icon).then(url=>{if(url&&generation===this.generation&&b.dataset.binding===key){const img=el('img','');img.alt='';img.src=url;icon.replaceChildren(img);}}).catch(e=>{if(generation===this.generation&&b.dataset.binding===key)this.failure(e,'network.quickbar-icon-unavailable');});}}}
  for(const [i,b]of [...this.pages.children].entries())b.setAttribute('aria-current',String(i===page));this.host.dataset.state=JSON.stringify({page,buttons:world.quickbar,pending:[...this.pending]});
 }
 async choices(){const w=this.world(),actor=w?.registry.get(w.localObjectId),groups=[{slot:2,label:'Items',icon:'IR_USE',entries:[]},{slot:1,label:'Spells',icon:'IR_CAST',entries:[]},{slot:3,label:'Feats',icon:'IR_XABILITY',entries:[]},{slot:4,label:'Skills',icon:'IR_STEALTH',entries:[]}];if(!actor)return groups;
  for(const o of w.registry.objects.values())if(o.objectType===6&&!o.replicationRemoved&&(o.inventoryLocation?.ownerId===actor.id||w.quickbar.some(b=>b.type===1&&(b.itemId===o.id||b.secondaryItemId===o.id))))groups[0].entries.push({label:await this.resolve(o.item.name),binding:{type:1,itemId:o.id,intParam:0xff00ff}});
  for(const [index,book]of Object.entries(actor.playerState?.spellbooks??{})){const seen=new Set(),add=async(id,metamagic=0,domainLevel=0)=>{const key=[id,metamagic,domainLevel].join(':');if(seen.has(key))return;seen.add(key);groups[1].entries.push({label:await this.ruleName('spells',id),binding:{type:2,intParam:id,classIndex:Number(index),metamagic,domainLevel}});};const owned=new Set([...(actor.playerState?.feats??[]),...(actor.playerState?.bonusFeats??[])]),masks=[0,...[[1,11],[2,12],[4,25],[8,29],[16,33],[32,37]].filter(([,feat])=>owned.has(feat)).map(([mask])=>mask)];for(const mask of masks)for(let level=0;level+metamagicLevelCost(this.tables,mask)<10;level++)for(const s of networkPreparationEntries(actor,this.tables,Number(index),level,mask))await add(s.id,mask,s.domain?level:0);for(const [level,slots]of Object.entries(book.memorized??{}))for(const s of slots)if(s)await add(s.spell,s.metamagic,s.domain?(Number(level)-metamagicLevelCost(this.tables,s.metamagic))&255:0);}
  for(const id of new Set([...(actor.playerState?.feats??[]),...(actor.playerState?.bonusFeats??[]),...(actor.inventoryStats?.feats??[]).map(v=>v.id)]))groups[2].entries.push({label:await this.ruleName('feat',id,'FEAT'),binding:{type:4,intParam:id}});
  for(const s of actor.inventoryStats?.skills??[])if(s.value>0)groups[3].entries.push({label:await this.ruleName('skills',s.index),binding:{type:3,intParam:s.index}});
  groups.push({slot:5,label:'Abilities',icon:'IR_XABILITY',entries:await Promise.all((actor.playerState?.specialAbilities??[]).filter(Boolean).map(async a=>({label:await this.ruleName('spells',a.spell),binding:{type:44,intParam:a.spell,domainLevel:a.level}})))});
  groups.push({slot:0,label:'Commands',icon:'IR_COMMAND',entries:networkAssociateShortcutChoices(w,actor)});return groups;
 }
 async openMenu(index,event){try{const generation=this.generation,actorId=this.world()?.localObjectId,groups=await this.choices();if(generation===this.generation&&actorId===this.world()?.localObjectId&&!this.host.hidden)this.menu(quickbarAssignmentMenu('Assign F'+(index%12+1),groups),index,event);}catch(e){this.failure(e);}}
 async assign(index,binding,{configure=true}={}){if(this.pending.has(index))return false;const generation=this.generation;this.pending.add(index);try{if(binding?.type===1&&configure){const result=configureNetworkItemShortcut(this.world(),this.tables,this.world().quickbar[index],binding,{feedback:()=>{},report:(...a)=>runtimeDiagnostics.record(...a)});if(!result)throw new Error('That item cannot be assigned');binding=result.button;}await this.requestAssign(index,binding);if(generation!==this.generation)return false;await this.sync();return true;}catch(e){if(generation===this.generation)this.failure(e);return false;}finally{if(generation===this.generation){this.pending.delete(index);await this.sync();}}}
 async drop(index,event){try{let payload;if(event.dataTransfer.types.includes(MIME)){payload=JSON.parse(event.dataTransfer.getData(MIME));if(payload.token!==this.token||!Number.isInteger(payload.sourceIndex)||JSON.stringify(payload.binding)!==JSON.stringify(this.world().quickbar[payload.sourceIndex]))throw new Error('Shortcut drag is stale');if(payload.sourceIndex===index)return;if(!await this.assign(index,payload.binding,{configure:false}))return;if(JSON.stringify(payload.binding)===JSON.stringify(this.world().quickbar[payload.sourceIndex]))await this.assign(payload.sourceIndex,null);}
   else if(event.dataTransfer.types.includes(ACTION)){payload=JSON.parse(event.dataTransfer.getData(ACTION));const dragWorld=this.world(),generation=this.generation;if(payload.token!==this.token||payload.actorId!==dragWorld?.localObjectId)throw new Error('Action drag is stale');if(payload.binding?.type!==1){if(![2,3,4,44].includes(payload.binding?.type)||(await this.choices()).flatMap(g=>g.entries).every(e=>JSON.stringify(e.binding)!==JSON.stringify(payload.binding)))throw new Error('Action is no longer available to this character');}if(generation!==this.generation||dragWorld!==this.world()||payload.token!==this.token||payload.actorId!==this.world()?.localObjectId)throw new Error('Action drag is stale');await this.assign(index,payload.binding,{configure:false});}
   else{payload=JSON.parse(event.dataTransfer.getData(ITEM));if(payload.token!==this.inventoryToken())throw new Error('Inventory drag is stale');await this.assign(index,{type:1,itemId:payload.itemId,intParam:0xff00ff});}}catch(e){this.failure(e);}}
 activate(index){if(!this.canUse()||this.pending.has(index))return;const world=this.world(),b=world?.quickbar[index];try{const actor=world?.registry.get(world.localObjectId);if(b?.type===2&&networkSpellUsesLeft(actor,this.tables,b.intParam,b.classIndex&7,b.domainLevel&15,b.metamagic&63)===0||b?.type===44&&networkSpellLikeUses(actor,b.intParam,b.domainLevel&15)===0||b?.type===4&&networkFeatUses(actor,this.tables,b.intParam)===0)return;if(b?.type)this.use(b,index);}catch(e){this.failure(e,'network.quickbar-activation-failed');}}
 failure(error,code='network.quickbar-ui-failed'){runtimeDiagnostics.error(error,code);document.querySelector('#network-feedback').textContent=error.message;}
}
