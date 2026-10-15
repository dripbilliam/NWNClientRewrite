import { OBJECT_INVALID } from './game_object_array.js';
import { clipTileLine } from './tile_line.js';

const f=Math.fround;
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native safe-point provider ${n} is unavailable`);return p[n];};

// ComputeSafeLocation14036aa90..14036b04a. Native XYZ. Initial safe point
// precedes radius validation; otherwise square rings visit four sides for
// lateral0,+1,-1,+2... (2*ring slots), retaining prior height between queries.
export async function computeSafeLocation(area,origin,range,path,straight,out,p){
  if(!path){required(p,'warning')('Native ComputeSafeLocation: pathfinding information is NULL');return 0;}
  if(!Array.isArray(origin)||origin.length!==3||!origin.every(Number.isFinite)||!Number.isFinite(range)||!Number.isInteger(straight))throw new Error('Native safe-location arguments are unavailable');
  origin=origin.map(f);range=f(range);area.nativePathInfo280=path;const radius=f(path.field4);
  if(!Number.isFinite(radius)||!Number.isFinite(path.fieldC))throw new Error('Native safe-location radius/height is unavailable');
  const height=async point=>{const v=await required(p,'height')(area,point);if(!Number.isFinite(v))throw new Error('Native safe-location terrain height is unavailable');return f(v);};
  let z=await height(origin),candidate=[origin[0],origin[1],z];
  const finish=point=>{out.point=point.slice();return 1;};
  if(await required(p,'safePoint')(area,candidate,path,0)===1)return finish(candidate);
  if(radius<=0){required(p,'warning')('Native ComputeSafeLocation: personal space is <=0');return 0;}
  const epsilon=f(.01),margin=f(.1),low=f(origin[2]-margin),high=f(f(origin[2]+f(path.fieldC))+margin);
  if(await required(p,'lineWalkable')(area,[f(origin[0]-.001),origin[1]],origin.slice(0,2))===0||
    await required(p,'polygons')(area,[f(origin[0]-epsilon),f(origin[1]-epsilon)],[f(origin[0]+epsilon),f(origin[1]+epsilon)],low,high,radius,OBJECT_INVALID,{id:OBJECT_INVALID},1,null,0)===0)straight=0;
  let step=f(range/10);if(radius<=step)step=radius>=margin?radius:margin;
  if(!(step>0))throw new Error('Native safe-location nonpositive search step is unsupported');
  const limit=Math.trunc(f(f(range+epsilon)/step));let visited=0;
  for(let ring=1;ring<=limit;ring++)for(let slot=0;slot<ring*2;slot++){
    const distance=f(f(ring)*step),lateral=f(f(((slot&1)*2-1))*f(Math.trunc((slot+1)/2))),offset=f(step*lateral);
    const sides=[[f(offset+origin[0]),f(origin[1]+distance)],[f(origin[0]+distance),f(origin[1]-offset)],
      [f(origin[0]-offset),f(origin[1]-distance)],[f(origin[0]-distance),f(offset+origin[1])]];
    for(const xy of sides){
      if(++visited>1000000)throw new Error('Native safe-location search exceeds supported candidate budget');
      candidate=[...xy,z];z=await height(candidate);candidate[2]=z;
      if(await p.safePoint(area,candidate,path,0)!==1)continue;
      if(straight!==0){
        if(await p.lineWalkable(area,xy,origin.slice(0,2))!==1)continue;
        const bottom=f(Math.min(origin[2],z)-margin),top=f(f(f(path.fieldC)+margin)+Math.max(origin[2],z));
        if(await p.polygons(area,xy,origin.slice(0,2),bottom,top,radius,OBJECT_INVALID,{id:OBJECT_INVALID},1,null,0)===0)continue;
      }
      return finish(candidate);
    }
  }
  return 0;
}

// ComputeNonVisibleLocation14036a370..14036a9d6. Keeps best output even
// when returning0. Original CountVisibleToPlayers receives an ORIGIN copy,
// independently of the candidate passed to LOS; preserve that call-site quirk.
export async function computeNonVisibleLocation(area,origin,path,straight,out,range,p){
  if(!path){required(p,'warning')('Native ComputeNonVisibleLocation: pathfinding information is NULL');return 0;}
  if(!Array.isArray(origin)||origin.length!==3||!origin.every(Number.isFinite)||!Number.isFinite(range)||!Number.isInteger(straight))throw new Error('Native nonvisible-location inputs are unavailable');
  origin=origin.map(f);range=f(range);out.point=[-1,-1,-1];area.nativePathInfo280=path;
  const radius=f(path.field4);if(!Number.isFinite(radius))throw new Error('Native nonvisible-location radius is unavailable');
  const height=async point=>{const v=await required(p,'height')(area,point);if(!Number.isFinite(v))throw new Error('Native nonvisible-location height is unavailable');return f(v);};
  let z=await height(origin),best=255;const initial=[origin[0],origin[1],z];
  if(await required(p,'safePoint')(area,initial,path,0)===1){const count=await required(p,'countVisible')(area,origin.slice(),255);if(count<best){out.point=initial;best=count;}if(count===0)return 1;}
  let step=f(range/10);if(radius<=step)step=radius>=f(.1)?radius:f(.1);if(!(step>0))throw new Error('Native nonvisible-location nonpositive search step is unsupported');
  const last=f(range+f(.01));let visited=0;
  const candidate=async(x,y)=>{
    if(++visited>1000000)throw new Error('Native nonvisible-location search exceeds supported candidate budget');
    const point=[x,y,z];z=await height(point);point[2]=z;
    if(await p.safePoint(area,point,path,0)!==1)return 0;
    if(straight!==0&&await required(p,'lineWalkable')(area,[x,y],origin.slice(0,2))!==1)return 0;
    const dx=f(origin[0]-x),dy=f(origin[1]-y),dz=f(origin[2]-z),distance=f(f(f(dy*dy)+f(dx*dx))+f(dz*dz));
    if(!(distance<=900)||await required(p,'lineOfSight')(area,origin.slice(),point,[0,0,0],{id:OBJECT_INVALID},OBJECT_INVALID,OBJECT_INVALID,0)!==1)return 0;
    const count=await p.countVisible(area,origin.slice(),best);if(count<best){out.point=point;best=count;}return Number(count===0);
  };
  const advance=(value,delta)=>{const next=f(value+delta);if(next===value)throw new Error('Native nonvisible-location search made no progress');return next;};
  for(let distance=1;distance<=last;distance=advance(distance,step)){
    const minX=f(origin[0]-distance),maxX=f(origin[0]+distance),minY=f(origin[1]-distance),maxY=f(origin[1]+distance);
    for(let x=minX;x<=maxX;x=advance(x,step))for(let y=minY;y<=maxY;y=advance(y,f(maxY-minY)))if(await candidate(x,y))return 1;
    for(let x=minX;x<=maxX;x=advance(x,f(maxX-minX)))for(let y=f(minY+step);y<=f(maxY-radius);y=advance(y,step))if(await candidate(x,y))return 1;
  }
  return 0;
}

// TestSafeLocationPoint140372470..1403728ff. Test the horizontal diameter,
// clipped tile heights/denied faces, object polygons, then a tiny creature
// query with segment=0. This differs from TestDirectLine's traversal/flags.
// Coordinates here are native XYZ; provider callbacks retain that convention.
export async function testSafeLocationPoint(area,point,path,preserveTarget,p){
  if(!path||!Array.isArray(point)||point.length!==3||!point.every(Number.isFinite)||!Number.isInteger(preserveTarget))throw new Error('Native safe-point arguments are unavailable');
  const [x,y,z]=point.map(f),radius=path.field4,height=path.fieldC;
  area.nativePathInfo280=path;
  const from=[f(x-radius),f(y+0)],to=[f(x+radius),f(y+0)],low=f(z-f(.1)),high=f(f(height+f(.1))+z);
  if(x<0||x>f(f(area.width)*10)||y<0||y>f(f(area.height)*10))return 0;
  let cursor=[from[0],from[1],low];
  const tolerance=f(.0001),visited=new Set();
  for(;;){
    const tile=await required(p,'tileAt')(area,cursor);if(!tile)return 0;
    if(visited.has(tile))throw new Error('Native safe-point tile traversal made no progress');visited.add(tile);
    const clippedLine=clipTileLine(tile.x,tile.y,from,to);
    if(!clippedLine.exit)throw new Error('Native safe-point clipping left unavailable output');
    const clipped=await required(p,'clippedWalkable')(tile,from,to);if(clipped.status===0)return 0;
    const min=f(f(clipped.minHeight)+f(-.1)),max=f(f(clipped.maxHeight)+f(height+f(.1)));
    if(await required(p,'noNonWalkTile')(tile,clipped.entry,clipped.exit,min,max,radius,1)===0)return 0;
    const [endX,endY]=clippedLine.exit;
    if(f(to[0]-tolerance)<=endX&&endX<=f(tolerance+to[0])&&f(to[1]-tolerance)<=endY&&endY<=f(tolerance+to[1]))break;
    cursor=[clipped.exit[0],clipped.exit[1],0];
    let current=await p.tileAt(area,cursor);
    while(current===tile){
      const next=[f(cursor[0]+f(.001)),f(cursor[1]+f(.001)),cursor[2]];
      if(next[0]===cursor[0]&&next[1]===cursor[1])throw new Error('Native safe-point increment made no progress');
      cursor=next;current=await p.tileAt(area,cursor);
    }
    if(cursor[0]>to[0])break;
  }
  const hit={id:OBJECT_INVALID};
  if(await required(p,'polygons')(area,from,to,low,high,radius,path.fieldC8,hit,1,null,0)===0)return 0;
  const target=path.field28;if((preserveTarget&255)===0)path.field28=OBJECT_INVALID;
  try{return Number(await required(p,'creatureLine')(area,[f(x-f(.001)),y],[x,y],path,0,0,null,0)!==0);}
  finally{if((preserveTarget&255)===0)path.field28=target;}
}
