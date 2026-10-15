const f=Math.fround;
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native inter-tile ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native inter-tile provider ${n} is unavailable`);return p[n];};
const abs=v=>{v|=0;const sign=v>>31;return((v^sign)-sign)|0;};
const distance=(a,b)=>((abs((a[0]-b[0])|0)+abs((a[1]-b[1])|0))|0);

// InterTileDFS14036cba0. Writes the current route even on failure. Visited
// depths are BYTES indexed by (x*maximumHeight+y)*6+region; a larger depth
// replaces a smaller byte. Candidate generation and tile exits are separate.
export async function interTileDFS(state,depth,budget,x,y,region,p){
  [depth,budget,x,y,region].forEach((v,i)=>integer(v,['depth','budget','x','y','region'][i]));
  const path=state.path,tiles=path.allocations.get(0xe8),points=path.allocations.get(0xf0);
  if(!(tiles instanceof Int32Array)||!(points instanceof Float32Array)||depth<0||depth*2+1>=tiles.length||depth*2+1>=points.length)
    throw new Error('Native inter-tile route allocation is unavailable');
  path.raw.setInt32(0xe0,(depth+1)|0,true);tiles[depth*2]=x;tiles[depth*2+1]=y;
  const goal=state.goal;
  if((depth!==0||budget<=2)&&goal[0]===x&&goal[1]===y&&goal[2]===region){
    let entry=state.goalExit;
    if(depth!==0){
      const px=f(f((tiles[depth*2-2]-x)|0)*10+points[depth*2-2]),py=f(f((tiles[depth*2-1]-y)|0)*10+points[depth*2-1]);
      entry=integer(await required(p,'exitNumber')(x,y,[px,py]),'entry exit');
    }
    const count=path.raw.getInt32(0xcc,true),avoidTiles=path.allocations.get(0xd0),avoidExits=path.allocations.get(0xd8);
    if(count>0&&(!(avoidTiles instanceof Int32Array)||!(avoidExits instanceof Int32Array)||avoidTiles.length<count*2||avoidExits.length<count*2))throw new Error('Native inter-tile avoidance allocation is unavailable');
    for(let n=0;n<count;n++)if(avoidTiles[n*2]===x&&avoidTiles[n*2+1]===y&&avoidExits[n*2]===entry&&avoidExits[n*2+1]===state.goalExit)return 0;
    return 1;
  }
  if(budget<=0||distance(goal,[x,y])>budget)return 0;
  const index=(((state.maximumHeight*x+y)*6)+region)|0,visited=state.visited;
  if(!(visited instanceof Uint8Array)||index<0||index>=visited.length)throw new Error('Native inter-tile visited index is unavailable');
  if(visited[index]>=budget)return 0;visited[index]=budget&255;
  const candidates=await required(p,'successors')(state,depth,x,y,region);
  if(!Array.isArray(candidates))throw new Error('Native inter-tile successor allocation is unavailable');
  for(const candidate of candidates){
    points[depth*2]=f(candidate.exit[0]);points[depth*2+1]=f(candidate.exit[1]);
    const result=await interTileDFS(state,(depth+1)|0,(budget-1)|0,...candidate.tile,candidate.region,p);
    if(result!==0)return result;
  }
  return 0;
}

// GenerateInterTilePath14036bc90. Iterative deepening advances by TWO,
// always attempts once and releases all three temporary search allocations.
export async function generateInterTilePath(state,threshold,start,p){
  const maximumWidth=integer(state.maximumWidth,'maximum width'),maximumHeight=integer(state.maximumHeight,'maximum height');
  const size=(maximumWidth*maximumHeight*6)|0,limit=(distance(start,state.goal)+23)|0;
  if(size<0||limit<0)throw new Error('Native inter-tile allocation overflow is unsupported');
  state.visited=new Uint8Array(size);state.successorStorage=Array((limit*integer(state.successorsPerDepth,'successor stride'))|0).fill(null);
  state.exitScratch=new Int32Array(integer(state.exitScratchCount,'exit scratch count'));
  let result;
  do{
    threshold.value=(integer(threshold.value,'threshold')+2)|0;
    result=await interTileDFS(state,0,threshold.value,...start,p);
  }while(result===0&&threshold.value<limit-2);
  state.visited=state.successorStorage=state.exitScratch=null;return result;
}
