import { OBJECT_INVALID } from './game_object_array.js';

const f=Math.fround;
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native ${n} is unavailable`);return v|0;};
const squared=(x,y)=>f(f(y*y)+f(x*x));
const xy=o=>{
  if(!Array.isArray(o.position)||!o.position.every(Number.isFinite))throw new Error('Native collision position is unavailable');
  return[f(o.position[0]),f(-o.position[2])];
};
function normal2(x,y){
  const length=f(f(x*x)+f(y*y));
  if(length===1)return[x,y];if(!(length>0))return[1,0];
  const factor=f(Math.sqrt(f(1/length)));return[f(x*factor),f(y*factor)];
}

// CNWSArea virtual+8 = NoCreaturesOnLine 14036ec90..14036f416;
// vtable140ddad28 entry140ddad30. Native X-scan, visibility, strict bounds,
// radius contact and optional nearest blocker are preserved independently
// of tile/door/placeable LOS. No inferred cylinder raycast replaces this query.
export async function noCreaturesOnLine(area,x1,y1,x2,y2,path,segment,bump,output,targetOverlap,p){
  [x1,y1,x2,y2]=[x1,y1,x2,y2].map(f);
  segment=integer(segment,'creature line segment flag');bump=integer(bump,'creature bump flag');
  targetOverlap=integer(targetOverlap,'target overlap flag');if(output)output.id=OBJECT_INVALID;
  if(segment===0&&x1===x2&&y1===y2)return 1;
  if(!path)return 0;
  const ownerId=path.field24,targetId=path.field28,radius=f(path.field8),owner=p.creature(ownerId);
  let ownerX=0,ownerY=0,visibleOnly=false,allowBump=0;
  if(owner){
    if(await p.dm(owner)===1&&integer(await p.dmBody(owner),'DM body flag')===0||
      integer(await p.collision788(owner),'collision flag +788')===1||integer(await p.ghost(owner),'cutscene ghost flag')===1)return 1;
    [ownerX,ownerY]=xy(owner);
    if(segment!==0&&targetOverlap===0&&path.field19c===0){
      visibleOnly=true;
      if(integer(await p.pc(owner),'PC flag')===0&&integer(await p.possessedFamiliar(owner),'possessed familiar')===0&&
        squared(f(ownerX-x1),f(ownerY-y1))>100&&squared(f(ownerX-x2),f(ownerY-y2))>100)return 1;
    }
    allowBump=bump;
  }
  // For point queries the entire window is centered on the destination.
  const highX=f((segment!==0?Math.max(x1,x2):x2)+radius),lowX=f((segment!==0?Math.min(x1,x2):x2)-radius);
  const highY=f((segment!==0?Math.max(y1,y2):y2)+radius),lowY=f((segment!==0?Math.min(y1,y2):y2)-radius);
  const dx=f(x2-x1),dy=f(y2-y1),normal=normal2(f(-dy),dx);
  const ids=p.areaIds(area),last=integer(ids.length,'area object count')-1;
  const first=await p.firstByX(area,f(lowX-5));if(first===null)return 1;
  let closest=f(10000000);
  for(let index=first;index<=last;index++){
    // Count is captured once, but the native array pointer/ID is re-read.
    const id=p.areaIds(area)[index];if(!Number.isInteger(id))throw new Error('Native creature line live area ID is unavailable');
    if((id>>>0)===ownerId||(id>>>0)===targetId)continue;
    const creature=p.creature(id>>>0);if(!creature)continue;
    const [cx,cy]=xy(creature);if(cx>f(highX+5))break;
    const otherRadius=f(await p.radius(creature));
    if(!(cx<f(otherRadius+highX)&&f(lowX-otherRadius)<cx&&cy<f(otherRadius+highY)&&f(lowY-otherRadius)<cy))continue;
    if(await p.dm(creature)!==0&&integer(await p.dmBody(creature),'candidate DM body flag')!==1)continue;
    if(integer(await p.collision788(creature),'candidate collision flag +788')!==0||integer(await p.ghost(creature),'candidate ghost flag')!==0)continue;
    if(visibleOnly){
      if(integer(await p.pc(owner),'observer PC flag')===0&&squared(f(cx-ownerX),f(cy-ownerY))>100)continue;
      const flags=await p.visibility(owner,id>>>0);if(flags===null||(integer(flags,'collision visibility flags')&3)===0)continue;
    }
    const fromX=f(x1-cx),fromY=f(y1-cy),fromDistance=output?squared(fromX,fromY):0;
    if(output&&fromDistance>closest)continue;
    const combined=f(radius+f(await p.radius(creature)));
    const perpendicular=Math.abs(f(f(fromY*normal[1])+f(fromX*normal[0])));
    if(perpendicular>combined||await p.dead(creature)!==0)continue;
    const endX=f(x2-cx),endY=f(y2-cy),contact=f(combined*combined),endDistance=squared(endX,endY);
    const insideEnd=endDistance<contact;
    const enters=f(f(fromY*dy)+f(fromX*dx))<0;
    const passes=f(f(dy*endY)+f(dx*endX))>0;
    if(!(segment===0&&insideEnd||enters&&(passes||insideEnd)))continue;
    if(allowBump!==0){
      if(typeof p.bumpable!=='function')throw new Error('Native creature bumpability is unavailable');
      if(await p.bumpable(owner,creature)!==0)continue;
    }
    if(targetOverlap===1){
      const currentTarget=p.creature(path.field28),candidate=p.creature(id>>>0);
      if(currentTarget&&candidate){
        const [tx,ty]=xy(currentTarget),[ox,oy]=xy(candidate);
        const overlap=f(f(await p.radius(candidate))+f(await p.radius(currentTarget)));
        if(f(squared(f(tx-ox),f(ty-oy))+0)<f(overlap*overlap))continue;
      }
    }
    if(!output)return 0;
    output.id=id>>>0;closest=fromDistance;
  }
  return output&&output.id!==OBJECT_INVALID?0:1;
}
