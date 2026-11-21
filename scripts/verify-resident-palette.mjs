// Read installed resources in place. Persist only names, hashes and counters.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {Worker} from 'node:worker_threads';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {openServerResourceContext} from '../electron/server_resource_context.mjs';
import {RESOURCE_TYPE} from '../src/resource_archive.js';
import {parseNativeTga} from '../src/native_tga.js';
import {PLT_PALETTE_NAMES,decodeBioWarePlt} from '../src/bioware_plt.js';
import {ResourceWorkerPool} from '../src/resource_worker_pool.js';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const resolver=await openServerResourceContext({install:path.resolve(root,'../FullDecomp/NwnRootInstall')}),images=new Map();
for(const name of new Set(PLT_PALETTE_NAMES)){const image=parseNativeTga(await resolver.getResource(name,RESOURCE_TYPE.TGA));images.set(name,{width:image.width,height:image.height,data:image.data});}
const sourceHash=()=>[...images].map(([name,image])=>({name,width:image.width,height:image.height,sha256:sha(image.data)})),before=sourceHash(),all=[...resolver.key.resources.keys()].filter(key=>key.endsWith(':6')).map(key=>key.slice(0,-2)).sort(),names=[...new Set(Array.from({length:32},(_,i)=>all[Math.floor(i*all.length/32)]))];assert.ok(names.length>=16);
const createWorker=()=>{const worker=new Worker(new URL('./resource-worker-thread-fixture.mjs',import.meta.url));return{postMessage:(...args)=>worker.postMessage(...args),terminate:()=>worker.terminate(),addEventListener(kind,fn){worker.on(kind,value=>fn(kind==='message'?{data:value}:{message:value.message,preventDefault(){}}));}};},pool=new ResourceWorkerPool({size:4,createWorker}),cases=[];
try{for(const name of names){const input=await resolver.getResource(name,RESOURCE_TYPE.PLT),inputHash=sha(new Uint8Array(input)),profiles=[0,1,32,99,255,256,-5,1000].map(row=>Array.from({length:10},(_,layer)=>row+layer)),results=await Promise.all(profiles.map(rows=>pool.decodePlt(input,images,rows)));
 for(let i=0;i<profiles.length;i++){const expected=decodeBioWarePlt(input,images,profiles[i]);assert.deepEqual(results[i],expected);cases.push({name,rows:profiles[i],width:expected.width,height:expected.height,sha256:sha(expected.data)});}assert.equal(sha(new Uint8Array(input)),inputHash);
}assert.deepEqual(sourceHash(),before);assert.equal(pool.snapshot().failed,0);assert.equal(pool.snapshot().paletteMessages,4);assert.equal(pool.snapshot().paletteReuses,cases.length-4);
}finally{pool.dispose();}
const sourceHashes={};for(const file of ['src/resource_worker_pool.js','src/resource_worker_tasks.js','src/resource_worker.js','scripts/resource-worker-thread-fixture.mjs','scripts/verify-resident-palette.mjs'])sourceHashes[file]=sha(await fs.readFile(path.join(root,file)));
const report={success:true,scope:'Installed resources read in place, no connections; resident real worker-thread decoding compared byte-for-byte to the existing ordinary decoder',sourceHashes,palettes:before,cases,retired:pool.snapshot(),limits:['Pixel parity against the replacement decoder, not a new native-decoder oracle.','Native multiplayer timing and GPU rendering are separate checks.']};await fs.writeFile(path.join(root,'backups/animations/resident-palette-installed-v1.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({success:true,cases:cases.length,stats:report.retired}));
