import test from 'node:test';import assert from 'node:assert/strict';import {PerspectiveCamera,OrthographicCamera,Vector3} from 'three';import {buildPointLightGrid,pointGridIndices,POINT_GRID_FALLBACK} from '../src/point_light_grid.js';
const options=c=>({width:1424,height:921,projection:c.projectionMatrix.elements,near:c.near,perspective:c.isPerspectiveCamera===true});
test('finite point lights cover every sampled reachable fragment and preserve original index order',()=>{
 const camera=new PerspectiveCamera(58,1424/921,.1,200),lights=Array.from({length:60},(_,i)=>({position:[Math.sin(i*8.7)*30,Math.cos(i*2.31)*20,-2-i*1.7],radius:1+i%12,decay:2})),grid=buildPointLightGrid({...options(camera),lights,firstShadow:6});
 for(let i=0;i<8000;i++){
  const p=new Vector3(Math.sin(i*1.47)*30,Math.cos(i*3.13)*20,-1-i%170),clip=p.clone().applyMatrix4(camera.projectionMatrix),x=(clip.x+1)*712,y=(clip.y+1)*460.5;if(x<0||x>=1424||y<0||y>=921)continue;const indices=pointGridIndices(grid,x,y);if(indices===null)continue;assert.deepEqual(indices,indices.slice().sort((a,b)=>a-b));assert.ok(indices.every(n=>n>=6));
  for(let index=6;index<lights.length;index++)if(p.distanceTo(new Vector3(...lights[index].position))<=lights[index].radius)assert.ok(indices.includes(index),'reachable light '+index+' at '+i);
 }
 assert.ok(grid.averageLights<lights.length-6);assert.equal(grid.fallbackCells,0);
});
test('unknown/infinite lights remain in every cell while only tagged neutral padding can use a local neighborhood',()=>{
 const camera=new PerspectiveCamera(60,1,.1,100),lights=[{position:[0,0,-5],radius:0},{position:[NaN,1,-3],radius:2},{position:[2,0,-5],radius:Infinity},{position:[0,0,-5],radius:0,neutral:true},{position:[0,0,5],radius:1}],grid=buildPointLightGrid({...options(camera),lights});
 for(let y=0;y<921;y+=96)for(let x=0;x<1424;x+=96){const indices=pointGridIndices(grid,x,y);assert.ok([0,1,2].every(i=>indices.includes(i)));assert.ok(!indices.includes(4));}
 const center=pointGridIndices(grid,712,460);assert.ok(center.includes(3));assert.ok(!pointGridIndices(grid,1,1).includes(3));
});
test('cell overflow uses the entire original tail instead of truncating membership',()=>{
 const camera=new PerspectiveCamera(60,1,.1,100),lights=Array.from({length:20},()=>({position:[0,0,-1],radius:0})),grid=buildPointLightGrid({...options(camera),width:192,height:192,lights,data:new Uint32Array(12)});assert.equal(grid.enabled,true);assert.equal(grid.fallbackCells,4);assert.ok([1,97].every(x=>[1,97].every(y=>pointGridIndices(grid,x,y)===null)));assert.equal(grid.data[1],POINT_GRID_FALLBACK);
 const disabled=buildPointLightGrid({...options(camera),lights,data:new Uint32Array(4)});assert.equal(disabled.enabled,false);assert.equal(pointGridIndices(disabled,1,1),null);
});
test('orthographic projection, near-plane intersections and reused storage retain conservative membership',()=>{
 const camera=new OrthographicCamera(-20,20,12,-12,.1,100),lights=[{position:[0,0,-.2],radius:2},{position:[15,8,-10],radius:3}],a=buildPointLightGrid({...options(camera),lights});
 const b=buildPointLightGrid({...options(camera),lights,data:a.data,bits:a.bits});assert.deepEqual(a.data,b.data);assert.equal(a.bits,b.bits);
 for(const p of [[0,0,-.15],[15,8,-10],[17,8,-10]]){const clip=new Vector3(...p).applyMatrix4(camera.projectionMatrix),indices=pointGridIndices(b,(clip.x+1)*712,(clip.y+1)*460.5);assert.ok(indices.includes(p[0]===0?0:1));}
});
test('native negative-decay attenuation remains present beyond a positive nominal radius',()=>{
 const camera=new PerspectiveCamera(60,1,.1,100),lights=[{position:[50,0,-5],radius:1,decay:-4.5},{position:[0,0,-5],radius:-2,decay:-1}],grid=buildPointLightGrid({...options(camera),lights});
 for(let y=0;y<921;y+=96)for(let x=0;x<1424;x+=96)assert.deepEqual(pointGridIndices(grid,x,y),[0,1]);
});
test('identical native membership shares one lookup list without changing any cell',()=>{
 const camera=new PerspectiveCamera(60,1,.1,100),lights=Array.from({length:45},(_,i)=>({position:[i,0,-5],radius:1,decay:-4.5})),grid=buildPointLightGrid({...options(camera),lights,data:new Uint32Array(400)});assert.equal(grid.enabled,true);assert.equal(grid.fallbackCells,0);assert.equal(grid.uniqueLists,1);assert.equal(grid.usedWords,grid.cols*grid.rows*2+45);for(let y=0;y<921;y+=96)for(let x=0;x<1424;x+=96)assert.deepEqual(pointGridIndices(grid,x,y),lights.map((_,i)=>i));
});
