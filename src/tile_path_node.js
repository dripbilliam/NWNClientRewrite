import {tilePathNodeData} from './tile_path_node_data.js';
const f=Math.fround;
const cache=new Map();
export function rotateCanonical(point,orientation){
  const [x,y]=point.map(f);
  switch(orientation){case 0:return[x,y];case 1:return[f(10-y),x];case 2:return[f(10-x),f(10-y)];case 3:return[y,f(10-x)];default:throw new Error('Native tile rotation is invalid');}
}
export function rotateReal(point,orientation){return rotateCanonical(point,(4-orientation)&3);}
export function tilePathNode(kind,orientation){
  kind&=255;orientation&=255;
  if(kind===0)return null;
  if(kind>120||orientation>3)throw new Error('Native tile path graph index is invalid');
  const key=kind*4+orientation;
  if(!cache.has(key)){
    const source=tilePathNodeData[kind-65]??{centres:[],entrances:[],regions:[]};
    // ComputePathNodeRotation rotates raw -5..5 coordinates, then adds 5.
    const rotate=p=>{
      const x=f(p[0]-5),y=f(p[1]-5);
      const q=orientation===0?[x,y]:orientation===1?[-y,x]:orientation===2?[-x,-y]:[y,-x];
      return q.map(v=>f(v+5));
    };
    cache.set(key,{centres:source.centres.map(rotate),entrances:source.entrances.map(rotate),regions:[...source.regions]});
  }
  return cache.get(key);
}
export function tileNodeOrientation(degrees){
  switch(degrees|0){case 0:case 360:case -360:return 0;case 90:case -270:return 1;case 180:case -180:return 2;case 270:case -90:return 3;default:return 4;}
}

// FindTriangle uses physical walkable face order and three f32 half-planes.
export function triangleAt(mesh,point){
  for(let i=0;i<mesh.faces.length;i++){
    const vertices=mesh.faces[i].map(index=>mesh.vertices[index]);
    if(vertices.every((a,j)=>{
      const b=vertices[(j+1)%3];
      return f(f(f(point[1]-a[1])*f(b[0]-a[0]))+f(f(point[0]-a[0])*f(a[1]-b[1])))>=0;
    }))return i;
  }
  return -1;
}
export function closestTileRegion(tile,worldPoint,kind=tile.pathNodes.path,orientation=tile.pathNodes.pathOrientation){
  const graph=tilePathNode(kind,orientation);
  if(!graph)throw new Error('Native tile path node information is unavailable');
  if(graph.centres.length<2)return 0;
  const point=rotateReal(worldPoint.map((v,i)=>f(v-f([tile.x,tile.y][i]*10))),tile.orientation);
  const triangle=triangleAt(tile.mesh,point);
  // Verified machine-code cleanup1402bd259 returns ZERO outside walkable faces.
  if(triangle===-1)return 0;
  const centres=graph.centres.map(p=>triangleAt(tile.mesh,p)),visited=new Uint8Array(tile.mesh.faces.length);
  // Iterative stack preserves recursive edge order 0,1,2 without a JS stack limit.
  const stack=[triangle];
  while(stack.length){
    const face=stack.pop();if(visited[face]===1)continue;
    const region=centres.indexOf(face);if(region!==-1)return region;
    visited[face]=1;
    const adjacent=tile.mesh.adjacency[face];
    for(let edge=2;edge>=0;edge--)if(adjacent[edge]>=0)stack.push(adjacent[edge]);
  }
  // Disconnected triangle fallback1402bd2f5..466 chooses nearest centre,
  // retaining the first region on ties. This runs only after a triangle hit.
  let best=0,distance=Infinity;
  graph.centres.forEach((centre,index)=>{
    const dx=f(point[0]-centre[0]),dy=f(point[1]-centre[1]),d=f(f(dx*dx)+f(dy*dy));
    if(d<distance){distance=d;best=index;}
  });return best;
}
export function tileRegionEntrance(tile,localPoint,kind=tile.pathNodes.path,orientation=tile.pathNodes.pathOrientation){
  const point=rotateReal(localPoint,tile.orientation),graph=tilePathNode(kind,orientation);
  if(!graph)throw new Error('Native tile path node information is unavailable');
  const epsilon=f(.0001);
  const index=graph.entrances.findIndex(p=>point.every((v,i)=>Math.abs(f(v-p[i]))<=epsilon));
  return index===-1?-1:graph.regions[index];
}

const pathGraph=tile=>{
  const graph=tilePathNode(tile.pathNodes.path,tile.pathNodes.pathOrientation);
  if(!graph)throw new Error('Native tile path node information is unavailable');return graph;
};
// CNWSTile GetRegionCoords/GetExit/GetTotalExits wrappers and their
// surface owners. Native failed/uninitialized output buffers are not guessed.
export function tileRegionCoords(tile,index,{outputRequired=true}={}){
  const graph=pathGraph(tile);
  // Surface1402becb7 returns0 when region>=count. Tile1404fdbdb rotates
  // indeterminate local scratch even on failure. An ignored output can be
  // represented by null; a required output must never acquire guessed XY.
  if(Number.isInteger(index)&&index>=0&&index>=graph.centres.length&&!outputRequired)return null;
  if(!Number.isInteger(index)||index<0||index>=graph.centres.length)throw Object.assign(new Error('Native tile region coordinate output is unavailable'),
    {diagnosticContext:{tile:[tile.x,tile.y],region:index,regionCount:graph.centres.length,pathKind:tile.pathNodes.path,pathOrientation:tile.pathNodes.pathOrientation,tileOrientation:tile.orientation}});
  return rotateCanonical(graph.centres[index],tile.orientation);
}
export function tileExit(tile,index){
  const graph=pathGraph(tile);
  if(!Number.isInteger(index)||index<0||index>=graph.entrances.length)throw new Error('Native tile exit output is unavailable');
  return{point:rotateCanonical(graph.entrances[index],tile.orientation),region:graph.regions[index]};
}
export function tileTotalExits(tile){return pathGraph(tile).entrances.length;}

// GetExitNumber1402be940, wrapped by1404fdb30. Boundary exits admit a
// corridor of min(coordinate,10-coordinate); other axes use epsilon bounds.
export function tileExitNumber(tile,localPoint){
  const point=rotateReal(localPoint,tile.orientation),graph=pathGraph(tile),epsilon=f(.0001),high=f(9.9999);
  for(let index=0;index<graph.entrances.length;index++){
    const [x,y]=graph.entrances[index],wx=y>high||y<epsilon?Math.min(x,f(10-x)):epsilon;
    if(f(x-wx)>point[0]||point[0]>f(wx+x))continue;
    const wy=x>high||x<epsilon?Math.min(y,f(10-y)):epsilon;
    if(f(y-wy)<=point[1]&&point[1]<=f(wy+y))return index;
  }
  return 12;
}
