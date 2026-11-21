import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {intraTileSuccessors} from '../src/intratile_successors.js';
const f=Math.fround;
test('intra-tile triangle successors match original hierarchy masks, goal shortcuts, midpoint/centres, scoring and ordering',async()=>{
  const rows=JSON.parse(readFileSync(new URL('../backups/animations/native-intratile-successor-observations.json',import.meta.url))).rows;
  const meshes=JSON.parse(readFileSync(new URL('../backups/animations/native-subdivision-observations.json',import.meta.url))).rows;
  for(const row of rows){const c=row.case,calls=[],state={mesh:meshes[c.mesh].mesh,optimisation:c.optimisation,goal:c.goal,bounds:c.bounds,goalTriangle:c.target,work:0,edgeMasks:Array.from({length:3},()=>[-7,-7,-7])};
    const response=(from,to,strict,area=false)=>{
      const goal=to.every((v,i)=>v===f(c.goal[i]));
      if(c.mode==='all-clear')return 1;if(c.mode==='blocked')return 0;if(c.mode==='goal-area-blocked')return area&&goal?0:1;
      if(c.mode==='goal-tile-blocked')return !area&&strict===0?0:1;return goal||strict===0?0:1;
    };
    const p={tileLine:(_s,from,to,out,strict)=>{calls.push(['tile',from,to,strict]);out.low=f(-.1);out.high=f(.6);return response(from,to,strict);},
      areaLine:(_s,from,to,low,high)=>{calls.push(['area',from,to,low,high]);return response(from,to,1,true);}};
    const result=await intraTileSuccessors(state,c.point,c.triangle,p);
    assert.deepEqual({calls,rows:result,work:state.work,masks:state.edgeMasks},{calls:row.calls,rows:row.rows,work:row.work,masks:row.masks},JSON.stringify(c));
  }
});
