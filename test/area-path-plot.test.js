import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {PathInformation} from '../src/path_information.js';
import {plotAreaPath} from '../src/area_path_plot.js';
test('area plot matches original timer budget, route shrinking, failure exclusion, retry and completion',async()=>{
  const rows=JSON.parse(readFileSync(new URL('../backups/animations/native-area-plot-observations.json',import.meta.url))).rows;
  for(const row of rows){
    const c=row.case,path=new PathInformation(77),area={width:3,height:3},calls=[];let ticks=0,generations=0,plots=0,mark=0;
    path.raw.setInt32(0x60,100,true);path.raw.setInt32(0x70,c.startArea,true);path.raw.setInt32(0x78,c.complete,true);
    c.start.concat(c.goal).forEach((v,n)=>path.raw.setFloat32([0x64,0x68,0x4c,0x50][n],v,true));
    if(c.resume){path.raw.setInt32(0xe0,c.route.length/2,true);path.allocations.set(0xe8,new Int32Array(c.route));path.allocations.set(0xf0,new Float32Array(c.exits));}
    path.raw.setInt32(0x88,c.old.length,true);if(c.old.length)path.allocations.set(0x90,new Float32Array(c.old));
    path.raw.setInt32(0xcc,c.avoidTiles.length/2,true);if(c.avoidTiles.length){path.allocations.set(0xd0,new Int32Array(c.avoidTiles));path.allocations.set(0xd8,new Int32Array(c.avoidExits));}
    const read=(offset,count)=>[...(path.allocations.get(offset)?.slice(0,path.raw.getInt32(count,true)*2)??[])];
    const p={markAI:value=>{mark=value;},microseconds:()=>BigInt(1000+ticks++*c.tickStep),closestRegion:(_area,x,y,point)=>{calls.push(['region',[x,y],point]);return 0;},
      generate:(_area,path,threshold,start)=>{calls.push(['generate',threshold.value,...start,read(0xd0,0xcc),read(0xd8,0xcc)]);threshold.value+=2;
        path.raw.setInt32(0xe0,c.route.length/2,true);path.allocations.get(0xe8).set(c.route);path.allocations.get(0xf0).set(c.exits);return c.generate[Math.min(generations++,c.generate.length-1)];},
      tilePlot:(_area,path,tile,start,end,budget)=>{const response=c.results[Math.min(plots++,c.results.length-1)];calls.push(['tilePlot',tile.slice(),start.slice(),end.slice(),budget,response]);
        if(response===2){const to=path.raw.getInt32(0xe0,true)===1?c.goal:[tile[0]*10+path.allocations.get(0xf0)[0],tile[1]*10+path.allocations.get(0xf0)[1]];
          const old=path.allocations.get(0x90)??[],next=new Float32Array([...old,tile[0]*10+start[0],tile[1]*10+start[1],...to]);path.allocations.set(0x90,next);path.raw.setInt32(0x88,next.length,true);}return response;},
      exitNumber:(_area,tile,point)=>{calls.push(['exitNumber',tile.slice(),point.slice()]);return 5;},
      resetWaypoints:path=>{calls.push(['resetWaypoints']);path.resetWaypoints();},resetInterTile:path=>{calls.push(['resetInterTile']);path.resetInterTile();},
      smooth:(_area,path)=>{calls.push(['smooth']);path.allocations.set(0x80,path.allocations.get(0x90).slice());path.raw.setInt32(0x7c,path.raw.getInt32(0x88,true),true);}};
    const result=await plotAreaPath(area,path,c.budget,p);
    assert.deepEqual({result,calls,route:read(0xe8,0xe0),exits:read(0xf0,0xe0),avoidTiles:read(0xd0,0xcc),avoidExits:read(0xd8,0xcc),waypoints:[...(path.allocations.get(0x90)??[])],output:[...(path.allocations.get(0x80)??[])],mark},
      {result:row.result,calls:row.calls,route:row.route,exits:row.exits,avoidTiles:row.avoidTiles,avoidExits:row.avoidExits,waypoints:row.waypoints,output:row.output,mark:row.mark},JSON.stringify(c));
  }
});
