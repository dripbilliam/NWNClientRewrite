import {intEntry} from './combat_stats.js';
import {nativeStringEntry} from './spell_metadata.js';
import {metamagicLevelCost} from './spell_book.js';
import {networkPreparationEntries} from './network_spellbook.js';
import {preparationRequest,dropPreparation} from './spell_preparation.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';

const ACTION='application/x-nwn-network-action',PREP='application/x-nwn-network-preparation';
const levels=['Cantrips','First Level','Second Level','Third Level','Fourth Level','Fifth Level','Sixth Level','Seventh Level','Eighth Level','Ninth Level'];
const numerals=['0','I','II','III','IV','V','VI','VII','VIII','IX'];
const levelIcon=level=>level===0?'ir_cantrips':level<7?`ir_level${level}`:'ir_level789';
const metas=[[0,null,'Normal'],[1,11,'Empower'],[2,12,'Extend'],[4,25,'Maximize'],[8,29,'Quicken'],[16,33,'Silent'],[32,37,'Still']];
const el=(tag,cls='',text)=>{const n=document.createElement(tag);n.className=cls;if(text!==undefined)n.textContent=text;return n;};
const button=(label,fn,cls='')=>{const b=el('button',cls,label);b.type='button';b.addEventListener('click',fn);return b;};
const stamp=s=>JSON.stringify(s??null),slotKey=w=>`${w.classIndex}:${w.level}:${w.slot}`;

