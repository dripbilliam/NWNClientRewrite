import { OBJECT_INVALID } from './game_object_array.js';
import { clipTileLine } from './tile_line.js';

const f=Math.fround;
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native safe-point provider ${n} is unavailable`);return p[n];};

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
