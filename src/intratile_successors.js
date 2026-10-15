import {tileSubdivision,findSubdivisionTriangle} from './tile_subdivision.js';
const f=Math.fround;
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native intra-tile successor ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native intra-tile successor provider ${n} is unavailable`);return p[n];};
const magnitude=(a,b)=>{const dx=f(a[0]-b[0]),dy=f(a[1]-b[1]);return f(Math.sqrt(f(f(f(dx*dx)+f(dy*dy))+0)));};
const inside=(point,b)=>b[0]<=point[0]&&point[0]<=b[1]&&b[2]<=point[1]&&point[1]<=b[3];
const estimate=(point,b)=>magnitude(point,[Math.max(b[0],Math.min(b[1],point[0])),Math.max(b[2],Math.min(b[3],point[1]))]);

// IntraTileDFSGenerateSuccessors1402bfec0. Three hierarchy levels (or only
// level0 for optimisation==1), physical edges, inherited accepted-edge masks,
// midpoint/centre traversal and the native level/score insertion pass.
export async function intraTileSuccessors(state,point,triangle,p){
  point=point.map(f);triangle=integer(triangle,'triangle');const optimisation=integer(state.optimisation,'optimisation'),levels=tileSubdivision(state.mesh);
  state.work=(integer(state.work,'work')+300)|0;
  const result=[],metadata=[],lastLevel=optimisation===1?0:2,goal=state.goal.map(f),bounds=state.bounds.map(f),target=integer(state.goalTriangle,'goal triangle');
  state.edgeMasks??=Array(3).fill(null);
  const tileLine=async(a,b,strict)=>{const out={low:0,high:0};const value=await required(p,'tileLine')(state,a,b,out,strict);return{value,out};};
  const line=async(a,b,strict)=>{
    const {value,out}=await tileLine(a,b,strict);if(value!==1)return false;
    return optimisation===1||await required(p,'areaLine')(state,a,b,out.low,out.high)===1;
  };
  for(let level=0;level<=lastLevel;level++){
    const index=triangle>>(4-level*2),indices=levels[level].faces[index],adj=levels[level].adjacency[index];
    if(!indices||!adj)throw new Error('Native intra-tile current triangle is unavailable');
    const vertices=indices.map(n=>levels[2].vertices[n]),atTarget=target<0?-1:target>>(4-level*2);
    if(level===0){
      if(await line(point,goal,0))return[{via:goal.slice(),point:goal.slice(),cost:0,triangle:0}];
      if(atTarget!==-1){
        const corners=[[bounds[0],bounds[2]],[bounds[0],bounds[3]],[bounds[1],bounds[2]],[bounds[1],bounds[3]]];
        const eligible=[point[0]<bounds[0]||point[1]<bounds[2],point[0]<bounds[0]||point[1]>bounds[3],point[0]>bounds[1]||point[1]<bounds[2],point[0]>bounds[1]||point[1]>bounds[3]];
        for(let n=0;n<4;n++)if(eligible[n]&&await line(point,corners[n],1))return[{via:corners[n].slice(),point:corners[n].slice(),cost:0,triangle:0}];
      }
    }
    const mask=state.edgeMasks[level]=[0,0,0];
    if(level>0){
      const parent=state.edgeMasks[level-1];
      if((index%4)===2){
        mask[0]=Number(parent[1]===1&&parent[0]===1);mask[1]=Number(parent[1]===1&&parent[2]===1);mask[2]=Number(parent[0]===1&&parent[2]===1);
        if(level>1&&((triangle>>(6-level*2))%4)===2){const grand=state.edgeMasks[level-2];if(grand[0]===1)mask[2]=1;if(grand[1]===1)mask[0]=1;if(grand[2]===1)mask[1]=1;}
      }else{mask[0]=parent[0];mask[1]=parent[1];}
    }
    for(let edge=0;edge<3;edge++){
      const neighbour=integer(adj[edge],'adjacent triangle');if(mask[edge]!==0||neighbour<0&&neighbour!==-2)continue;
      const a=vertices[edge],b=vertices[(edge+1)%3],via=[f(f(a[0]+b[0])*.5),f(f(a[1]+b[1])*.5)];
      if(optimisation!==1&&!await line(point,via,1))continue;
      let nextPoint,nextTriangle,cost;
      if(neighbour<0){
        if(!inside(via,bounds))continue;
        nextTriangle=level===2?index:findSubdivisionTriangle(state.mesh,level+1,1-level,via,index);nextPoint=via.slice();cost=magnitude(point,via);
      }else{
        nextTriangle=neighbour;for(let n=level;n<2;n++)nextTriangle=(nextTriangle*4+2)|0;
        const face=levels[2].faces[nextTriangle];if(!face)throw new Error('Native intra-tile adjacent centre is unavailable');
        const [x,y,z]=face.map(n=>levels[2].vertices[n]);
        nextPoint=[f(f(f(y[0]+x[0])+z[0])/3),f(f(f(y[1]+x[1])+z[1])/3)];
        if(atTarget!==-1&&atTarget===neighbour){nextPoint=goal.slice();nextTriangle=level===2?atTarget:findSubdivisionTriangle(state.mesh,level+1,1-level,nextPoint,atTarget);}
        if(optimisation!==1&&!await line(via,nextPoint,1))continue;
        cost=f(magnitude(point,via)+magnitude(nextPoint,via));
      }
      result.push({via,point:nextPoint,cost,triangle:nextTriangle});metadata.push({level,score:f(estimate(nextPoint,bounds)+cost)});mask[edge]=1;
      // The original runs a complete backwards adjacent pass, preserving
      // equal scores and only swapping across non-increasing level numbers.
      for(let n=result.length-1;n>0;n--)if(metadata[n].level<=metadata[n-1].level&&metadata[n].score<metadata[n-1].score){
        [result[n],result[n-1]]=[result[n-1],result[n]];[metadata[n],metadata[n-1]]=[metadata[n-1],metadata[n]];
      }
    }
  }
  return result;
}
