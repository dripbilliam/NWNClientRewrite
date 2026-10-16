import {UI_PIXELS_PER_UNIT as PPU} from './native_ui_assets.js';
import {OBJECT_INVALID} from './game_object_array.js';
import {repositoryPage} from './item_repository.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
const MIME='application/x-nwn-inventory-item';
const dragSessions=new WeakMap(),dragSession=session=>{if(!dragSessions.has(session))dragSessions.set(session,crypto.randomUUID());return dragSessions.get(session);};
const el=(tag,cls,text)=>{const node=document.createElement(tag);node.className=cls;if(text!==undefined)node.textContent=text;return node;};

// Presentation adapters use canonical repository IDs/coordinates and submit
// decoded native requests. They never move items or assign replacement IDs.
export function bindRepositoryDrag(node,item,session){
 node.draggable=true;node.addEventListener('dragstart',event=>{event.dataTransfer.setData(MIME,JSON.stringify({session:dragSession(session),actorId:session.player.id,itemId:item.id,sourceId:item.possessorId}));event.dataTransfer.effectAllowed='copyMove';});
}
export function repositoryGrid({session,owner,page,cell=33,itemButton,onRequest}){
 const repo=owner.nativeRepository;if(!repo)throw new Error('Inventory grid canonical repository is unavailable');
 const rows=Math.trunc(repo.boundary/repo.width);if(rows<=0||repo.width<=0)throw new Error('Inventory grid dimensions are unavailable');
 const grid=el('div','game-repository-grid');grid.dataset.ownerId=owner.id;grid.dataset.page=page;grid.dataset.columns=repo.width;grid.dataset.rows=rows;
 Object.assign(grid.style,{width:`${repo.width*cell}px`,height:`${rows*cell}px`});grid.style.setProperty('--repository-cell',`${cell}px`);
 grid.addEventListener('dragover',event=>{if([...event.dataTransfer.types].includes(MIME)){event.preventDefault();event.dataTransfer.dropEffect='move';}});
 grid.addEventListener('drop',event=>{if(![...event.dataTransfer.types].includes(MIME))return;event.preventDefault();event.stopPropagation();
  try{const source=JSON.parse(event.dataTransfer.getData(MIME)),item=session.registry.get(source.itemId);
   if(source.session!==dragSession(session)||source.actorId!==session.player.id||!item||item.possessorId!==source.sourceId)throw new Error('Inventory drag source changed before drop');
   const rect=grid.getBoundingClientRect(),x=Math.floor((event.clientX-rect.left)/cell),row=Math.floor((event.clientY-rect.top)/cell),y=row+page*rows;
   if(x<0||x>=repo.width||row<0||row>=rows||y>255)return;
   onRequest('inventory.move',{itemId:item.id,destination:owner.id===session.player.id?OBJECT_INVALID:owner.id,x,y});
  }catch(error){runtimeDiagnostics.error(error,'ui.inventory-drop-failed');}
 });
 for(const id of repo.ids()){
  const item=session.registry.get(id);if(!item)throw new Error(`Inventory repository item ${id} is unavailable`);
  if(repositoryPage(repo,item.repositoryX,item.repositoryY)!==page)continue;
  const info=session.items.baseInfo(item);if(!info)throw new Error(`Inventory item ${id} base rules are unavailable`);
  const node=itemButton(item);node.classList.add('game-repository-item');node.dataset.objectId=id;node.dataset.repositoryX=item.repositoryX;node.dataset.repositoryY=item.repositoryY;
  node.title=`${node.title||item.name||item.tag} · ${item.stackSize}`;
  Object.assign(node.style,{left:`${item.repositoryX*cell}px`,top:`${(item.repositoryY-page*rows)*cell}px`,width:`${info.width*cell-1}px`,height:`${info.height*cell-1}px`});
  bindRepositoryDrag(node,item,session);grid.append(node);
 }
 return grid;
}