// The view owns selection, collapsed trees and in-flight input indicators only.
// Slot counts, ready bits, known spells and daily uses stay server-owned.
export class NetworkSpellbookView{
 constructor({world,quickbar,resolve,prepare,close}){
  Object.assign(this,{world,quickbar,resolve,prepare,close});this.host=el('div','network-spellbooks');this.pending=new Map();this.collapsed=new Set();this.scrollPositions=new Map();this.version=0;this.level=0;this.meta=0;this.preparationVisible=true;
 }
 reset(){this.version++;this.context=null;this.signature=null;this.displayKey=null;this.scrollPositions.clear();this.pending.clear();this.widgets=new Map();clearTimeout(this.timer);this.host.replaceChildren();}
 current(context=this.context){const w=this.world();return context&&context===this.context&&context.world===w&&context.actor===w?.registry.get(w.localObjectId)&&context.areaId===w.areaId&&context.token===this.quickbar.token;}
 async sync(force=false){
  const world=this.world(),actor=world?.registry.get(world.localObjectId),rules=this.quickbar.tables;if(!world||!actor||!rules)return;
  if(!this.current()){this.reset();this.context={world,actor,areaId:world.areaId,token:this.quickbar.token};this.selected=null;this.examine=null;this.preparationVisible=true;}
  for(const [key,p]of this.pending){const s=actor.playerState?.spellbooks?.[p.classIndex]?.memorized?.[p.level]?.[p.slot];if(stamp(s)!==p.before||Date.now()-p.at>5000){this.pending.delete(key);if(stamp(s)===p.before)runtimeDiagnostics.record('network.preparation-unconfirmed','The server has not changed the requested spell slot',{classIndex:p.classIndex,level:p.level,slot:p.slot});}}
  const signature=JSON.stringify([actor.replicated?.stats?.classes,actor.playerState?.spellbooks,actor.playerState?.feats,actor.playerState?.bonusFeats,this.classIndex,this.level,this.meta,this.selected,this.examine,this.preparationVisible,[...this.collapsed],[...this.pending.keys()]]);
  if(!force&&signature===this.signature)return;if(this.displayKey)this.scrollPositions.set(this.displayKey,{known:this.host.querySelector('.network-spell-list')?.scrollTop??0,memory:this.host.querySelector('.network-memorized-levels')?.scrollTop??0});this.signature=signature;const version=++this.version,context=this.context;
  try{const content=await this.render(context);if(version!==this.version||!this.current(context))return;this.host.replaceChildren(...content);this.displayKey=`${this.classIndex}:${this.level}:${this.meta}`;const scroll=this.scrollPositions.get(this.displayKey);if(scroll){const known=this.host.querySelector('.network-spell-list'),memory=this.host.querySelector('.network-memorized-levels');if(known)known.scrollTop=scroll.known;if(memory)memory.scrollTop=scroll.memory;}this.host.dataset.state=JSON.stringify({classIndex:this.classIndex,level:this.level,metamagic:this.meta,pending:[...this.pending.keys()],memorization:!!this.host.querySelector('.network-memorized-spells'),known:this.host.querySelectorAll('.network-spell-row').length,ready:this.host.querySelectorAll('.network-memorized-slot[data-spell-ready="1"]').length,used:this.host.querySelectorAll('.network-memorized-slot[data-spell-ready="0"][data-empty="false"]').length,empty:this.host.querySelectorAll('.network-memorized-slot[data-empty="true"]').length});}
  catch(error){if(version===this.version&&this.current(context)){this.host.replaceChildren(el('p','',error.message));this.failure(error);}}
 }
 refresh(){void this.sync(true);}
 failure(error){runtimeDiagnostics.error(error,'network.spellbook-ui-failed');const feedback=document.querySelector('#network-feedback');if(feedback)feedback.textContent=error.message;}
 async image(name){const url=await this.quickbar.icon(name);if(!url)return null;const image=el('img','');image.src=url;image.alt='';image.draggable=false;return image;}
 async skin(node,model){const skin=await this.quickbar.assets.skin(model);if(skin?.url){node.style.backgroundImage=`url("${skin.url}")`;node.style.backgroundSize='100% 100%';node.dataset.nativeModel=model;node.textContent='';}}
 async spellIcon(id){return this.image(nativeStringEntry(this.quickbar.tables.spells,id,'IconResRef').value);}
 binding(widget){return{type:2,intParam:widget.id,classIndex:widget.classIndex,metamagic:widget.metamagic,domainLevel:widget.domain?(widget.level-metamagicLevelCost(this.quickbar.tables,widget.metamagic))&255:0};}
 drag(node,widget,key,context){
  node.draggable=widget.id>=0;if(!node.draggable)return;
  node.addEventListener('dragstart',event=>{if(!this.current(context)||!this.widgetCurrent(widget)){event.preventDefault();return;}
   event.dataTransfer.setData(ACTION,JSON.stringify({token:context.token,actorId:context.actor.id,binding:this.binding(widget)}));
   event.dataTransfer.setData(PREP,JSON.stringify({token:context.token,actorId:context.actor.id,areaId:context.areaId,key,widget}));event.dataTransfer.effectAllowed='copyMove';});
 }
 widgetCurrent(widget){
  if(!this.current()||widget.classIndex!==this.classIndex)return false;const {actor}=this.context,rules=this.quickbar.tables;
  if(widget.kind===0){const pool=actor.playerState?.spellbooks?.[widget.classIndex]?.memorized?.[widget.level];return widget.slot<(pool?.length??0)&&widget.id===(pool[widget.slot]?.spell??-1)&&widget.ready===(pool[widget.slot]?.ready??0)&&widget.domain===(pool[widget.slot]?.domain??0)&&widget.metamagic===(pool[widget.slot]?.metamagic??0);}
  const level=widget.level-metamagicLevelCost(rules,widget.metamagic);return level>=0&&networkPreparationEntries(actor,rules,widget.classIndex,level,widget.metamagic).some(s=>s.id===widget.id&&s.domain===widget.domain);
 }
 async submit(widget,clear=false){
  if(!this.widgetCurrent(widget))throw new Error('Spell preparation selection is stale');const context=this.context,key=slotKey(widget);if(this.pending.has(key))throw new Error('That slot is waiting for the server');
  const before=context.actor.playerState.spellbooks[widget.classIndex].memorized[widget.level][widget.slot];
  this.pending.set(key,{classIndex:widget.classIndex,level:widget.level,slot:widget.slot,before:stamp(before),at:Date.now()});this.refresh();
  try{await this.prepare(clear?{clear:true,classIndex:widget.classIndex,level:widget.level,slot:widget.slot}:preparationRequest(widget,{metamagicCost:m=>metamagicLevelCost(this.quickbar.tables,m)}));}
  catch(error){if(this.current(context)){this.pending.delete(key);this.refresh();}throw error;}
  if(this.current(context)){clearTimeout(this.timer);this.timer=setTimeout(()=>this.refresh(),5100);}
 }
 async memorize(source){
  try{if(!this.widgetCurrent(source))return;const slots=this.context.actor.playerState.spellbooks?.[source.classIndex]?.memorized?.[source.level]??[],slot=slots.findIndex((s,i)=>!s&&!this.pending.has(`${source.classIndex}:${source.level}:${i}`));if(slot<0)throw new Error('No empty spell slots at that level');
   const destination={...source,kind:0,slot,id:-1,domain:0,metamagic:0,ready:0};await this.setDestination(destination,source);
  }catch(error){this.failure(error);}
 }
 async setDestination(destination,source){
  if(source.kind===0&&slotKey(source)===slotKey(destination))return;
  if(!this.widgetCurrent(source)||!this.widgetCurrent(destination))throw new Error('Spell preparation drag is stale');
  // Ported drop policy operates on widget copies. Queue both exchange writes
  // in native order; never write into actor.playerState as a preview.
  const requests=[],sourceCopy={...source},destinationCopy={...destination};
  await dropPreparation(destinationCopy,sourceCopy,0,{set:(widget,id,_send,domain,metamagic,classIndex)=>{
   const original=widget===sourceCopy?source:destination;
   // Source validation uses the old record, while the wire request uses its
   // new spell. Reserve before sending so rapid arrows choose separate slots.
   requests.push(this.submitReplacement(original,{...widget,id,domain,metamagic,classIndex}));
  },tint:()=>{}});await Promise.all(requests);
 }
 async submitReplacement(original,next){
  if(!this.widgetCurrent(original))throw new Error('Spell slot has changed');
  // submit validates the old physical slot; conversion is built from new data.
  const context=this.context,key=slotKey(original);if(this.pending.has(key))throw new Error('That slot is waiting for the server');
  const before=context.actor.playerState.spellbooks[original.classIndex].memorized[original.level][original.slot];
  this.pending.set(key,{classIndex:original.classIndex,level:original.level,slot:original.slot,before:stamp(before),at:Date.now()});this.refresh();
  try{await this.prepare(preparationRequest(next,{metamagicCost:m=>metamagicLevelCost(this.quickbar.tables,m)}));}
  catch(error){if(this.current(context)){this.pending.delete(key);this.refresh();}throw error;}
  if(this.current(context)){clearTimeout(this.timer);this.timer=setTimeout(()=>this.refresh(),5100);}
 }
 async drop(destination,encoded){try{const payload=JSON.parse(encoded);if(!this.current()||payload.token!==this.context.token||payload.actorId!==this.context.actor.id||payload.areaId!==this.context.areaId)return;const source=this.widgets.get(payload.key);if(!source||stamp(source)!==stamp(payload.widget)||!this.widgetCurrent(source)||!this.widgetCurrent(destination)||source.classIndex!==destination.classIndex)return;await this.setDestination(destination,source);}catch(error){this.failure(error);}}
 async render(context){
  const {actor}=context,rules=this.quickbar.tables,classes=actor.replicated?.stats?.classes??[],books=actor.playerState?.spellbooks??{};
  const choices=classes.map((c,index)=>({...c,index})).filter(c=>intEntry(rules.classes,c.id,'SpellCaster').value!==0);
  if(!choices.length)return[el('p','','This character has no class spellbooks.')];
  if(!choices.some(c=>c.index===this.classIndex))this.classIndex=choices[0].index;
  const cls=classes[this.classIndex],book=books[this.classIndex]??{},prepared=intEntry(rules.classes,cls.id,'MemorizesSpells').value!==0,name=await this.quickbar.ruleName('classes',cls.id),known=el('section','network-spell-window network-known-spells'),header=el('header');
  const close=button('×',()=>this.close(),'network-spell-close');close.setAttribute('aria-label','Close spellbook');await this.skin(close,'ctl_btn_x');header.append(el('h2','',`${name} Spells`),close);known.append(header);
  const tabs=el('nav','network-spell-classes');tabs.setAttribute('aria-label','Class spellbooks');
  for(const c of choices){const label=await this.quickbar.ruleName('classes',c.id),b=button('',()=>{this.classIndex=c.index;this.selected=null;this.examine=null;this.meta=0;this.preparationVisible=true;this.refresh();});b.title=label;b.setAttribute('aria-label',label);b.setAttribute('aria-pressed',String(this.classIndex===c.index));b.dataset.classIndex=c.index;const image=await this.image(nativeStringEntry(rules.classes,c.id,'Icon').value);b.append(image??el('span','',label));tabs.append(b);}known.append(tabs);
  const levelTabs=el('nav','network-spell-levels');levelTabs.setAttribute('aria-label','Spell levels');
  for(let level=0;level<10;level++){const b=button(numerals[level],()=>{this.level=level;this.selected=null;this.examine=null;this.refresh();});b.title=levels[level];b.setAttribute('aria-label',levels[level]);b.setAttribute('aria-pressed',String(this.level===level));b.dataset.spellLevel=level;const icon=await this.image(levelIcon(level));if(icon){b.textContent="";b.append(icon);}levelTabs.append(b);}known.append(levelTabs);
  const owned=new Set([...(actor.playerState?.feats??[]),...(actor.playerState?.bonusFeats??[])]),available=metas.filter(([,feat])=>feat===null||owned.has(feat));if(!available.some(([mask])=>mask===this.meta))this.meta=0;
  if(available.length>1){const label=el('label','network-spell-meta','Metamagic '),select=el('select');select.setAttribute('aria-label','Metamagic');for(const [mask,,label]of available){const option=el('option','',label);option.value=mask;select.append(option);}select.value=this.meta;select.addEventListener('change',()=>{this.meta=Number(select.value);this.selected=null;this.refresh();});label.append(select);known.append(label);}
  const list=el('div','network-spell-list'),heading=el('div','network-spell-tree-heading',`▾  ${numerals[this.level]}  Known`);known.append(list);list.append(heading);this.widgets=new Map();
  const base=this.level-metamagicLevelCost(rules,this.meta),entries=base>=0?networkPreparationEntries(actor,rules,this.classIndex,base,this.meta):[];
  const named=await Promise.all(entries.map(async(s,n)=>({...s,n,label:await this.quickbar.ruleName('spells',s.id)})));named.sort((a,b)=>a.label.localeCompare(b.label)||a.n-b.n);
  for(const s of named){const key=`known:${this.classIndex}:${this.level}:${this.meta}:${s.n}`,widget={type:0x53704278,classIndex:this.classIndex,kind:1,level:this.level,slot:0,id:s.id,metamagic:s.metamagic,domain:s.domain,ready:0},row=el('div','network-panel-spell network-spell-row');this.widgets.set(key,widget);row.dataset.spellId=s.id;row.dataset.spellClassIndex=this.classIndex;row.dataset.spellDomain=s.domain;row.dataset.spellMetamagic=s.metamagic;row.setAttribute('role','button');row.tabIndex=0;row.setAttribute('aria-selected',String(this.selected===key));const image=await this.spellIcon(s.id);if(image)row.append(image);row.append(el('span','network-spell-name',s.label+(s.domain?' · Domain':'')));
   const select=()=>{if(!this.current(context))return;this.selected=key;this.examine=null;this.refresh();};row.addEventListener('click',select);row.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();select();}});this.drag(row,widget,key,context);
   if(this.selected===key){const actions=el('span','network-spell-row-actions'),examine=button('?',e=>{e.stopPropagation();if(this.current(context)){this.examine=s.id;this.refresh();}});examine.title='Examine spell';examine.setAttribute('aria-label','Examine '+s.label);await this.skin(examine,'ctl_cg_btn_help');actions.append(examine);
    if(prepared){const arrow=button('➤',e=>{e.stopPropagation();if(this.current(context))void this.memorize(widget);});arrow.title='Memorize in next empty slot';arrow.setAttribute('aria-label','Memorize '+s.label);arrow.dataset.memorizeSpell=s.id;arrow.disabled=!(book.memorized?.[this.level]??[]).some((s,i)=>!s&&!this.pending.has(`${this.classIndex}:${this.level}:${i}`));await this.skin(arrow,'ctl_spl_btn_arow');actions.append(arrow);}row.append(actions);}
   list.append(row);
  }
  if(!entries.length)list.append(el('p','network-spell-empty','No known spells at this level.'));
  if(!prepared)known.append(el('p','network-spell-note',`${book.usesLeft?.[this.level]??0} casts remaining at this level`));
  if(prepared&&!this.preparationVisible)known.append(button('Memorize Spells',()=>{this.preparationVisible=true;this.refresh();}));
  const result=[known];if(prepared&&this.preparationVisible){const memory=el('section','network-spell-window network-memorized-spells'),h=el('header');h.append(el('h2','','Memorize Spells'),button('×',()=>{this.preparationVisible=false;this.refresh();},'network-spell-close'));memory.append(h);const scroll=el('div','network-memorized-levels');memory.append(scroll);
   for(let level=0;level<10;level++){const section=el('section','network-memorized-level'),collapsed=this.collapsed.has(level),toggle=button(`${collapsed?'▸':'▾'}  ${numerals[level]}  ${levels[level]}`,()=>{if(this.collapsed.has(level))this.collapsed.delete(level);else this.collapsed.add(level);this.refresh();},'network-spell-tree-heading');toggle.setAttribute('aria-expanded',String(!collapsed));toggle.dataset.memorizedLevel=level;const levelImage=await this.image(levelIcon(level));if(levelImage){toggle.replaceChildren(el("span","",collapsed?"▸":"▾"),levelImage,el("span","",levels[level]));}section.append(toggle);const slots=el('div','network-memorized-slots');slots.hidden=collapsed;
    for(const [slot,s]of(book.memorized?.[level]??[]).entries()){const widget={type:0x53704278,classIndex:this.classIndex,kind:0,level,slot,id:s?.spell??-1,metamagic:s?.metamagic??0,domain:s?.domain??0,ready:s?.ready??0},key=`slot:${this.classIndex}:${level}:${slot}`,b=button('',()=>{},'network-memorized-slot');this.widgets.set(key,widget);b.dataset.preparationSlot=slot;b.dataset.preparationLevel=level;b.dataset.spellId=widget.id;b.dataset.spellReady=Number(widget.ready!==0);b.dataset.empty=String(!s);b.dataset.pending=String(this.pending.has(slotKey(widget)));const label=s?await this.quickbar.ruleName('spells',s.spell):'Empty slot';b.title=`${levels[level]} · ${label}${s?(s.ready?' · Ready':' · Used / rest required'):''}${s?.domain?' · Domain':''}`;b.setAttribute('aria-label',b.title);if(s){const image=await this.spellIcon(s.spell);if(image)b.append(image);if(s.metamagic)b.append(el('small','network-spell-metamagic',metas.find(([mask])=>mask===s.metamagic)?.[2]?.slice(0,1)??String(s.metamagic)));}this.drag(b,widget,key,context);
     b.addEventListener('dragover',e=>{if(e.dataTransfer.types.includes(PREP)){e.preventDefault();b.classList.add('drag-over');}});b.addEventListener('dragleave',()=>b.classList.remove('drag-over'));b.addEventListener('drop',e=>{e.preventDefault();b.classList.remove('drag-over');if(this.current(context))void this.drop(widget,e.dataTransfer.getData(PREP));});
     const clear=e=>{e.preventDefault();if(s&&this.current(context))void this.submit(widget,true).catch(error=>this.failure(error));};b.addEventListener('dblclick',clear);b.addEventListener('contextmenu',clear);slots.append(b);
    }section.append(slots);scroll.append(section);
   }memory.append(el('p','network-spell-note','Drag spells into slots. Right-click a slot to clear it. Rest to ready new preparations.'));result.push(memory);}
  if(this.examine!==null&&this.examine!==undefined){const dialog=el('section','network-spell-examine network-spell-window');dialog.setAttribute('role','dialog');dialog.setAttribute('aria-label','Examine spell');const h=el('header');h.append(el('h2','',await this.quickbar.ruleName('spells',this.examine)),button('×',()=>{this.examine=null;this.refresh();},'network-spell-close'));dialog.append(h);const image=await this.spellIcon(this.examine);if(image)dialog.append(image);const description=intEntry(rules.spells,this.examine,'SpellDesc');dialog.append(el('p','',description.found?await this.resolve({strRef:description.value>>>0}):'No description available.'));result.push(dialog);}
  return result;
 }
}
