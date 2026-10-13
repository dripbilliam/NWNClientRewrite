const f=Math.fround;

// ComputeClippedLineSegment 1402bbf60..1402bc3c0. Inclusive 10-unit
// tile bounds; choose the X-edge intersection first if it is in bounds.
// Preserve native float divisions/products instead of a double-precision
// generic clipping algorithm. Coordinates here are native horizontal X/Y.
export function clipTileLine(tileX,tileY,from,to){
  if(![tileX,tileY].every(Number.isInteger)||![...from,...to].every(Number.isFinite))
    throw new Error('Native tile clipping inputs are unavailable');
  const [x1,y1]=from.map(f),[x2,y2]=to.map(f);
  const lowX=f(f(tileX)*10),lowY=f(f(tileY)*10),highX=f(10+lowX),highY=f(10+lowY);
  const vertical=x1===x2,horizontal=y1===y2;
  const inside=(x,y)=>x>=lowX&&x<=highX&&y>=lowY&&y<=highY;
  function endpoint(entry){
    const x=entry?x1:x2,y=entry?y1:y2;
    if(inside(x,y))return[x,y];
    let edgeX=x2,atY=x2;
    if(!vertical){
      edgeX=entry?(x2<x1?highX:lowX):(x1<x2?highX:lowX);
      atY=f(f(f(f(y2-y1)/f(x2-x1))*f(edgeX-x1))+y1);
    }
    if(!vertical&&atY>=lowY&&atY<=highY)return[edgeX,atY];
    let edgeY=x2,atX=x2;
    if(!horizontal){
      edgeY=entry?(y2<y1?highY:lowY):(y1<y2?highY:lowY);
      atX=f(f(f(f(x2-x1)/f(y2-y1))*f(edgeY-y1))+x1);
    }
    if(!horizontal&&atX>=lowX&&atX<=highX)return[atX,edgeY];
    return null;
  }
  const entry=endpoint(true),exit=endpoint(false);
  return{status:entry&&exit?1:0,entry,exit};
}

const required=(p,name)=>{if(typeof p[name]!=='function')throw new Error(`Native direct-line provider ${name} is unavailable`);return p[name];};
const cvtt=value=>value>=-2147483648&&value<2147483648?Math.trunc(value):-2147483648;
const tolerance=f(0.0001),upperEdge=f(9.9999),tileScale=f(0.1);
function traversal(area,from,to){
  if(![area.width,area.height].every(Number.isInteger)||![...from,...to].every(Number.isFinite))throw new Error('Native area line geometry is unavailable');
  from=from.map(f);to=to.map(f);
  return{from,to,x:cvtt(f(from[0]/10)),y:cvtt(f(from[1]/10)),dx:to[0]<from[0]?-1:1,dy:to[1]<from[1]?-1:1};
}
function advance(state,exit){
  const [x,y]=exit;
  const complete=!(x<f(state.to[0]-tolerance)||f(state.to[0]+tolerance)<x||y<f(state.to[1]-tolerance)||f(state.to[1]+tolerance)<y);
  if(complete)return true;
  const localX=f(x-f(f(state.x)*10)),localY=f(y-f(f(state.y)*10));
  if(state.dx===1?localX>=upperEdge:localX<=tolerance)state.x+=state.dx;
  if(state.dy===1?localY>=upperEdge:localY<=tolerance)state.y+=state.dy;
  return false;
}
const outside=(a,s)=>s.x<0||s.y<0||s.x>=a.width||s.y>=a.height;

// TestLineWalkable 140372220: tile traversal only, returning0/1.
// Lower surface-mesh clipping remains an actual required provider.
export async function testLineWalkable(area,from,to,p){
  const state=traversal(area,from,to),visited=new Set();
  for(;;){
    if(outside(area,state))return 0;
    const key=`${state.x}:${state.y}`;
    if(visited.has(key))throw new Error('Native tile traversal made no progress');visited.add(key);
    const tile=await required(p,'tile')(area,state.x,state.y);if(!tile)return 0;
    const clipped=await required(p,'clippedWalkable')(tile,state.from,state.to);
    if(clipped.status!==1)return 0;if(advance(state,clipped.exit))return 1;
  }
}

// TestDirectLine 140371d30..14037221f: clipped tile traversal, height
// bounds, endpoint clearance, object polygons, then virtual+8 creatures.
// Preserve distinct native return0/-1/-2/-3/1 instead of collapsing to bool.
export async function testDirectLine(area,from,to,radius,height,flag,p){
  const state=traversal(area,from,to),visited=new Set();radius=f(radius);height=f(height);
  if(!Number.isInteger(flag))throw new Error('Native direct-line flag is unavailable');
  let minHeight=0,maxHeight=0;
  for(;;){
    if(outside(area,state))return 0;
    const key=`${state.x}:${state.y}`;
    if(visited.has(key))throw new Error('Native tile traversal made no progress');visited.add(key);
    const tile=await required(p,'tile')(area,state.x,state.y);if(!tile)return 0;
    const clipped=await required(p,'clippedWalkable')(tile,state.from,state.to);if(clipped.status!==1)return -1;
    const low=f(f(clipped.minHeight)-tileScale),high=f(f(height+tileScale)+f(clipped.maxHeight));
    let nextMin=low,nextMax=high;
    if(minHeight!==0||maxHeight!==0){if(minHeight<=low)nextMin=minHeight;if(high<=maxHeight)nextMax=maxHeight;}
    // Native re-resolves the tile after clipping before the denied polygon
    // query (140371f23..f84); do not retain the earlier pointer across a query.
    const collisionTile=await required(p,'tile')(area,state.x,state.y);
    if(!collisionTile)throw new Error('Native collision tile disappeared after clipping');
    if(await required(p,'noNonWalkTile')(collisionTile,clipped.entry,clipped.exit,low,high,radius,0)===0)return -1;
    minHeight=nextMin;maxHeight=nextMax;
    if(advance(state,clipped.exit))break;
  }
  const extension=[f(f(state.dx*radius)+state.to[0]),f(f(state.dy*radius)+state.to[1])];
  const sameTile=cvtt(f(state.to[0]*tileScale))===cvtt(f(extension[0]*tileScale))&&cvtt(f(state.to[1]*tileScale))===cvtt(f(extension[1]*tileScale));
  if(!sameTile&&await testLineWalkable(area,state.to,extension,p)===0)return -1;
  const path=area.nativePathInfo280;
  if(!path)throw new Error('Native direct-line path information is unavailable');
  const hit={id:0};
  if(await required(p,'noNonWalkDetailed')(area,state.from,state.to,minHeight,maxHeight,radius,path.fieldC8,hit,Number(flag===0),null,0)===0)return -2;
  if(radius<=0)return -3;
  if(await required(p,'noCreatures')(area,state.from,state.to,path,1,flag,null,0)===0)return -3;
  return 1;
}