export class ContainerUi{
 constructor(parent,{getSession,objectName,onRequest,onItemTarget,onExamine}={}){
  Object.assign(this,{getSession,objectName,onRequest,onItemTarget,onExamine});this.root=el('div','game-container-layer');parent.append(this.root);this.epoch=0;this.signature='';
 }
 reset(){this.epoch++;this.signature='';this.presentationReported=false;this.root.dataset.nativeContainers='[]';this.root.replaceChildren();this.root.parentElement?.classList.remove('has-container');}
 refresh(session,assets,text){
  const client=session.combat.broadcastProviders().client(session.player.id),records=[];
  for(const [name,gui]of [['primary',client?.inventoryGUI],['alternate',client?.alternateInventoryGUI]]){
   const id=gui?.openInventory.id;if(id===undefined||id===OBJECT_INVALID)continue;const owner=session.registry.get(id);if(!owner)continue;
   const repo=owner.nativeRepository;if(!repo)throw new Error('Open container has no canonical repository');
   records.push({name,owner,page:gui.openInventory.field8,gui,items:[...repo.ids()].map(id=>{const item=session.registry.get(id);return item?{id,x:item.repositoryX,y:item.repositoryY,stack:item.stackSize,baseItem:item.baseItem,tag:item.tag,name:this.objectName(item)}:{id,missing:true};})});
  }
  this.root.parentElement.classList.toggle('has-container',records.length!==0);this.root.dataset.nativeContainers=JSON.stringify(records.map(({name,owner,page,items})=>({name,id:owner.id,page,width:owner.nativeRepository.width,height:owner.nativeRepository.height,boundary:owner.nativeRepository.boundary,items})));
  if(records.length&&!this.presentationReported){this.presentationReported=true;runtimeDiagnostics.record('ui.inventory-presentation-approximate','Item icon selection, global window anchoring and grid-origin parity are not reconstructed',{actorId:session.player.id},'info');}
  const signature=JSON.stringify([session.player.id,this.root.dataset.nativeContainers]);if(signature===this.signature)return;this.signature=signature;
  const epoch=++this.epoch;this.root.replaceChildren();void this.render(records,session,assets,text,epoch).catch(error=>{if(epoch===this.epoch)runtimeDiagnostics.error(error,'ui.container-render-failed');});
 }
 async render(records,session,assets,text,epoch){
  if(!records.length)return;const layout=await assets.layout('inv_container'),skin=await assets.skin(layout.Obj_ResRef);
  if(epoch!==this.epoch||session!==this.getSession())return;
  this.root.parentElement.style.setProperty('--container-width',`${records.length*skin.width}px`);
  for(const [index,record]of records.entries()){
   const {owner,page,name}=record,panel=el('section','game-container-panel');panel.dataset.containerId=owner.id;panel.dataset.gui=name;panel.setAttribute('role','dialog');panel.setAttribute('aria-label',this.objectName(owner));
   Object.assign(panel.style,{width:`${skin.width}px`,height:`${skin.height}px`,right:`${91+index*skin.width}px`,backgroundImage:`url("${skin.url}")`});
   const close=()=>this.onRequest(name==='primary'?'container.close':'inventory.status',name==='primary'?{}:{value:0,ownerId:record.gui.ownerId});
   for(const control of layout.Obj_ChildList??[]){
    const model=control.Obj_ResRef,art=model?await assets.skin(model):null;if(epoch!==this.epoch||session!==this.getSession())return;
    const caption=control.Obj_Tag==='Label'?this.objectName(owner):text.resolve(control.Obj_Caption);
    let node;
    if(control.Obj_Tag==='ItemGrid'){
     const grid=repositoryGrid({session,owner,page,cell:(art.width-PPU*(art.hooks.get('icon')?.[0]??0))/owner.nativeRepository.width,
      itemButton:item=>{const node=el('button','',this.objectName(item));node.type='button';node.addEventListener('click',()=>{if(!this.onItemTarget?.(item.id))this.onExamine?.(item.id);});return node;},onRequest:this.onRequest});
     node=el('div','native-container-grid');node.append(grid);grid.style.left=`${PPU*(art.hooks.get('icon')?.[0]??0)}px`;grid.style.top='0px';
    }else{
     const interactive=['RightButton','LeftButton','CloseButton','XButton'].includes(control.Obj_Tag);node=el(interactive?'button':'div','native-container-control',caption);
     if(interactive){node.type='button';node.setAttribute('aria-label',control.Obj_Tag==='RightButton'?'Next container page':control.Obj_Tag==='LeftButton'?'Previous container page':'Close container');
      node.addEventListener('click',()=>['CloseButton','XButton'].includes(control.Obj_Tag)?close():this.onRequest('container.page',{subtype:control.Obj_Tag==='RightButton'?2:3}));
      if(['RightButton','LeftButton'].includes(control.Obj_Tag))node.disabled=owner.objectType!==9||owner.nativeRepository.width*owner.nativeRepository.height<=owner.nativeRepository.boundary;
     }
    }
    node.dataset.nativeControl=control.Obj_Tag;node.dataset.nativeModel=model??'';
    const x=Number(control.Obj_X??control.Obj_Label_X??0),y=Number(control.Obj_Y??control.Obj_Label_Y??0);
    Object.assign(node.style,{left:`${(x+(art?.min[0]??0))*PPU}px`,top:`${skin.height-(y+(art?.max[1]??0))*PPU}px`,width:`${art?.width??Number(control.Obj_Label_Width??0)*PPU}px`,height:`${art?.height??Number(control.Obj_Label_Height??.17)*PPU}px`,zIndex:String(control.Obj_Layer??1),backgroundImage:art?.url?`url("${art.url}")`:''});
    panel.append(node);
   }
   if(epoch===this.epoch)this.root.append(panel);
  }
 }
}
