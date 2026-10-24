const selector='.network-inventory,.network-panels:not([data-panel="spells"]),.network-spell-window,.network-dialog,.game-panel';
const interactive='button,input,select,textarea,a,[contenteditable],[draggable="true"]';
const storageKey='nwn.ui.windowPositions.v1';
const managers=new WeakMap();
function managerFor(root){for(let node=root;node;node=node.parentElement)if(managers.has(node))return managers.get(node);return null;}
export function raiseGameWindow(root){managerFor(root)?.raise(root);}
export function frontGameWindow(root){const manager=managerFor(root);if(!manager)return root;return[...manager.viewport.querySelectorAll(selector)].filter(n=>n.getClientRects().length&&n.getBoundingClientRect().width>0).sort((a,b)=>(Number(b.style.zIndex)||0)-(Number(a.style.zIndex)||0))[0]??null;}
export function isFrontGameWindow(root){const front=frontGameWindow(root);return front===root||Boolean(front&&root.contains(front));}
export function clampWindowPosition(point,size,bounds){return{x:Math.max(0,Math.min(point.x,Math.max(0,bounds.width-size.width))),y:Math.max(0,Math.min(point.y,Math.max(0,bounds.height-Math.min(size.height,bounds.height))))};}
export function movableWindowKey(root){
 if(root.matches('.network-inventory'))return'inventory';
 if(root.matches('.network-spell-window'))return root.matches('.network-memorized-spells')?'spells-preparation':root.matches('.network-spell-examine')?'spells-examine':'spells-known';
 if(root.matches('.network-dialog'))return'conversation';return root.dataset.panel||null;
}
// Translations leave native sizing, flex layout, scrolling and item hit boxes
// intact. Stored coordinates are relative to the game viewport, not the screen.
export class MovableWindows{
 constructor(viewport,{storage}={}){
  if(storage===undefined)try{storage=globalThis.localStorage;}catch{}
  this.viewport=viewport;this.storage=storage;this.windows=new Map();this.positions={};this.frame=null;this.serial=20;this.order=new Map();managers.set(viewport,this);
  try{const saved=JSON.parse(storage?.getItem(storageKey)??'{}');for(const[key,p]of Object.entries(saved).slice(0,100))if(/^[a-z-]{1,40}$/.test(key)&&Number.isFinite(p?.x)&&Number.isFinite(p?.y))this.positions[key]={x:p.x,y:p.y};}catch{}
  this.resize=new ResizeObserver(()=>this.schedule());this.resize.observe(viewport);
  this.mutations=new MutationObserver(()=>this.schedule());this.mutations.observe(viewport,{subtree:true,childList:true,attributes:true,attributeFilter:['hidden','data-panel','class']});
  this.abort=new AbortController();const options={capture:true,signal:this.abort.signal};
  viewport.addEventListener('pointerdown',event=>this.start(event),options);viewport.addEventListener('pointermove',event=>this.move(event),options);for(const type of ['pointerup','pointercancel','lostpointercapture'])viewport.addEventListener(type,event=>this.end(event),options);
  viewport.addEventListener('click',event=>{if(this.suppressClick){this.suppressClick=false;event.preventDefault();event.stopImmediatePropagation();}},options);window.addEventListener('blur',()=>this.finish(),{signal:this.abort.signal});this.schedule();
 }
 schedule(){if(this.frame===null)this.frame=requestAnimationFrame(()=>{this.frame=null;this.refresh();});}
 refresh(){
  const live=new Set(this.viewport.querySelectorAll(selector));for(const[root]of this.windows)if(!live.has(root)){if(this.drag?.root===root)this.finish();this.resize.unobserve(root);this.windows.delete(root);}
  for(const root of live){const key=movableWindowKey(root);if(!key)continue;let state=this.windows.get(root);if(!state){state={key,dx:0,dy:0};this.windows.set(root,state);this.resize.observe(root);}else if(state.key!==key){if(this.drag?.root===root)this.finish();state.key=key;state.dx=state.dy=0;root.style.translate='';}
   if(!root.classList.contains('game-window-movable'))root.classList.add('game-window-movable');const handle=root.querySelector('header,.record-title,.game-panel-title');if(handle&&!handle.classList.contains('game-window-handle'))handle.classList.add('game-window-handle');
   if(!root.getClientRects().length||!root.getBoundingClientRect().width)continue;const saved=this.positions[key];if(this.drag?.root!==root&&saved)this.place(root,saved);
   if(!this.order.has(key))this.nextOrder(key);root.style.zIndex=String(this.order.get(key));
  }
 }
 place(root,point){const state=this.windows.get(root),rect=root.getBoundingClientRect(),view=this.viewport.getBoundingClientRect(),position=clampWindowPosition(point,rect,view),dx=position.x-(rect.left-view.left-state.dx),dy=position.y-(rect.top-view.top-state.dy);state.dx=dx;state.dy=dy;const value=`${dx}px ${dy}px`;if(root.style.translate!==value)root.style.translate=value;return position;}
 nextOrder(key){this.order.set(key,++this.serial);if(this.serial>200){this.order=new Map([...this.order].sort((a,b)=>a[1]-b[1]).map(([id],i)=>[id,i+20]));this.serial=this.order.size+20;for(const n of this.windows.keys())n.style.zIndex=String(this.order.get(movableWindowKey(n))??20);}return this.order.get(key);}
 raise(root){if(root.matches('.network-panels[data-panel="spells"]')){root.style.zIndex='';for(const key of ['spells-known','spells-preparation'])this.nextOrder(key);for(const n of root.querySelectorAll('.network-spell-window')){const key=movableWindowKey(n);if(!this.order.has(key))this.nextOrder(key);n.style.zIndex=String(this.order.get(key));}return;}const key=movableWindowKey(root);if(key)root.style.zIndex=String(this.nextOrder(key));}
 start(event){this.suppressClick=false;if(event.button!==0||this.drag)return;const root=event.target.closest(selector),state=this.windows.get(root);if(!state)return;this.raise(root);const handle=event.target.closest('.game-window-handle');if(!handle||!root.contains(handle)||event.target.closest(interactive))return;
  const rect=root.getBoundingClientRect(),view=this.viewport.getBoundingClientRect();this.drag={root,pointerId:event.pointerId,x:event.clientX,y:event.clientY,left:rect.left-view.left,top:rect.top-view.top,moved:false};event.preventDefault();event.stopPropagation();try{this.viewport.setPointerCapture(event.pointerId);}catch{}root.classList.add('game-window-dragging');
 }
 move(event){const drag=this.drag;if(!drag||event.pointerId!==drag.pointerId)return;if(!drag.root.isConnected||!drag.root.getClientRects().length){this.finish();return;}const dx=event.clientX-drag.x,dy=event.clientY-drag.y;if(!drag.moved&&Math.hypot(dx,dy)<3)return;drag.moved=true;drag.position=this.place(drag.root,{x:drag.left+dx,y:drag.top+dy});event.preventDefault();event.stopPropagation();}
 end(event){if(this.drag&&event.pointerId===this.drag.pointerId){event.stopPropagation();this.finish();}}
 finish(){const drag=this.drag;if(!drag)return;this.drag=null;drag.root.classList.remove('game-window-dragging');if(drag.moved){this.suppressClick=true;const state=this.windows.get(drag.root);if(state){this.raise(drag.root);this.positions[state.key]=drag.position;try{this.storage?.setItem(storageKey,JSON.stringify(this.positions));}catch{}}}try{this.viewport.releasePointerCapture(drag.pointerId);}catch{}}
 destroy(){this.finish();this.abort.abort();this.mutations.disconnect();this.resize.disconnect();managers.delete(this.viewport);if(this.frame!==null)cancelAnimationFrame(this.frame);}
}
