import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {EQUIPMENT_SLOTS} from './character.js';
import {intEntry} from './combat_stats.js';
const MIME='application/x-nwn-network-item';
// Original creature repository construction37a702..37a71b:10x36,
// boundary60 => six pages of six rows. These are native storage constants;
// item sizes and allowed slots still come from the selected baseitems.2DA.
const columns=10,pageRows=6,pages=6,cell=33;

// Presentation reads the canonical server proxies. Window requests control
// native replication; no BIC inventory or singleplayer rules run here.
export class NetworkInventoryView{
 constructor(viewport,{world,request,resolve,onVisibility,action,baseItems,panel,itemMenu,activate}){
  Object.assign(this,{world,request,resolve,onVisibility,action,baseItems,panel,itemMenu,activate});this.generation=0;this.pendingItems=new Map();this.page=0;this.dragToken=crypto.randomUUID();
  this.host=document.createElement('section');this.host.className='network-inventory';this.host.hidden=true;this.host.setAttribute('aria-label','Inventory');this.host.innerHTML='<header><h2>Inventory</h2><button type="button" class="tool-button">Close</button></header><p role="status"></p><div class="network-inventory-columns"><section><h3>Equipment</h3><ul class="network-equipment"></ul></section><section><h3>Backpack</h3><nav class="game-repository-pages" aria-label="Inventory pages"></nav><div class="game-repository-grid network-backpack"></div></section></div>';viewport.append(this.host);
  this.status=this.host.querySelector('[role=status]');this.equipment=this.host.querySelector('.network-equipment');this.backpack=this.host.querySelector('.network-backpack');this.host.querySelector('button').addEventListener('click',()=>this.toggle(false));
  this.button=document.querySelector('#network-inventory-button');this.button.addEventListener('click',()=>this.toggle());
  this.pager=this.host.querySelector('nav');for(let page=0;page<pages;page++){const b=document.createElement('button');b.type='button';b.className='tool-button';b.textContent=String(page+1);b.dataset.page=String(page);b.addEventListener('click',()=>this.choosePage(page));this.pager.append(b);}
  Object.assign(this.backpack.style,{width:`${columns*cell}px`,height:`${pageRows*cell}px`});this.backpack.style.setProperty('--repository-cell',`${cell}px`);
  this.acceptDrop(this.backpack,(item,event)=>{const rect=this.backpack.getBoundingClientRect(),x=Math.floor((event.clientX-rect.left)/cell),row=Math.floor((event.clientY-rect.top)/cell);if(x<0||x>=columns||row<0||row>=pageRows)return;void this.submit(item.id,item.inventoryLocation.channel==='I'?'unequip':'move',{x,y:row+this.page*pageRows});});
  window.addEventListener('keydown',event=>{if(!this.world()||event.repeat||event.ctrlKey||event.altKey||event.metaKey||/^(INPUT|TEXTAREA|SELECT)$/.test(event.target.tagName))return;if(event.key.toLowerCase()==='i'||event.key==='Escape'&&this.active){event.preventDefault();event.stopPropagation();void this.toggle(!this.active);}},true);
 }
 get active(){return!this.host.hidden;}
 reset(){this.generation++;this.host.hidden=true;this.pending=false;this.pendingItems.clear();this.page=0;this.dragToken=crypto.randomUUID();this.button.disabled=false;this.equipment.replaceChildren();this.backpack.replaceChildren();this.host.dataset.state='null';this.onVisibility(false);}
 async toggle(open=!this.active){
  if(this.pending)return;const generation=++this.generation;this.pending=true;this.button.disabled=true;this.status.textContent='';
  try{await this.request(open);if(generation!==this.generation)return;if(open)await this.panel(this.page);if(generation!==this.generation)return;this.host.hidden=!open;this.onVisibility(open);if(open)await this.sync();else this.host.dataset.state='null';}
  catch(error){if(generation!==this.generation)return;this.status.textContent=error.message;runtimeDiagnostics.error(error,'network.inventory-window-failed');}
  finally{if(generation===this.generation){this.pending=false;this.button.disabled=false;}}
 }
 async sync(){
  if(!this.active)return;const generation=this.generation,renderGeneration=this.renderGeneration=(this.renderGeneration??0)+1,w=this.world();if(!w)return;
  const table=await this.baseItems();if(generation!==this.generation||renderGeneration!==this.renderGeneration)return;
  const rows=await Promise.all(['I','R'].map(async channel=>Promise.all((w.inventories.get(channel)?.entries??[]).map(async location=>{
   const object=w.registry.get(location.id),item=object?.item;if(!item)throw new Error('Replicated inventory item is unavailable');
   const entry=name=>{const v=intEntry(table,item.baseItem,name);if(!v.found)throw new Error(`Native item ${name} is unavailable`);return v.value;};
   return{...location,name:await this.resolve(item.name),identified:item.identified,canUse:item.canUse,stackSize:item.stackSize??item.field454,slotMask:entry('EquipableSlots')>>>0,width:entry('InvSlotWidth')&255,height:entry('InvSlotHeight')&255};
  }))));if(generation!==this.generation||renderGeneration!==this.renderGeneration)return;
  this.equipment.replaceChildren();this.backpack.replaceChildren();
  for(const [index,name]of EQUIPMENT_SLOTS.entries()){
   const slot=1<<index,row=rows[0].find(v=>v.slot===slot),li=document.createElement('li'),label=document.createElement('span');label.textContent=name;li.dataset.slot=String(slot);li.append(label);if(row)li.append(this.itemButton(row));else li.append(document.createTextNode(' —'));this.acceptDrop(li,item=>void this.submit(item.id,'equip',{slot}));this.equipment.append(li);
  }
  for(const row of rows[1]){
   if(Math.floor((row.y*columns+row.x)/(columns*pageRows))!==this.page)continue;
   const button=this.itemButton(row);button.classList.add('game-repository-item');Object.assign(button.style,{left:`${row.x*cell}px`,top:`${(row.y-this.page*pageRows)*cell}px`,width:`${Math.max(1,row.width)*cell-1}px`,height:`${Math.max(1,row.height)*cell-1}px`});this.backpack.append(button);
  }
  for(const b of this.pager.children)b.setAttribute('aria-current',String(Number(b.dataset.page)===this.page));
  if(rows.every(r=>r.length===0)&&!this.status.textContent)this.status.textContent='Waiting for inventory…';
  else if(rows.some(r=>r.length)&&this.status.textContent==='Waiting for inventory…')this.status.textContent='';
  this.host.dataset.state=JSON.stringify({equipment:rows[0],backpack:rows[1],page:this.page,pending:[...this.pendingItems].map(([itemId,operation])=>({itemId,operation}))});
 }
 itemButton(row){
  const b=document.createElement('button');b.type='button';b.className='tool-button network-item';b.dataset.objectId=String(row.id);b.title=row.name;b.textContent=row.name+(row.stackSize>1?` ×${row.stackSize}`:'');b.draggable=!this.pendingItems.has(row.id);b.disabled=this.pendingItems.has(row.id);
  b.addEventListener('dblclick',()=>{if(this.activate){void Promise.resolve(this.activate(row.id)).catch(error=>this.failure(error));}else if(row.slotMask)void this.submit(row.id,'toggle');else{this.status.textContent='Item activation is not connected yet';runtimeDiagnostics.record('network.interaction-unimplemented','Native inventory activation is not connected',{objectId:row.id});}});
  b.addEventListener('dragstart',event=>{event.dataTransfer.setData(MIME,JSON.stringify({token:this.dragToken,itemId:row.id}));event.dataTransfer.effectAllowed='move';});
  b.addEventListener('contextmenu',event=>{event.preventDefault();this.itemMenu(row.id,row.name,event);});return b;
 }
 acceptDrop(node,callback){node.addEventListener('dragover',event=>{if([...event.dataTransfer.types].includes(MIME)){event.preventDefault();event.dataTransfer.dropEffect='move';}});node.addEventListener('drop',event=>{if(![...event.dataTransfer.types].includes(MIME))return;event.preventDefault();event.stopPropagation();try{const source=JSON.parse(event.dataTransfer.getData(MIME)),w=this.world(),item=w?.registry.get(source.itemId);if(source.token!==this.dragToken||!this.active||!item||item.inventoryLocation?.ownerId!==w.localObjectId||!['R','I'].includes(item.inventoryLocation.channel))throw new Error('Native inventory drag source is stale');callback(item,event);}catch(error){this.failure(error);}});}
 async submit(itemId,operation,fields={}){if(this.pendingItems.has(itemId))return;const generation=this.generation;this.pendingItems.set(itemId,operation);this.status.textContent='Action requested';try{await this.action({itemId,operation,...fields});if(generation===this.generation)await this.sync();}catch(error){if(generation!==this.generation)return;this.pendingItems.delete(itemId);this.failure(error);await this.sync();}}
 async receive(result){if(result.alternate)return;const pending=this.pendingItems.get(result.itemId);if(pending===result.operation||pending==='toggle'&&['equip','unequip'].includes(result.operation))this.pendingItems.delete(result.itemId);this.status.textContent=result.success?'Action completed':'The server rejected that action';await this.sync();}
 async choosePage(page){const generation=this.generation;try{await this.panel(page);if(generation!==this.generation)return;this.page=page;await this.sync();}catch(error){if(generation===this.generation)this.failure(error);}}
 failure(error){this.status.textContent=error.message;runtimeDiagnostics.error(error,'network.inventory-action-failed');}
}
