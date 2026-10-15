import {tilePathNode} from './tile_path_node.js';
import {rotateTilePoint} from './tile_surface_mesh.js';
const f=Math.fround,epsilon=f(.0001),high=f(9.9999),padding=f(.1);
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native intra-tile exit provider ${n} is unavailable`);return p[n];};

// GenerateBestIntraTileExit1402bd950..1402be7f5. Canonical corridor
// candidates, direction weights and collision probes preserve native order.
// Unlike strict line admission, the expanding fallback rejects only zero.
export async function generateBestIntraTileExit(state,start,p){
  const {tile,path}=state,exits=path.allocations.get(0xf0),tiles=path.allocations.get(0xe8),count=path.raw.getInt32(0xe0,true);
  if(!(exits instanceof Float32Array)||exits.length<2)throw new Error('Native intra-tile exit point is unavailable');
  if(count>2&&(!(tiles instanceof Int32Array)||tiles.length<6))throw new Error('Native intra-tile exit route is unavailable');
  const at=[f(f(tile.x)*10),f(f(tile.y)*10)],goal=[exits[0],exits[1]],radius=Math.max(padding,path.raw.getFloat32(4,true));
  if(!Number.isFinite(radius)||!goal.every(Number.isFinite))throw new Error('Native intra-tile exit geometry is unavailable');
  state.goal=goal.slice();state.goalTriangle=-1;
  let axis=-1,halfWidth=epsilon,lateral=0,inward=1,current=0,bounds=[f(goal[0]-epsilon),f(goal[0]+epsilon),0,0],corridor=false;
  const edgeWidth=(axis,coordinate)=>{
    const graph=p.pathNode?required(p,'pathNode')(tile):tilePathNode(tile.pathNodes.path,tile.pathNodes.pathOrientation);
    if(!graph?.entrances)throw new Error('Native intra-tile exit path node is unavailable');
    const entries=graph.entrances.filter(point=>Math.abs(f(coordinate-point[axis]))<=epsilon),less=entries.filter(point=>point[1-axis]<goal[1-axis]).length;
    if(entries.length===1)return 5;if(entries.length===2)return f(2.5);if(entries.length===3)return less===1?3:1;
    throw new Error('Native intra-tile exit edge count is unsupported');
  };
  const candidates=Array.from({length:5},()=>goal.slice());
  if(goal[1]>high||goal[1]<epsilon){
    halfWidth=edgeWidth(1,goal[1]);corridor=true;lateral=0;inward=goal[1]>high?-1:1;
    const wide=f(halfWidth*f(.8)),inner=f(halfWidth*.5*Number(f(.8))),step=f(halfWidth/5);
    [-wide,-inner,0,inner,wide].forEach((v,n)=>candidates[n][0]=f(goal[0]+v));
    for(let n=1;n<5;n++){const lo=f(goal[0]+f(step*(n*2-5))),hi=f(goal[0]+f(step*(n*2-3)));if(lo<=start[0]&&start[0]<=hi)current=n;}
    if(count>2)axis=tile.orientation;
    bounds=[f(goal[0]-halfWidth),f(goal[0]+halfWidth),0,0];
  }
  let lateralHalfWidth=f(halfWidth*f(.09));halfWidth=epsilon;
  if(goal[0]>high||goal[0]<epsilon){
    halfWidth=edgeWidth(0,goal[0]);corridor=true;lateral=1;inward=goal[0]>high?-1:1;
    const wide=f(halfWidth*f(.8)),inner=f(halfWidth*.5*Number(f(.8))),step=f(halfWidth/5);
    [-wide,-inner,0,inner,wide].forEach((v,n)=>candidates[n]=[goal[0],f(goal[1]+v)]);
    for(let n=0;n<5;n++){const lo=f(goal[1]+f(step*(n*2-5))),hi=f(goal[1]+f(step*(n*2-3)));if(lo<=start[1]&&start[1]<=hi)current=n;}
    if(count>2)axis=[1,0,3,2][tile.orientation];
    lateralHalfWidth=f(halfWidth*f(.09));
  }
  bounds[2]=f(goal[1]-halfWidth);bounds[3]=f(goal[1]+halfWidth);state.bounds=bounds;
  // An interior exit already has its epsilon goal box; native returns1
  // without any corridor collision probes.
  if(!corridor)return 1;
  let weight=3,increment=0;
  if(axis>=0){const coordinate=axis%2,delta=tiles[4+coordinate]-tiles[2+coordinate];increment=Math.sign(delta)*(axis>=2?-1:1);weight=3-2*increment;}
  const worldStart=start.map((v,n)=>f(at[n]+f(v)));let best=-1,bestScore=10;
  const areaLine=async(a,b,low,upper)=>{
    const aa=rotateTilePoint(tile,a,false),bb=rotateTilePoint(tile,b,false);
    return required(p,'noNonWalk')(state.area,aa,bb,f(low+f(tile.heightOffset)),f(upper+f(tile.heightOffset)),radius,path.raw.getUint32(0xc8,true));
  };
  const creatureLine=async(a,b)=>required(p,'noCreatures')(state.area,rotateTilePoint(tile,a,false),rotateTilePoint(tile,b,false),path,1,0,null,0);
  const denied=async(a,b,low,upper,r)=>required(p,'noDenied')(tile,a.map((v,n)=>f(v-at[n])),b.map((v,n)=>f(v-at[n])),low,upper,r,0);
  for(let n=0;n<5;n++,weight+=increment){
    const priority=weight+(n===current?1:0),end=candidates[n].map((v,i)=>f(at[i]+v)),clipped=await required(p,'clipped')(tile,worldStart,end);
    if(!clipped.entry?.every(Number.isFinite)||!clipped.exit?.every(Number.isFinite)||!Number.isFinite(clipped.minHeight)||!Number.isFinite(clipped.maxHeight))throw new Error('Native intra-tile exit clip output is unavailable');
    let low=f(clipped.minHeight),upper=f(clipped.maxHeight),clear=false;
    if(clipped.status===1){
      low=f(low-padding);upper=f(f(path.raw.getFloat32(0xc,true)+padding)+upper);
      clear=await denied(clipped.entry,clipped.exit,low,upper,radius)===1&&await areaLine(clipped.entry,clipped.exit,low,upper)===1&&await creatureLine(clipped.entry,clipped.exit)===1;
    }
    let blocked=false;
    if(!clear){
      low=f(low+f(-20.01));upper=f(upper+f(20.01));const maximum=f(radius*f(6.1));let probe=f(radius*.5);
      while(probe<=maximum){
        if(blocked)break;
        const offset=end.slice();offset[1-lateral]=f(offset[1-lateral]+f(f(probe*1)*inward));
        if(await denied(offset,end,low,upper,f(probe+probe))===0||await areaLine(offset,end,low,upper)===0||await creatureLine(offset,end)===0){
          blocked=true;const score=f(f(f(priority)*probe)*f(.5));
          if(probe>=radius&&(best===-1||bestScore<score)){best=n;bestScore=f(f(probe*f(.5))*f(priority));}
        }
        probe=f(probe+radius);
      }
    }
    if(!blocked){let score=f(f(f(priority)*6)*radius);if(clear)score=f(score*7);if(best===-1||bestScore<score){best=n;bestScore=score;}}
  }
  if(best<0)return 0;
  state.goal=candidates[best].slice();
  if(lateral===0){state.bounds[0]=f(state.goal[0]-lateralHalfWidth);state.bounds[1]=f(state.goal[0]+lateralHalfWidth);}
  else{state.bounds[2]=f(state.goal[1]-lateralHalfWidth);state.bounds[3]=f(state.goal[1]+lateralHalfWidth);}
  return 1;
}
