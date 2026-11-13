import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {test} from 'node:test';
import {fileURLToPath} from 'node:url';

const extractor=fileURLToPath(new URL('./extract-native-lighting-stream.mjs',import.meta.url));
const observation={kind:'observed',nativeProcessId:1,areaId:7,generation:3,connection:2,area_lighting:{configured:true,ambient:{color:[.1,.2,.3]}}};
const line=(sequence,bytes)=>`1\t${sequence>>>0}\t${Buffer.from(bytes).toString('hex')}\n`;
async function extract(input,world=false){
 const directory=await fs.mkdtemp(path.join(os.tmpdir(),'native-lighting-stream-test-'));
 const output=path.join(directory,'lighting.json');
 try{
  const child=spawnSync(process.execPath,[extractor,output,...(world?['--world']:[])],{input,encoding:'utf8',windowsHide:true});
  return {status:child.status,value:JSON.parse(await fs.readFile(output,'utf8')),stdout:child.stdout};
 }finally{
  await fs.unlink(output).catch(error=>{if(error.code!=='ENOENT')throw error});
  await fs.rmdir(directory);
 }
}
test('reassembles split, reordered and retransmitted segments without losing lighting',async()=>{
 const bytes=Buffer.from(JSON.stringify(observation)+'\n');
 const result=await extract(line(100,bytes.subarray(0,17))+line(140,bytes.subarray(40))+line(117,bytes.subarray(17,40))+line(117,bytes.subarray(17,40)));
 assert.equal(result.status,0);assert.equal(result.value.complete_observations,1);
 assert.deepEqual(result.value.latest.lighting,observation.area_lighting);assert.equal(result.value.gaps,0);
});
test('sequence wrap preserves a complete observation',async()=>{
 const bytes=Buffer.from(JSON.stringify(observation)+'\n');
 const result=await extract(line(0xfffffff0,bytes.subarray(0,20))+line(4,bytes.subarray(20)));
 assert.equal(result.status,0);assert.equal(result.value.complete_observations,1);
});
test('a missing segment never fabricates an observation',async()=>{
 const bytes=Buffer.from(JSON.stringify(observation)+'\n');
 const result=await extract(line(100,bytes.subarray(0,20))+line(130,bytes.subarray(30)));
 assert.equal(result.status,1);assert.equal(result.value.success,false);assert.ok(result.value.gaps>0);
});
test('world inspection uses a whitelist and never retains objects or unrelated messages',async()=>{
 const world={kind:'raw-world-begin',generation:3,connection:2,data:{area:{id:7,resRef:'room',tileset:'tic01',fields:{dc:1},tiles:[{fields:{14:1},lightMask:238}],staticObjects:[{secret:'STATIC_MARKER'}],mapPins:[{name:'PIN_MARKER'}]},objects:[{secret:'OBJECT_MARKER'}],account:{secret:'ACCOUNT_MARKER'}}};
 const input=JSON.stringify(world)+'\n'+JSON.stringify({kind:'chat',text:'CHAT_MARKER'})+'\n';
 const result=await extract(line(100,input),true);
 assert.equal(result.status,0);assert.equal(result.value.worldLighting.tileCount,1);
 assert.deepEqual(Object.keys(result.value.worldLighting.area).sort(),['fields','id','resRef','tileset']);
 for(const marker of ['STATIC_MARKER','PIN_MARKER','OBJECT_MARKER','ACCOUNT_MARKER','CHAT_MARKER']){
  assert.ok(!JSON.stringify(result.value).includes(marker));assert.ok(!result.stdout.includes(marker));
 }
});
