import {resourceFlow} from './resource_flow.js';
const f=Math.fround,invalid=0x7f000000,epsilon=f(.0001),edge=f(9.9999),scale=f(.1);
const slot=value=>{for(let i=0;i<32;i++)if(f(i*10)<=value&&value<f((i+1)*10))return i;return-1;};
const cvtt=value=>value>=-2147483648&&value<2147483648?Math.trunc(value):-2147483648;

// Client7e6a20: each clipped segment owns its height/polygon/creature checks.
// This is distinct from server371d30's aggregate-height/full-line query.
export function clientDriveLine(area,from,to,radius,height,actorId,checkCreatures,p){return resourceFlow(driveLine(area,from,to,radius,height,actorId,checkCreatures,p));}
function* driveLine(area,from,to,radius,height,actorId,checkCreatures,p){
 if(![...from,...to,radius,height].every(Number.isFinite))throw Error('Native client drive line is unavailable');
 from=from.map(f);to=to.map(f);radius=f(radius);height=f(height);
 let x=slot(from[0]),y=slot(from[1]);const dx=from[0]<=to[0]?1:-1,dy=from[1]<=to[1]?1:-1,visited=new Set();
 for(;;){
  const key=`${x}:${y}`;if(visited.has(key))throw Error('Native client tile traversal made no progress');visited.add(key);
  const tile=yield p.tile(area,x,y);if(!tile)return 0;
  const clipped=yield p.clippedWalkable(tile,from,to);if(clipped.status!==1)return 0;
  const low=f(clipped.minHeight-f(.1)),high=f(clipped.maxHeight+f(height+f(.1)));
  if((yield p.noNonWalkTile(tile,clipped.entry,clipped.exit,low,high,radius,0))!==1)return 0;
  if((yield p.noNonWalkWorld(clipped.entry,clipped.exit,low,high,radius,invalid))!==1)return 0;
  if(checkCreatures&&(yield p.noCreatures(clipped.entry,clipped.exit,actorId,radius))!==1)return 0;
  const [ex,ey]=clipped.exit;
  if(!(ex<f(to[0]-epsilon)||f(to[0]+epsilon)<ex||ey<f(to[1]-epsilon)||f(to[1]+epsilon)<ey))break;
  const localX=f(ex-f(x*10)),localY=f(ey-f(y*10));
  if(dx===1?localX>=edge:localX<=epsilon)x+=dx;
  if(dy===1?localY>=edge:localY<=epsilon)y+=dy;
 }
 // The original uses the X direction for BOTH extension components.
 const extension=[f(to[0]+f(dx*radius)),f(to[1]+f(dx*radius)),0];
 if(cvtt(f(to[0]*scale))!==cvtt(f(extension[0]*scale))||cvtt(f(to[1]*scale))!==cvtt(f(extension[1]*scale)))return (yield p.extensionWalkable(to,extension,radius))===0?0:1;
 return 1;
}

//7e7210 only traverses walkable clipped tile segments, using the same32
// native coordinate slots. Its caller supplies endpoint extension and radius.
export function clientDriveEdge(area,from,to,p){return resourceFlow(driveEdge(area,from,to,p));}
function* driveEdge(area,from,to,p){
 from=from.map(f);to=to.map(f);let x=slot(from[0]),y=slot(from[1]);const dx=from[0]<=to[0]?1:-1,dy=from[1]<=to[1]?1:-1,visited=new Set();
 for(;;){
  const key=`${x}:${y}`;if(visited.has(key))throw Error('Native client edge traversal made no progress');visited.add(key);
  const tile=yield p.tile(area,x,y);if(!tile)return 0;const clipped=yield p.clippedWalkable(tile,from,to);if(clipped.status!==1)return 0;
  const [ex,ey]=clipped.exit;if(!(ex<f(to[0]-epsilon)||f(to[0]+epsilon)<ex||ey<f(to[1]-epsilon)||f(to[1]+epsilon)<ey))return 1;
  const localX=f(ex-f(x*10)),localY=f(ey-f(y*10));if(dx===1?localX>=edge:localX<=epsilon)x+=dx;if(dy===1?localY>=edge:localY<=epsilon)y+=dy;
 }
}

// Client767740 uses displayed2D positions and appearance PERSPACE. It has
// no server visibility/death/height/bump filters. Keep its cyclic list private.
export function clientCreatureLine(state,from,to,radius,ignoredId,p){
 const [x1,y1]=from.map(f),[x2,y2]=to.map(f);radius=f(radius);
 if(![x1,y1,x2,y2,radius].every(Number.isFinite))throw Error('Native client creature line is unavailable');
 if(x1===x2&&y1===y2)return 1;
 const owner=p.owner?.(ignoredId);
 if(owner&&(owner.field3b0_110===1&&owner.field3b0_114===0||owner.id===p.controlledId&&p.controlFlag===1))return 1;
 const dx=f(x2-x1),minX=Math.min(x1,x2),maxX=Math.max(x1,x2),minY=Math.min(y1,y2),maxY=Math.max(y1,y2),slope=dx===0?0:f(f(y2-y1)/dx),constant=dx===0?0:f(y1-f(slope*x1)),normalScale=dx===0?0:f(Math.sqrt(f(1/f(f(slope*slope)+1))));
 const next=()=>{if(!state.ids.length)return null;state.cursor=((state.cursor??-1)+1)%state.ids.length;return p.object(state.ids[state.cursor])??null;};
 const first=next();if(!first)return 1;let object=first;
 do{
  if(object&&object.id!==ignoredId&&object.objectType===5){
   const [cx,cy]=object.position.map(f),combined=f(radius+f(p.radius(object)));let clear=true;
   if(dx===0&&cy>minY&&cy<maxY)clear=cx<f(maxX-combined)||f(combined+maxX)<cx;
   else if(dx===0){const end=cy<=minY?[minX,minY]:[maxX,maxY],ox=f(cx-end[0]),oy=f(cy-end[1]);clear=combined<f(Math.sqrt(f(f(ox*ox)+f(oy*oy))));}
   else{
    const lineY=f(f(cx*slope)+constant),perpendicular=f(Math.abs(f(cy-lineY))*normalScale);
    if(perpendicular<combined){const sign=cy<lineY?-1:1,projectedX=f(f(f(f(sign*perpendicular)*slope)*normalScale)+cx);if(minX<=projectedX&&projectedX<=maxX)return 0;}
    const ox=f(cx-x2),oy=f(cy-y2);clear=combined<f(Math.sqrt(f(f(ox*ox)+f(oy*oy))));
   }
   if(!clear)return 0;
  }
  object=next();
 }while(object!==first);
 return 1;
}
