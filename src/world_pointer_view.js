import {pointerRay} from './world_picking.js';
import {GameCursorAssets,worldCursorId} from './game_cursor.js';
import {TargetPreviewShader} from './target_preview_shader.js';
export class WorldPointerView{
 constructor({viewport,canvas,camera,context,enabled=()=>true,report=()=>{}}){Object.assign(this,{canvas,camera,context,enabled,report});this.sets=new WeakMap();this.pointer=null;this.buttons=0;this.serial=0;this.cursorLoaded=new Map();
  viewport.addEventListener('pointermove',e=>{this.pointer=e.target===canvas?{x:e.clientX,y:e.clientY}:null;this.buttons=e.buttons;this.dirty=true;});
  canvas.addEventListener('pointerdown',e=>{this.pointer={x:e.clientX,y:e.clientY};this.buttons=e.buttons|(e.button===0?1:e.button===1?4:e.button===2?2:0);this.dirty=true;});canvas.addEventListener('pointerup',e=>{this.buttons=e.buttons;this.dirty=true;});canvas.addEventListener('pointerleave',()=>{this.pointer=null;this.hide();});window.addEventListener('blur',()=>{this.pointer=null;this.hide();});
 }
 async attach(root,resolver){this.detach();const serial=this.serial,preview=new TargetPreviewShader();try{await preview.load(resolver);if(serial!==this.serial){preview.dispose();return;}this.preview=preview;this.root=root;preview.bind(root);}catch(error){preview.dispose();this.report('target.preview-load-failed',error.message);}}
 detach(){this.serial++;this.preview?.dispose();this.preview=null;this.root=null;this.hit=null;this.cursorOwner=null;this.cursorLoaded.clear();this.lastPick=-Infinity;this.hide();}
 hide(){this.preview?.update();if(this.preview)this.canvas.dataset.targetPreview=JSON.stringify(this.preview.snapshot());else delete this.canvas.dataset.targetPreview;if(this.canvas.dataset.gameCursor)delete this.canvas.dataset.gameCursor;this.canvas.style.cursor='';}
 cursor(assets,id){if(!assets){this.canvas.style.cursor=id===29||id===31?'crosshair':'';return;}let set=this.sets.get(assets);if(!set){set=new GameCursorAssets(assets);this.sets.set(assets,set);}if(this.cursorOwner!==assets){this.cursorOwner=assets;this.cursorLoaded=new Map();}
  if(!this.cursorLoaded.has(id)){this.cursorLoaded.set(id,null);set.get(id).then(icon=>{if(this.cursorOwner===assets)this.cursorLoaded.set(id,icon);}).catch(error=>this.report('cursor.asset-failed',error.message,{id}));}
  const icon=this.cursorLoaded.get(id),css=icon?`url("${icon.url}") ${icon.hotspot.join(' ')}, auto`:id===29||id===31?'crosshair':id===1?'default':'pointer';if(this.canvas.style.cursor!==css)this.canvas.style.cursor=css;const metadata=JSON.stringify({id,resource:icon?.name??null,loaded:Boolean(icon)});if(this.canvas.dataset.gameCursor!==metadata)this.canvas.dataset.gameCursor=metadata;
 }
 update(time=performance.now()){
  const c=this.context();if(!c||!this.enabled()||!this.pointer||document.hidden||document.elementFromPoint(this.pointer.x,this.pointer.y)!==this.canvas){this.hide();return;}
  this.preview?.bind(c.root);const targeting=Boolean(c.targetingActive),cameraKey=this.camera.matrixWorld.elements.join(',');if(this.cameraKey!==cameraKey){this.cameraKey=cameraKey;this.dirty=true;}
  if(time-(this.lastPick??-Infinity)>=(targeting?25:this.dirty?40:120)){this.lastPick=time;this.dirty=false;this.camera.updateMatrixWorld();this.hit=c.pick(pointerRay(this.pointer.x,this.pointer.y,this.canvas.getBoundingClientRect(),this.camera));}
  const hit=this.hit,target=hit?.object??null,state=c.targeting?.(target),point=hit?.point?[hit.point.x,-hit.point.z,hit.point.y]:null;
  this.cursor(c.assets,worldCursorId(target,{walkable:Boolean(hit&&!target),playerId:c.playerId,targeting:state,pressed:Boolean(this.buttons&1)}));
  this.preview?.update({preview:state?.valid?state.preview:null,player:c.player,point,type:hit?(target?.objectType??2):0,time});
  if(this.preview){const metadata=JSON.stringify(this.preview.snapshot());if(this.canvas.dataset.targetPreview!==metadata)this.canvas.dataset.targetPreview=metadata;}
 }
}
