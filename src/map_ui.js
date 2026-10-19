import {parseTileset} from './area.js';
import {RESOURCE_TYPE,decodeResourceText} from './resource_archive.js';
import {decodeGffText} from './gff_text.js';
import {findMapPin} from './map_pin_messages.js';
import {presentMapPin,playerMapPosition,mapPlayerHeading} from './map_pin_presentation.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';

const node=(tag,cls)=>{const n=document.createElement(tag);n.className=cls;return n;},f=Math.fround;
const image=(skin,scale=1)=>{if(!skin?.url)throw new Error('Native map GUI model raster is unavailable');const img=node('img','game-map-art');img.src=skin.url;img.draggable=false;Object.assign(img.style,{left:`${skin.min[0]*100*scale}px`,top:`${-skin.max[1]*100*scale}px`,width:`${(skin.max[0]-skin.min[0])*100*scale}px`,height:`${(skin.max[1]-skin.min[1])*100*scale}px`});return img;};

// Local single-player presentation adapter, NOT the native client exploration
// packet decoder or full map-window graph. The canonical PC bitmaps feed a
// separate tile-state view; no server IDs/automap storage are allocated here.
export class MapUi{
 constructor(body,session,assets,options={}){
  Object.assign(this,{session,assets,options});this.widgets=new Map();this.reported=new Set();this.generation=0;this.disposed=false;this.zoom=16;
  this.viewport=node('div','game-map-viewport');this.stage=node('div','game-map');this.stage.setAttribute('aria-label','Area map');this.viewport.append(this.stage);body.append(this.viewport);
  this.note=node('p','game-map-note');this.note.setAttribute('role','status');body.append(this.note);
  if(!options.network)runtimeDiagnostics.record('map-ui.local-adapter','Map artwork uses native assets and pin projection with local PC exploration bits; native exploration transport, full window controls and user-note editing remain unavailable',session.diagnosticContext(session.player.id),'info');
  void this.load();
 }
 report(error,operation){if(this.reported.has(operation))return;this.reported.add(operation);runtimeDiagnostics.error(error,'map-ui.presentation-failed',{...this.session.diagnosticContext(this.session.player.id),operation});if(!this.disposed)this.note.textContent=error.message;}
 destroy(){this.disposed=true;this.generation++;}
 active(){return !this.disposed&&this.stage.isConnected;}
 async load(){
  const generation=++this.generation,area=this.session.currentArea;this.area=area;this.ready=false;this.stage.replaceChildren();this.widgets.clear();this.cells=[];this.note.textContent='';
  try{
   if(!area||!Array.isArray(area.tilePlacements)||area.tilePlacements.length!==area.width*area.height)throw new Error('Native map tile placements are unavailable');
   const tileset=parseTileset(decodeResourceText(await this.assets.resolver.getResource(area.tilesetResRef,RESOURCE_TYPE.SET)));
   const cells=await Promise.all(area.tilePlacements.map(async(tile,index)=>{
    const definition=tileset.tiles[tile.Tile_ID];if(!definition)throw new Error(`Map tile definition ${tile.Tile_ID} is unavailable`);
    const orientation=tile.Tile_Orientation??0;if(!Number.isInteger(orientation)||orientation<0||orientation>3)throw new Error('Native map tile orientation is unavailable');
    const skin=await this.assets.mapTileSkin(definition.mapImage,orientation);return{index,reference:definition.mapImage,orientation,skin};
   }));
   const [pinSkin,pinHilite,pinDown,playerSkin]=await Promise.all([this.assets.skin('CTL_MAP_PIN'),this.assets.skin('CTL_MAP_PIN','hilite'),this.assets.skin('CTL_MAP_PIN','down'),this.assets.skin('CTL_MAP_XMARKER')]);
   if(!this.active()||generation!==this.generation||area!==this.session.currentArea)return;
   Object.assign(this,{pinSkin,pinHilite,pinDown,playerSkin});Object.assign(this.stage.style,{width:`${area.width*this.zoom}px`,height:`${area.height*this.zoom}px`});
   for(const c of cells){const holder=node('div','game-map-cell');holder.dataset.mapImage=c.reference;holder.dataset.orientation=c.orientation;holder.dataset.tileIndex=c.index;
    // Constructor89314c4 selects model1 (CTL_ICON_AREAMAP); its installed
    // mesh is16 pixels wide, matching the original initial zoom16. The model
    // table's other DWORD is not the authored mesh width or a scale divisor.
    Object.assign(holder.style,{left:`${(c.index%area.width+.5)*this.zoom}px`,top:`${(area.height-Math.floor(c.index/area.width)-.5)*this.zoom}px`});holder.append(image(c.skin));this.stage.append(holder);this.cells.push(holder);
   }
   this.player=node('div','game-map-player');this.player.title='Player';this.player.append(image(playerSkin));this.stage.append(this.player);
   this.stage.dataset.areaId=area.id;this.stage.dataset.zoom=this.zoom;this.ready=true;this.lastRefresh=0;void this.refresh();
  }catch(error){if(generation===this.generation)this.report(error,'map-artwork');}
 }
 tileStates(){
  if(this.options.tileStates)return this.options.tileStates();
  const p=this.session.player,index=p.nativeAutoMapAreaIds6c8?.indexOf(this.area.id),bytes=index>=0?p.nativeAutoMapBuffers6d8?.[index]:null;
  if(!(bytes instanceof Uint8Array)||bytes.length!==128||this.area.width*this.area.height>1024)throw new Error('Local player map exploration buffer is unavailable');
  return Uint8Array.from({length:this.area.width*this.area.height},(_,i)=>(bytes[i>>>3]>>>(i&7))&1);
 }
 widget(pin){
  let widget=this.widgets.get(pin);if(widget)return widget;
  const b=node('button','game-map-pin');b.type='button';b.dataset.wireReference=pin.nativeReference188>>>0;b.dataset.pinType=pin.nativeType18c|0;
  const art=image(this.pinSkin);b.append(art);const setSkin=skin=>{const next=image(skin);art.src=next.src;art.style.cssText=next.style.cssText;};
  b.addEventListener('pointerenter',()=>setSkin(this.pinHilite));b.addEventListener('pointerleave',()=>setSkin(this.pinSkin));b.addEventListener('pointerdown',()=>setSkin(this.pinDown));b.addEventListener('pointerup',()=>setSkin(this.pinHilite));
  b.addEventListener('click',()=>{this.note.textContent=b.title;});
  widget={nativeReference188:pin.nativeReference188,nativeType18c:pin.nativeType18c,nativeStateE8:0,button:b};this.widgets.set(pin,widget);this.stage.append(b);return widget;
 }
 async refresh(){
  if(!this.active())return;if(this.area!==this.session.currentArea){void this.load();return;}if(!this.ready||this.busy||performance.now()-(this.lastRefresh??0)<100)return;
  this.busy=true;this.lastRefresh=performance.now();const generation=this.generation;
  try{
   const area=this.area,states=this.tileStates(),scene=this.session.mapPins?.scene;if(!scene?.initialLoaded||scene.areaId!==area.id||scene.clientObjectId!==this.session.player.id)throw new Error('Local client map-pin scene is unavailable');
   this.cells.forEach((c,i)=>{c.hidden=states[i]!==1;});
   const map={width:area.width,height:area.height,zoom514:this.zoom,container1e8:this.stage,view110:this.stage},live=new Set(scene.nativeMapPins2b8);
   for(const[pin,w]of this.widgets)if(!live.has(pin)){w.button.remove();this.widgets.delete(pin);}
   for(const pin of scene.nativeMapPins2b8){
    if(!pin)continue;const widget=this.widget(pin),first=findMapPin(scene,widget.nativeReference188,widget.nativeType18c);if(!first)throw new Error('Native map widget reference lookup failed');
    const label=decodeGffText(first.nativeText178);widget.button.title=label;widget.button.setAttribute('aria-label',label||'Map note');
    if(pin.nativeEnabled170===0){widget.button.hidden=true;continue;}
    await presentMapPin(map,widget,0,{position:()=>{const record=findMapPin(scene,widget.nativeReference188,widget.nativeType18c);if(!record)throw new Error('Native map widget position is unavailable');return record.nativePosition38;},tileState:(_m,i)=>states[i],attach:()=>1,model:w=>w,viewOrigin:()=>[0,0,0],transform:(w,_root,point)=>{w.point=point;}});
    if(!this.active()||generation!==this.generation)return;
    widget.button.hidden=widget.nativeStateE8===0;if(widget.point){Object.assign(widget.button.style,{left:`${area.width*this.zoom/2+widget.point[0]*100}px`,top:`${area.height*this.zoom/2-widget.point[1]*100}px`});widget.button.dataset.nativePoint=JSON.stringify(widget.point);}
   }
   const p=this.session.player,point=playerMapPosition(map,[f(p.position[0]),f(-p.position[2]),f(p.position[1])]);
   if(!Array.isArray(p.orientation)||p.orientation.length!==3)throw new Error('Native map player orientation is unavailable');
   const heading=mapPlayerHeading([f(p.orientation[0]),f(-p.orientation[2]),f(p.orientation[1])]);Object.assign(this.player.style,{left:`${area.width*this.zoom/2+point[0]*100}px`,top:`${area.height*this.zoom/2-point[1]*100}px`,transform:`rotate(${-heading}deg)`});this.player.dataset.nativePoint=JSON.stringify(point);this.player.dataset.nativeHeading=heading;
   this.stage.dataset.rendered='true';this.stage.dataset.exploredTiles=states.reduce((sum,n)=>sum+n,0);
  }catch(error){this.report(error,'map-refresh');}finally{this.busy=false;}
 }
}
