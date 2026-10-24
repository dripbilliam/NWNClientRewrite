import {networkStorePrice} from './network_store.js';
import {INVENTORY_CELL as cell} from './inventory_layout.js';

// Paired merchant/backpack presentation. No local purchase/sale simulation.
export class NetworkStoreView{
 constructor(inventory,{input,examine}){
  Object.assign(this,{inventory,input,examine});this.host=document.createElement('section');this.host.className='network-store';this.host.hidden=true;
  this.host.innerHTML='<h3>Store</h3><button type="button" data-store-close>Close store</button><nav data-store-tabs aria-label="Store categories"></nav><nav><button type="button" data-store-prev>Previous</button><span data-store-page></span><button type="button" data-store-next>Next</button></nav><p data-store-gold></p><div class="game-repository-grid network-store-grid"></div><div data-store-selection hidden><p></p><button type="button" data-store-confirm></button><button type="button" data-store-examine>Examine</button><button type="button" data-store-identify>Identify</button><button type="button" data-store-cancel>Cancel</button></div>';
  inventory.equipment.parentElement.after(this.host);this.grid=this.host.querySelector('.network-store-grid');Object.assign(this.grid.style,{width:10*cell+'px',height:10*cell+'px'});this.grid.style.setProperty('--repository-cell',cell+'px');
  this.host.querySelector('[data-store-close]').onclick=()=>void this.command({operation:'close'});
  this.host.querySelector('[data-store-prev]').onclick=()=>void this.navigate(-1);this.host.querySelector('[data-store-next]').onclick=()=>void this.navigate(1);
  this.selection=this.host.querySelector('[data-store-selection]');this.selection.querySelector('[data-store-confirm]').onclick=()=>void this.transact();
  this.selection.querySelector('[data-store-cancel]').onclick=()=>this.clearSelection();this.selection.querySelector('[data-store-examine]').onclick=()=>void Promise.resolve(this.examine?.(this.selected?.id)).catch(e=>inventory.failure(e));
  this.selection.querySelector('[data-store-identify]').onclick=()=>void this.transact('identify');
  inventory.acceptDrop(this.grid,item=>this.select(item.id));
 }
 get open(){return Boolean(this.inventory.world()?.store?.open);}
 reset(){this.host.hidden=true;this.generation=null;this.signature=null;this.labels=null;this.pending=null;this.clearSelection();this.grid.replaceChildren();}
 clearSelection(){this.selected=null;this.selection.hidden=true;}
 async command(request){const world=this.inventory.world(),generation=this.inventory.generation;try{await this.input(request);if(world!==this.inventory.world()||generation!==this.inventory.generation)return false;this.clearSelection();await this.inventory.sync();return true;}catch(e){if(world===this.inventory.world()&&generation===this.inventory.generation)this.inventory.failure(e);return false;}}
 async navigate(delta){const w=this.inventory.world(),view=w?.inventories.get('M');if(!this.open)return;const count=view?.pageCount??1,page=((w.store.page??0)+delta+Math.max(1,count))%Math.max(1,count);await this.command({operation:'page',page});}
 async sync(table,generation,renderGeneration){
  const iv=this.inventory,w=iv.world(),store=w?.store;this.host.hidden=!this.open;if(!this.open){this.clearSelection();return;}
  if(this.generation!==store.generation){this.generation=store.generation;this.clearSelection();}
  const view=w.inventories.get('M'),tabs=this.host.querySelector('[data-store-tabs]');
  const signature=JSON.stringify([store.generation,store.panel,store.page,store.gold,view?.pageCount,[...this.pending??[]],(view?.entries??[]).map(v=>[v,w.registry.get(v.id)?.item])]);if(signature===this.signature)return;
  this.labels??=Promise.all(Array.from({length:5},(_,panel)=>iv.resolve({strRef:0xf85c+panel})));const labels=await this.labels;
  const rows=await Promise.all((view?.entries??[]).map(async row=>{const item=w.registry.get(row.id)?.item;if(!item)throw new Error('Replicated merchant item is unavailable');const entry=table.rows.get(item.baseItem);return{...row,name:await iv.resolve(item.name),width:Number(entry?.InvSlotWidth),height:Number(entry?.InvSlotHeight),stackSize:item.stackSize??item.field454,icon:await iv.resolveItemIcon(item)};}));
  if(generation!==iv.generation||renderGeneration!==iv.renderGeneration||w!==iv.world()||!store.open)return;
  tabs.replaceChildren();for(let panel=0;panel<5;panel++){const b=document.createElement('button');b.type='button';b.textContent=labels[panel];b.dataset.storePanel=String(panel);b.setAttribute('aria-current',String(store.panel===panel));b.onclick=()=>void this.command({operation:'panel',panel});tabs.append(b);}this.signature=signature;
  this.grid.replaceChildren();this.host.querySelector('[data-store-page]').textContent=`${(store.page??0)+1}/${view?.pageCount??1}`;this.host.querySelector('[data-store-gold]').textContent=store.gold===-1?'':`Store gold: ${store.gold}`;
  for(const b of this.host.querySelectorAll('[data-store-prev],[data-store-next]'))b.disabled=(view?.pageCount??1)<=1;
  for(const row of rows){const b=iv.itemButton(row);b.classList.add('game-repository-item');Object.assign(b.style,{left:row.x*cell+'px',top:(row.y%10)*cell+'px',width:Math.max(1,row.width)*cell-1+'px',height:Math.max(1,row.height)*cell-1+'px'});b.addEventListener('click',()=>this.select(row.id));this.grid.append(b);}
  if(this.selected){const location=w.registry.get(this.selected.id)?.inventoryLocation;if(!location||(location.channel==='M')!==this.selected.buy)this.clearSelection();}
  this.host.dataset.state=JSON.stringify({generation:store.generation,panel:store.panel,page:store.page,pageCount:view?.pageCount??1,entries:rows.map(({icon,...row})=>row),pending:[...this.pending??[]]});
 }
 select(id){
  const w=this.inventory.world(),object=w?.registry.get(id),item=object?.item,location=object?.inventoryLocation;if(!this.open||!item||!(location?.channel==='M'||location?.ownerId===w.localObjectId&&['R','I'].includes(location.channel)))return;
  const buy=location.channel==='M',price=networkStorePrice(w.store,item,buy);this.selected={id,buy,generation:w.store.generation};this.selection.hidden=false;this.selection.querySelector('p').textContent=`${buy?'Buy':'Sell'} for ${price} gold?`;
  this.selection.querySelector('[data-store-confirm]').textContent=buy?'Buy':'Sell';this.selection.querySelector('[data-store-confirm]').disabled=this.pending?.has(id)??false;
  const identify=this.selection.querySelector('[data-store-identify]');identify.hidden=buy||Boolean(item.identified);identify.textContent=`Identify (${w.store.identifyPrice} gold)`;
 }
 async transact(operation){const s=this.selected,w=this.inventory.world();if(!s||!this.open||s.generation!==w.store.generation)return;const pending=this.pending??=new Set();if(pending.has(s.id))return;pending.add(s.id);this.inventory.status.textContent='Transaction requested';const sent=await this.command({operation:operation??(s.buy?'buy':'sell'),itemId:s.id});if(!sent||operation==='identify')pending.delete(s.id);if(w===this.inventory.world())await this.inventory.sync();}
}
