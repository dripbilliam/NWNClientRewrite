import {initializeAutomapState,postProcessAutomap,reconcileAutomap,clearAutomap,updateAutomap,exploreArea,setAllTilesExplored,getTileExplored,setTileExplored} from './automap.js';
import {dfsExploreArea} from './automap_exploration.js';
import {tilePathNode,tileRegionEntrance,closestTileRegion} from './tile_path_node.js';
import {intEntry} from './combat_stats.js';
import {updatePlayerAutomaps} from './world_displacement.js';
const native=v=>[Math.fround(v[0]),Math.fround(-v[2]),Math.fround(v[1])];

export class AutomapRuntime{
 constructor(session){this.session=session;}
 providers(){const s=this.session;return{
  module:()=>s.module,moduleIds:m=>m.nativeAreaIds50.view(),
  areaById:id=>{const a=s.registry.get(id);return a?.objectType===4?a:null;},
  area:o=>{const a=s.registry.get(o.areaId);return a?.objectType===4?a:null;},
  creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},position:o=>native(o.position),
  client:id=>s.combat.broadcastProviders().client(id),
  possessedFamiliar:o=>Number((o.associateType&65535)===3&&Boolean(s.combat.broadcastProviders().client(o.id))),
  tileExists:a=>{if(!Array.isArray(a.tilePlacements)||a.tilePlacements.length<a.width*a.height)throw new Error('Native automap tile array is unavailable');return true;},
  update:(o,id)=>this.update(o,id),explore:(a,o,x,y,r)=>exploreArea(a,o,x,y,r,this.explorationProviders(a)),
 };}
 explorationProviders(area){const s=this.session,g=area.nativeGeometry,objects=g?.objects;if(!g||!objects)throw new Error('Native automap area geometry is unavailable');return{
  position:o=>native(o.position),dfs:(a,visited,depth,x,y,lx,ly)=>dfsExploreArea(a,visited,depth,x,y,lx,ly,this.explorationProviders(a)),
  tile:(x,y)=>g.tile(x,y),graph:tilePathNode,regionEntrance:tileRegionEntrance,closestRegion:closestTileRegion,
  doors:tile=>objects.automapDoorIds(tile),door:id=>{const o=s.registry.get(id);return o?.objectType===10?o:null;},
  appearance:o=>(o.authored.Appearance??0)>>>0,open:o=>objects.providers().doorOpenState(o),
  orientation:o=>o.nativeOrientation,
  blockSight:o=>{
   const d=objects.descriptors.get(o.id);if(!d)throw new Error('Native automap door rules are unavailable');
   // Appearance0 reads rules+138 GenericDoors at GenericType+3fc. GetINT
   // writes the table fallback even when the lookup returns failure.
   const value=intEntry(d.table,d.index,'BlockSight');if(!value.found)objects.report(new Error('Native automap door BlockSight lookup returned its table fallback'),o,'native-automap-door-blocksight');return value.value;
  },
 };}
 async run(o,operation,fn){try{return await fn();}catch(error){this.session.report(error,{...this.session.diagnosticContext(o.id),operation});throw error;}}
 initialize(o){initializeAutomapState(o);}
 postProcess(o){return this.run(o,'native-postprocess-automap',()=>postProcessAutomap(o,this.providers()));}
 update(o,id=o.id){return this.run(o,'native-update-automap',()=>updateAutomap(o,id,this.providers()));}
 updatePlayersInArea(area){const s=this.session;return this.run(area,'native-area-update-player-automaps',()=>updatePlayerAutomaps(area,{
  clients:s.combat.broadcastProviders().clients,clientObject:c=>c?.object?s.registry.get(c.object.id)??null:null,
  asCreature:o=>o.objectType===5?o:null,update:(o,id)=>this.update(o,id),
 }));}
 reconcile(o){return this.run(o,'native-reconcile-automap',()=>reconcileAutomap(o,this.providers()));}
 reveal(o,id,value){return this.run(o,'native-set-all-tiles-explored',()=>setAllTilesExplored(o,id,value,this.providers()));}
 explored(o,id,x,y){return getTileExplored(o,id,x,y,this.providers());}
 scriptProviders(){const s=this.session,p=this.providers();return{
  area:p.areaById,client:p.client,creature:p.creature,object:id=>s.registry.get(id)??null,
  asArea:o=>o.objectType===4?o:null,asCreature:o=>o.objectType===5?o:null,
  reveal:(...args)=>this.reveal(...args),explored:(...args)=>this.explored(...args),
  setTile:(o,id,x,y,value)=>setTileExplored(o,id,x,y,value,p),
 };}
 clear(o){clearAutomap(o);}
}
