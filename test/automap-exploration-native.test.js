import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {dfsExploreArea} from '../src/automap_exploration.js';
import {tilePathNode,rotateReal} from '../src/tile_path_node.js';
test('recursive automap exploration matches 1,536 original executions with tile rotations and closed-door checks',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-automap-exploration-observations.json',import.meta.url)));assert.equal(data.rows.length,1536);
 for(const row of data.rows){
  const c=row.case,calls=[],area={width:c.width,height:c.height},visited=Uint8Array.from(c.visited??Array(c.width*c.height).fill(0)),door=c.door?{id:77,...c.door}:null,p={
   tile:(x,y)=>({x,y,orientation:c.rotation,pathNodes:{path:c.path,pathOrientation:c.pathOrientation,visibility:c.visibility,visibilityOrientation:c.visibilityOrientation,doorVisibility:c.doorVisibility,doorVisibilityOrientation:c.doorVisibilityOrientation,doors:c.tileDoors}}),
   doors:()=>c.ids,door:id=>{calls.push(['door',id]);return id===77?door:null;},appearance:o=>o.appearance,
   open:o=>{calls.push(['open',o.id]);return o.open;},blockSight:o=>{calls.push(['block',o.id]);return o.block;},position:o=>o.position,orientation:o=>o.orientation,
   graph:(kind,orientation)=>{calls.push(['graph',kind,orientation]);return tilePathNode(kind,orientation);},
   regionEntrance:(tile,point,kind,orientation)=>{calls.push(['entrance',tile.y*c.width+tile.x,...rotateReal(point,tile.orientation),kind,orientation]);return c.entrance;},
   closestRegion:(tile,point,kind,orientation)=>{calls.push(['closest',tile.y*c.width+tile.x,...point,kind,orientation]);return c.region;},
  };
  await dfsExploreArea(area,visited,c.depth,c.x,c.y,...c.local,p);
  assert.deepEqual({calls,visited:[...visited]},{calls:row.calls,visited:row.visited},JSON.stringify(c));
 }
});
