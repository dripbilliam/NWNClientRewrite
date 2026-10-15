import {tilePathNode,rotateCanonical,closestTileRegion,tileRegionEntrance} from './tile_path_node.js';
const f=Math.fround,low=f(.0001),high=f(9.9999);
const cvtt=value=>value>=-2147483648&&value<2147483648?Math.trunc(value):-2147483648;

// CNWSDoor::AddToArea14041e410 associates up to four tiles using floorf
// of the position +/- .5, independently of the DWK bounding box.
export function doorTileCoordinates(position,width,height){
  const [x,y]=position.map(f),xs=[-1,1].map(sign=>Math.floor(f(f(x+sign*.5)/10))),ys=[-1,1].map(sign=>Math.floor(f(f(y+sign*.5)/10)));
  const points=[[xs[0],ys[0]]];
  if(xs[0]!==xs[1]&&ys[0]!==ys[1])points.push([xs[1],ys[0]],[xs[0],ys[1]]);
  if(xs[0]!==xs[1]||ys[0]!==ys[1])points.push([xs[1],ys[1]]);
  return points.filter(([a,b])=>a>=0&&b>=0&&a<width&&b<height);
}

// PlotSoundPath140370e60 / InterTileDFSSoundPath14036e260.
// The visited depth belongs to the tile, not each region. Boundary rejection
// and entrance order deliberately follow the native DFS, not shortest-path BFS.
export async function plotSoundPath(area,path,p){
  if(!path?.raw)throw new Error('Native sound path information is unavailable');
  const point=offset=>[path.raw.getFloat32(offset,true),path.raw.getFloat32(offset+4,true)];
  const start=point(0x64),goal=point(0x4c),slot=v=>cvtt(f(v/10));
  const [sx,sy]=start.map(slot),[gx,gy]=goal.map(slot),valid=(x,y)=>x>=0&&y>=0&&x<area.width&&y<area.height;
  if(!valid(sx,sy))return 0;
  const first=await p.tile(sx,sy),region=closestTileRegion(first,start),visited=new Uint8Array(area.width*area.height);
  area.nativeSoundPath288=path;
  async function dfs(depth,x,y,region){
    const index=y*area.width+x;
    if(index<0||index>=visited.length||depth<1||depth<=visited[index])return 0;
    visited[index]=depth;
    const tile=await p.tile(x,y);
    if(!valid(gx,gy))return 0;
    const goalTile=await p.tile(gx,gy);
    if(x===gx&&y===gy&&closestTileRegion(goalTile,goal)===region)return 1;
    const nodes=tile.pathNodes,doors=await p.doors(tile);
    let kind=0,orientation=0;
    if(nodes.doorVisibility){for(const door of doors){if(door.visibleModel!==0&&door.openState===0){kind=nodes.doorVisibility;orientation=nodes.doorVisibilityOrientation;}}}
    if(!kind){kind=nodes.visibility||nodes.path;orientation=nodes.visibility?nodes.visibilityOrientation:nodes.pathOrientation;}
    const graph=tilePathNode(kind,orientation);if(!graph)return 0;
    for(let entrance=0;entrance<graph.entrances.length;entrance++){
      if(graph.regions[entrance]!==region)continue;
      const [a,b]=rotateCanonical(graph.entrances[entrance],tile.orientation);
      const nx=a>high?x+1:a<low?x-1:x,ny=b>high?y+1:b<low?y-1:y;
      const local=[a>high?0:a<low?10:a,b>high?0:b<low?10:b],next=ny*area.width+nx;
      if(next<0||next>=visited.length)return 0;
      if(visited[next]>=depth-1||Math.abs(nx-gx)+Math.abs(ny-gy)+(4-depth)>=4||!valid(nx,ny))continue;
      const neighbour=await p.tile(nx,ny);
      if(nodes.doors!==0&&neighbour.pathNodes.doors!==0){
        const yEdge=nx===x;
        const min=yEdge?[f(x*10),f(f(b-.5)+f(y*10))]:[f(f(a-.5)+f(x*10)),f(y*10)];
        const max=yEdge?[f(min[0]+10),f(f(b+.5)+f(y*10))]:[f(f(a+.5)+f(x*10)),f(min[1]+10)];
        let blocked=false;
        for(const door of doors){
          // Invisible models use the doortypes BlockSight INT, initialized ONE
          // before the native lookup. Visible models always enter this check.
          if((door.visibleModel===0?door.blockSight:1)!==1||door.openState!==0)continue;
          if(door.position.every((v,i)=>v>=min[i]&&v<=max[i])&&Math.abs(f(door.orientation[yEdge?1:0]))>.707){blocked=true;break;}
        }
        if(blocked)continue;
      }
      if(await dfs(depth-1,nx,ny,tileRegionEntrance(neighbour,local))===1)return 1;
    }
    return 0;
  }
  return dfs(5,sx,sy,region);
}
