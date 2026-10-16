import {rotateCanonical} from './tile_path_node.js';
const f=Math.fround,low=f(.0001),high=f(9.9999);

// InterTileDFSExploreArea14036ce60. Visited bytes store remaining depth,
// including the final ring. Graph choice uses door Appearance+3f8, distinct
// from VisibleModel+498. Resolve doors again during boundary checks.
export async function dfsExploreArea(area,visited,depth,x,y,lx,ly,p){
 const index=(Math.imul(area.width,y)+x)|0,total=Math.imul(area.width,area.height);
 if(index<0||index>=total||depth<=visited[index])return;
 visited[index]=depth;
 if(depth===1||y<0||y>=area.height||x<0||x>=area.width)return;
 const tile=await p.tile(x,y);if(!tile)return;
 const nodes=tile.pathNodes;let kind=0,orientation=0;
 if(nodes.doorVisibility){
  const ids=await p.doors(tile);
  for(let i=0;i<ids.length;i++){
   const door=await p.door(ids[i]);
   if(door&&p.appearance(door)!==0&&(await p.open(door)&255)===0){kind=nodes.doorVisibility;orientation=nodes.doorVisibilityOrientation;}
  }
 }
 if(!kind){kind=nodes.visibility||nodes.path;orientation=nodes.visibility?nodes.visibilityOrientation:nodes.pathOrientation;}
 const graph=await p.graph(kind&255,orientation&255);if(!graph)return;
 let region=await p.regionEntrance(tile,[lx,ly],kind&255,orientation&255);
 if(region===-1)region=await p.closestRegion(tile,[f(f(f(x)*10)+f(lx)),f(f(f(y)*10)+f(ly))],kind&255,orientation&255);
 for(let entrance=0;entrance<graph.entrances.length;entrance++){
  const [a,b]=rotateCanonical(graph.entrances[entrance],tile.orientation);
  if(graph.regions[entrance]!==region)continue;
  const nx=a>high?x+1:a<low?x-1:x,ny=b>high?y+1:b<low?y-1:y,
   local=[a>high?0:a<low?10:a,b>high?0:b<low?10:b],next=(Math.imul(area.width,ny)+nx)|0;
  if(next<0||next>=total||visited[next]>=depth-1||ny<0||ny>=area.height||nx<0||nx>=area.width)continue;
  const neighbour=await p.tile(nx,ny);if(!neighbour)continue;
  if(nodes.doors!==0&&neighbour.pathNodes.doors!==0){
   const yEdge=nx===x,min=yEdge?[f(f(x)*10),f(f(b-.5)+f(f(y)*10))]:[f(f(a-.5)+f(f(x)*10)),f(f(y)*10)],
    max=yEdge?[f(min[0]+10),f(f(b+.5)+f(f(y)*10))]:[f(f(a+.5)+f(f(x)*10)),f(min[1]+10)];
   let blocked=false;const ids=await p.doors(tile);
   for(let i=0;i<ids.length;i++){
    const door=await p.door(ids[i]);if(!door)continue;
    if(p.appearance(door)===0&&await p.blockSight(door)!==1)continue;
    if((await p.open(door)&255)!==0)continue;
    const position=p.position(door);if(position[1]<min[1]||position[1]>max[1]||position[0]<min[0]||position[0]>max[0]||Number.isNaN(position[0])||Number.isNaN(position[1]))continue;
    const orientation=p.orientation(door),dot=f(f(f(f(orientation[0])*Number(!yEdge))+f(f(orientation[1])*Number(yEdge)))+f(f(orientation[2])*0));
    if(Math.abs(dot)>.707){blocked=true;break;}
   }
   if(blocked)continue;
  }
  await dfsExploreArea(area,visited,depth-1,nx,ny,local[0],local[1],p);
 }
}
