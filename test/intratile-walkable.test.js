import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {PathInformation} from '../src/path_information.js';
import {intraTileWalkable,intraAreaWalkable} from '../src/intratile_walkable.js';
test('intra-tile walkable wrappers match native padded heights, endpoint tolerance, rotation, flags and short-circuit order',async()=>{
  const rows=JSON.parse(readFileSync(new URL('../backups/animations/native-intra-walkable-observations.json',import.meta.url))).rows,f=Math.fround;
  for(const row of rows){const c=row.case,calls=[],tile={x:c.x,y:c.y,orientation:c.orientation,heightOffset:c.elevation},path=new PathInformation(77),out={low:0,high:0};
    path.raw.setFloat32(4,c.radius,true);path.raw.setFloat32(0xc,c.height,true);path.raw.setUint32(0xc8,0x80000001,true);
    const p={clipped:(_tile,from,to)=>{calls.push(['clipped',from,to]);return{status:c.clipResult,entry:from,exit:[f(to[0]+c.delta),to[1]],minHeight:f(c.low),maxHeight:f(c.high)};},
      noDenied:(_tile,...args)=>{calls.push(['denied',...args]);return c.denied;},noNonWalk:(_area,...args)=>{calls.push(['objects',...args,0,false,0]);return c.objects;},
      noCreatures:(_area,from,to,_path,segment,bump,output,overlap)=>{calls.push(['creatures',from,to,segment,bump,Boolean(output),overlap]);return c.creatures;}};
    const result=c.mode==='tile'?await intraTileWalkable(tile,path,c.from,c.to,out,c.strict,p):await intraAreaWalkable({},tile,path,c.from,c.to,c.low,c.high,p);
    assert.deepEqual({result,calls,low:out.low,high:out.high},{result:row.result,calls:row.calls,low:row.low,high:row.high},JSON.stringify(c));
  }
});
