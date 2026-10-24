import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';import http from 'node:http';import {createHash} from 'node:crypto';import {deflateSync,zstdCompressSync} from 'node:zlib';
const sha=b=>createHash('sha1').update(b).digest('hex');
function blob(data,algorithm){const n=algorithm===0?16:algorithm===1?20:24,b=Buffer.alloc(n);b.write('NSYC');b.writeUInt32LE(3,4);b.writeUInt32LE(algorithm,8);b.writeUInt32LE(data.length,12);if(algorithm)b.writeUInt32LE(1,16);return Buffer.concat([b,algorithm===0?data:algorithm===1?deflateSync(data):zstdCompressSync(data)]);}
export async function nwsyncFixture({label='',extra=[]}={}){
 if(!['','A','B'].includes(label))throw Error('Invalid authored NWSync variant');
 const directory=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-godot-nwsync-')),cacheDirectory=path.join(directory,'cache'),files=new Map(),requests=[],entries=[];
 for(let i=0;i<12;i++){const data=Buffer.from('2DA V2.0\n\nVALUE\n0 GODOT_NWSYNC_'+(label?label+'_':'')+i+'\n'+'\n'.repeat(1024+i)),name='gd_sync_'+i;entries.push({name,type:2017,data,hash:sha(data),algorithm:i%3});}
 const pixel=label==='B'?[40,100,220,255]:[240,170,20,255];
 const image=Buffer.alloc(18+16*16*4);image[2]=2;image.writeUInt16LE(16,12);image.writeUInt16LE(16,14);image[16]=32;image[17]=0x28;for(let i=18;i<image.length;i+=4){image[i]=pixel[2];image[i+1]=pixel[1];image[i+2]=pixel[0];image[i+3]=pixel[3];}entries.push({name:'gd_sync_icon',type:3,data:image,hash:sha(image),algorithm:2});
 if(label){const data=Buffer.from('2DA V2.0\n\nVALUE\n0 ONLY_'+label+'\n');entries.push({name:'gd_only_'+label.toLowerCase(),type:2017,data,hash:sha(data),algorithm:0});}
 for(const e of extra){if(e.name!=='port_nui_jui'||e.type!==2083)throw Error('Unsupported authored fixture resource');const data=Buffer.from(e.data);entries.push({name:e.name,type:e.type,data,hash:sha(data),algorithm:1});}
 const manifest=Buffer.alloc(16+entries.length*42);manifest.write('NSYM');manifest.writeUInt32LE(3,4);manifest.writeUInt32LE(entries.length,8);
 for(const [i,e]of entries.entries()){const offset=16+i*42;Buffer.from(e.hash,'hex').copy(manifest,offset);manifest.writeUInt32LE(e.data.length,offset+20);manifest.write(e.name,offset+24,16,'ascii');manifest.writeUInt16LE(e.type,offset+40);files.set('/data/sha1/'+e.hash.slice(0,2)+'/'+e.hash.slice(2,4)+'/'+e.hash,blob(e.data,e.algorithm));}
 const hash=sha(manifest);files.set('/manifests/'+hash,manifest);files.set('/latest',Buffer.from(hash));
 let delay=180,failData=false;
 const server=http.createServer((req,res)=>{const bytes=files.get(req.url),status=bytes&&!(failData&&req.url.startsWith('/data/'))?200:404,row={at:Date.now(),url:req.url,status,complete:false};requests.push(row);res.on('finish',()=>{row.complete=true;row.completedAt=Date.now();});if(status!==200){res.writeHead(status);res.end();return;}const timer=setTimeout(()=>{res.writeHead(200,{'content-length':bytes.length});res.end(bytes);},req.url.startsWith('/data/')?delay:30);res.on('close',()=>{clearTimeout(timer);if(!row.complete)row.aborted=true;});});
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});
 const descriptor={version:1,label,pixel,url:'http://127.0.0.1:'+server.address().port+'/',hash,cacheDirectory,reuseInstalledNWSync:false,entries:entries.map(({data,...e})=>({...e,size:data.length})),scope:'Authored data only; raw/zlib/Zstandard loopback NWSync fixture'};
 const descriptorPath=path.join(directory,'fixture.json');await fs.writeFile(descriptorPath,JSON.stringify(descriptor,null,2)+'\n',{flag:'wx'});
 return{...descriptor,directory,descriptorPath,requests,setDelay(value){delay=value;},setFailure(value){failData=Boolean(value);},async corrupt(){await fs.writeFile(path.join(cacheDirectory,'objects',entries[0].hash),'corrupt authored cache fixture');},async close(){await new Promise(resolve=>server.close(resolve));},requestsSince(index){return requests.slice(index);}};
}
