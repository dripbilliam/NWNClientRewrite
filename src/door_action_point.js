const f=Math.fround;
function transform(door,point){
  if(!point||point.length!==3||!point.every(Number.isFinite))throw new Error('Native door action-point storage is unavailable');
  const [x,y,z]=point.map(f),[ox,oy]=door.nativeOrientation.map(f),p=door.nativePosition.map(f);
  return[f(p[0]+f(f(oy*x)+f(ox*y))),f(p[1]+f(f(oy*y)-f(ox*x))),f(p[2]+z)];
}
function local(door,state,side){
  const points=door.nativeDoorSurface?.actionPoints;
  if(!points)throw new Error('Native door surface action points are unavailable');
  return points.flat()[state*2+(side&255)];
}
// GetActionPoint1404201e0..1404202da. Animation is an INT, side a BYTE.
// Unknown animations transform the zero vector, returning the door position.
export function doorActionPoint(door,animation,side){
  const state={22:0,50:1,51:2}[animation|0];
  return transform(door,state===undefined?[0,0,0]:local(door,state,side));
}
const magnitude=v=>{const [x,y,z]=v.map(f),s=f(f(f(x*x)+f(y*y))+f(z*z));return s===1?1:s>0?f(Math.sqrt(s)):0;};
const distance=(a,b)=>magnitude(a.map((v,i)=>f(v-b[i])));

// GetNearestActionPoint140420360..1404207e3. Ties choose the second point;
// a failed first walkability test tries second. For nonclosed animation the
// closed pair can replace the candidate only at strictly smaller distances.
export async function nearestDoorActionPoint(door,from,forceClosed,p){
  const sampled=p.animation(door),area=await p.area(door),animation=forceClosed!==0?22:sampled,
    a=doorActionPoint(door,animation,0),b=doorActionPoint(door,animation,1),da=distance(from,a),db=distance(from,b);
  let best=[0,0,0],bound=1000;
  if(da<db){
    if(area&&await p.walkable(area,a)!==0){best=a;bound=da;}
    else if(area&&await p.walkable(area,b)!==0){best=b;bound=db;}
  }else if(area&&await p.walkable(area,b)!==0){best=b;bound=db;}
  if(animation!==22){
    const closedA=transform(door,local(door,0,0)),closedB=transform(door,local(door,0,1)),
      ca=distance(from,closedA),cb=distance(from,closedB);
    if(ca<bound&&area&&await p.walkable(area,closedA)!==0){best=closedA;bound=ca;}
    if(cb<bound&&area&&await p.walkable(area,closedB)!==0)best=closedB;
  }
  return best.every(v=>v===0)?door.nativePosition.slice():best;
}
