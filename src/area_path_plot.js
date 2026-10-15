const f=Math.fround;
const i=(path,o)=>path.raw.getInt32(o,true),v=(path,o)=>path.raw.getFloat32(o,true),si=(path,o,n)=>path.raw.setInt32(o,n,true);
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native area path provider ${n} is unavailable`);return p[n];};
const clock=async p=>BigInt.asUintN(64,BigInt(await required(p,'microseconds')()));
const local=(point,tile)=>point.map((value,n)=>f(value-f(f(tile[n])*10)));

// CNWSArea::PlotPath14036fc70..140370e58 with profiling disabled.
// Keep shrinking physical tile/exit arrays, failed entry/exit exclusions,
// full-capacity retry storage and the native pending/success return contract.
export async function plotAreaPath(area,path,budget,p){
  await required(p,'markAI')(1);const began=await clock(p);area.nativePathInfo280=path;
  const start=[v(path,0x64),v(path,0x68)],goal=[v(path,0x4c),v(path,0x50)],width=area.nativeGeometry?.area.width??area.width,height=area.nativeGeometry?.area.height??area.height;
  const tileCoordinate=value=>{const divided=f(value/10);return divided>=-2147483648&&divided<2147483648?Math.trunc(divided)|0:-2147483648;};
  const startTile=start.map(tileCoordinate),goalTile=goal.map(tileCoordinate);
  const valid=tile=>tile.every((value,n)=>Number.isInteger(value)&&value>=0&&value<[width,height][n]);
  const fail=()=>{(p.resetInterTile??(path=>path.resetInterTile()))(path);return 3;};
  if(i(path,0x70)!==i(path,0x60))return fail();
  area.nativePathGoalTile26c=goalTile.slice();if(!valid(startTile)||!valid(goalTile))return fail();
  const startRegion=await required(p,'closestRegion')(area,...startTile,start),goalRegion=await p.closestRegion(area,...goalTile,goal);
  area.nativePathGoalRegion274=goalRegion;
  const threshold={value:Math.abs(goalTile[0]-startTile[0])+Math.abs(goalTile[1]-startTile[1])-2};
  const allocate=(bytes,value)=>{p.onAllocate?.(bytes,value);return value;},free=value=>p.onFree?.(value);
  const fullCapacity=()=>{const width=p.maximumWidth??32,height=p.maximumHeight??32;if(!Number.isInteger(width)||!Number.isInteger(height)||width<1||height<1)throw new Error('Native area route capacity is unavailable');return width*height*2;};
  const arrays=()=>{const tiles=path.allocations.get(0xe8),exits=path.allocations.get(0xf0),count=i(path,0xe0);if(!(tiles instanceof Int32Array)||!(exits instanceof Float32Array)||count<0||tiles.length<count*2||exits.length<count*2)throw new Error('Native area route storage is unavailable');return{tiles,exits,count};};
  const replace=(count,copy)=>{
    const tiles=allocate(count*4,new Int32Array(count)),exits=allocate(count*4,new Float32Array(count));
    if(copy){const old=arrays();tiles.set(old.tiles.subarray(0,old.count*2));exits.set(old.exits.subarray(0,old.count*2));}
    if(path.allocations.has(0xe8))free(path.allocations.get(0xe8));if(path.allocations.has(0xf0))free(path.allocations.get(0xf0));path.allocations.set(0xe8,tiles);path.allocations.set(0xf0,exits);
  };
  const generate=async()=>{
    area.nativePathGoalPoint278=goal.slice();return required(p,'generate')(area,path,threshold,[...startTile,startRegion],[...goalTile,goalRegion],goal);
  };
  let borrowed=i(path,0xe0)!==0;
  if(!borrowed&&i(path,0x78)===0){replace(fullCapacity(),false);si(path,0xe0,0);if(await generate()===0)return fail();}
  let elapsed=BigInt.asUintN(64,await clock(p)-began),progress=false;
  if(i(path,0xe0)<=0)return 1;
  let route=arrays(),tile=[route.tiles[0],route.tiles[1]],point=start.slice();
  const count=i(path,0x88),waypoints=path.allocations.get(0x90);
  if(count){if(!(waypoints instanceof Float32Array)||count%2||count<2||count>waypoints.length)throw new Error('Native area last waypoint is unavailable');point=[waypoints[count-2],waypoints[count-1]];}
  let from=local(point,tile),original=local(start,tile);
  while(i(path,0xe0)>0&&elapsed<BigInt.asUintN(64,BigInt(budget))){
    if(!valid(tile))throw new Error('Native area current route tile is unavailable');
    const remaining=Number(BigInt.asUintN(32,BigInt(budget)-elapsed));
    const result=await required(p,'tilePlot')(area,path,tile,from,original,remaining);
    if(result===2){
      progress=true;const points=path.allocations.get(0x90),length=i(path,0x88);
      if(!(points instanceof Float32Array)||length<2||length>points.length)throw new Error('Native area completed tile waypoint is unavailable');
      from=local([points[length-2],points[length-1]],tile);original=local(start,tile);route=arrays();
      if(route.count>1){
        const next=[route.tiles[2],route.tiles[3]];
        for(let n=0;n<2;n++){if(next[n]>tile[n])from[n]=0;else if(next[n]<tile[n])from[n]=10;}
        si(path,0xe0,route.count-1);route.tiles.copyWithin(0,2,route.count*2);route.exits.copyWithin(0,2,route.count*2);tile=[route.tiles[0],route.tiles[1]];
      }else{free(route.tiles);free(route.exits);path.allocations.delete(0xe8);path.allocations.delete(0xf0);si(path,0xe0,0);}
    }else if(result===3){
      const entry=await required(p,'exitNumber')(area,tile,from);route=arrays();
      const exit=route.count>1?await p.exitNumber(area,tile,[route.exits[0],route.exits[1]]):12,oldCount=i(path,0xcc),oldTiles=path.allocations.get(0xd0),oldExits=path.allocations.get(0xd8);
      if(oldCount<0||oldCount>0&&(!(oldTiles instanceof Int32Array)||!(oldExits instanceof Int32Array)||oldTiles.length<oldCount*2||oldExits.length<oldCount*2))throw new Error('Native area avoidance storage is unavailable');
      const avoidExits=allocate((oldCount*2+2)*4,new Int32Array(oldCount*2+2)),avoidTiles=allocate((oldCount*2+2)*4,new Int32Array(oldCount*2+2));
      if(oldCount){avoidExits.set(oldExits.subarray(0,oldCount*2));avoidTiles.set(oldTiles.subarray(0,oldCount*2));}
      si(path,0xcc,oldCount+1);avoidExits.set([entry,exit],oldCount*2);avoidTiles.set(tile,oldCount*2);
      if(oldExits)free(oldExits);if(oldTiles)free(oldTiles);path.allocations.set(0xd8,avoidExits);path.allocations.set(0xd0,avoidTiles);
      area.nativePathGoalPoint278=goal.slice();(p.resetWaypoints??(path=>path.resetWaypoints()))(path);threshold.value-=2;
      if(borrowed){replace(fullCapacity(),true);borrowed=false;}
      if(await generate()===0)return fail();route=arrays();tile=[route.tiles[0],route.tiles[1]];from=local(start,tile);original=from.slice();
    }
    elapsed=BigInt.asUintN(64,await clock(p)-began);
  }
  let result=2;
  if(i(path,0xe0)!==0){replace(i(path,0xe0)*2,true);result=1;}
  if(progress&&result===2)await required(p,'smooth')(area,path);
  return result;
}
