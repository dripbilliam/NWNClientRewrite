import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {tilePathNode,closestTileRegion,tileRegionEntrance,tileNodeOrientation,rotateCanonical} from '../src/tile_path_node.js';
import {plotSoundPath,doorTileCoordinates} from '../src/sound_path.js';
import {PathInformation} from '../src/path_information.js';
import {computeTileAdjacency} from '../src/tile_surface_mesh.js';

test('all480 native-emulated graph shapes and rotations match the replacement constants',()=>{
  const observations=JSON.parse(readFileSync(new URL('../backups/animations/native-tile-path-node-observations.json',import.meta.url)));
  assert.equal(observations.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
  for(let kind=1;kind<=120;kind++)for(let rotation=0;rotation<4;rotation++)assert.deepEqual(tilePathNode(kind,rotation),observations.graphs[kind][rotation],`${kind}/${rotation}`);
  assert.equal(tilePathNode(0,0),null);assert.throws(()=>tilePathNode(121,0),/invalid/);assert.throws(()=>tilePathNode(65,4),/invalid/);
});
function tile(x,y,kind=65,orientation=0){
  const mesh={vertices:[[0,0,0],[10,0,0],[10,10,0],[0,10,0]],faces:[[0,1,2],[0,2,3]]};mesh.adjacency=computeTileAdjacency(mesh.vertices,mesh.faces);
  return{x,y,orientation,mesh,pathNodes:{path:kind,pathOrientation:0,visibility:0,visibilityOrientation:0,doorVisibility:0,doorVisibilityOrientation:0,doors:0}};
}
function fixture(width=12,height=12){
  const area={width,height},tiles=new Map(),doors=new Map(),path=new PathInformation();
  const p={tile:async(x,y)=>{const key=`${x},${y}`;if(!tiles.has(key))tiles.set(key,tile(x,y));return tiles.get(key);},doors:async t=>doors.get(`${t.x},${t.y}`)??[]};
  const run=async(start,goal)=>{for(const [offset,point] of [[0x64,start],[0x4c,goal]])point.forEach((v,i)=>path.raw.setFloat32(offset+i*4,v,true));return plotSoundPath(area,path,p);};
  return{area,tiles,doors,path,p,run};
}
test('sound traversal reaches same region and up to four tile crossings but rejects a fifth',async()=>{
  const s=fixture();assert.equal(await s.run([55,55],[55,55]),1);
  assert.equal(await s.run([55,55],[95,55]),1);assert.equal(await s.run([55,55],[105,55]),0);
  assert.equal(s.area.nativeSoundPath288,s.path);
  assert.equal(await s.run([-10,55],[55,55]),0);assert.equal(await s.run([55,55],[125,55]),0);
});
test('native entrance ordering returns immediately on an out-of-array crossing',async()=>{
  const s=fixture(2,1);assert.equal(await s.run([5,5],[15,5]),0); // A's north entrance is first.
});
test('closed visible doors block crossings only when both tile definitions declare doors',async()=>{
  const s=fixture();const a=await s.p.tile(5,5),b=await s.p.tile(6,5);a.pathNodes.doors=b.pathNodes.doors=1;
  // Limit A to an east-only engine shape by choosing a captured one-entrance graph.
  a.pathNodes.visibility=78;a.pathNodes.visibilityOrientation=3; // N, rotated east.
  const door={visibleModel:1,openState:0,position:[60,55],orientation:[1,0,0]};s.doors.set('5,5',[door]);
  assert.equal(await s.run([55,55],[65,55]),0);door.openState=1;assert.equal(await s.run([55,55],[65,55]),1);
  door.openState=0;b.pathNodes.doors=0;assert.equal(await s.run([55,55],[65,55]),1);
  b.pathNodes.doors=1;door.orientation=[Math.fround(.706),1,0];assert.equal(await s.run([55,55],[65,55]),1);
});
test('door ownership spans native half-unit tile boundaries in native insertion order',()=>{
  assert.deepEqual(doorTileCoordinates([20,20],4,4),[[1,1],[2,1],[1,2],[2,2]]);
  assert.deepEqual(doorTileCoordinates([20,25],4,4),[[1,2],[2,2]]);
  assert.deepEqual(doorTileCoordinates([25,20],4,4),[[2,1],[2,2]]);
  assert.deepEqual(doorTileCoordinates([25,25],4,4),[[2,2]]);
  assert.deepEqual(doorTileCoordinates([0,0],4,4),[[0,0]]);
});
test('region lookup preserves placement rotation and exact native entrance epsilon',()=>{
  for(let orientation=0;orientation<4;orientation++){
    const t=tile(2,3,65,orientation),local=rotateCanonical([10,5],orientation);
    assert.equal(tileRegionEntrance(t,local),0);assert.equal(tileRegionEntrance(t,local.map(v=>v+.001)),-1);
    assert.equal(closestTileRegion(t,[25,35]),0);
  }
  for(const [degrees,rotation] of [[0,0],[-360,0],[90,1],[-270,1],[180,2],[-180,2],[270,3],[-90,3],[45,4]])assert.equal(tileNodeOrientation(degrees),rotation);
});
