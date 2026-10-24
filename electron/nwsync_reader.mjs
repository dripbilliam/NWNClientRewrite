import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';

// A separate process keeps SQLite and decompression work off the renderer and
// Electron's event loop. All database opens in this helper are READONLY.
export class NWSyncReader{
 constructor(directory,{executable=fileURLToPath(new URL('../tooling/native/content-reader/nwn-content-reader.exe',import.meta.url))}={}){
  this.child=spawn(executable,[directory],{windowsHide:true,stdio:['pipe','pipe','ignore']});this.tail=Promise.resolve();this.closed=false;
  this.child.stdout.on('data',data=>this.receive(data));this.child.on('error',()=>this.fail());this.child.stdin.on('error',()=>this.fail());this.child.on('close',()=>this.fail());
 }
 fail(){this.closed=true;if(this.pending){clearTimeout(this.pending.timer);this.pending.reject(new Error('NWSync content reader is unavailable'));this.pending=null;}}
 receive(data){
  const p=this.pending;if(!p){this.close();return;}
  if(p.headerBytes<4){const count=Math.min(4-p.headerBytes,data.length);data.copy(p.header,p.headerBytes,0,count);p.headerBytes+=count;data=data.subarray(count);if(p.headerBytes===4){p.length=p.header.readUInt32LE();if(!p.length||p.length>256*1024*1024+1){this.close();return;}}}
  if(data.length){p.chunks.push(data);p.bytes+=data.length;}
  if(p.length!==undefined&&p.bytes>=p.length){
   if(p.bytes!==p.length){this.close();return;}this.pending=null;clearTimeout(p.timer);const value=Buffer.concat(p.chunks,p.bytes),status=value[0];
   if(status===1)p.resolve(null);else if(status!==0)p.reject(new Error('NWSync content reader rejected the data'));else p.resolve(value.subarray(1));
  }
 }
 request(operation,payload){
  const run=this.tail.then(()=>{
   if(this.closed)throw new Error('NWSync content reader is closed');if(payload.length+1>256*1024*1024)throw new Error('NWSync reader request exceeds the supported size');
   return new Promise((resolve,reject)=>{const header=Buffer.alloc(5);header.writeUInt32LE(payload.length+1);header[4]=operation;this.pending={resolve,reject,header:Buffer.alloc(4),headerBytes:0,chunks:[],bytes:0,timer:setTimeout(()=>this.close(),30000)};this.child.stdin.write(header);this.child.stdin.write(payload);});
  });this.tail=run.catch(()=>{});return run;
 }
 async manifest(hash){
  const bytes=await this.request(1,Buffer.from(hash,'ascii'));if(bytes===null)return null;if(bytes.length<4)throw new Error('Invalid installed NWSync catalog');const count=bytes.readUInt32LE();
  if(!count||count>1_000_000||bytes.length!==4+count*58)throw new Error('Invalid installed NWSync catalog');
  const entries=[];for(let i=0;i<count;i++){const offset=4+i*58,raw=bytes.subarray(offset,offset+16),end=raw.indexOf(0),name=raw.subarray(0,end<0?16:end).toString('latin1').toLowerCase(),type=bytes.readUInt16LE(offset+16),hash=bytes.subarray(offset+18,offset+58).toString('ascii');if(!name||/[\x00-\x1f/\\:]/.test(name)||!type||!/^[0-9a-f]{40}$/.test(hash))throw new Error('Invalid installed NWSync catalog entry');entries.push({name,type,hash,size:null});}
  const catalog=new Map(entries.map(entry=>[`${entry.name}:${entry.type}`,entry]));if(catalog.size!==entries.length)throw new Error('Duplicate installed NWSync catalog entry');return{entries,catalog};
 }
 blob(hash){return this.request(2,Buffer.from(hash,'ascii'));}
 async inventory(){const bytes=await this.request(4,Buffer.alloc(0));if(bytes===null)return new Set();if(bytes.length<4||bytes.readUInt32LE()>1_000_000||bytes.length!==4+bytes.readUInt32LE()*40)throw new Error('Invalid installed NWSync resource inventory');const hashes=new Set();for(let offset=4;offset<bytes.length;offset+=40){const hash=bytes.subarray(offset,offset+40).toString('ascii');if(!/^[0-9a-f]{40}$/.test(hash))throw new Error('Invalid installed NWSync inventory hash');hashes.add(hash);}return hashes;}
 decompress(bytes,expected){const header=Buffer.alloc(4);header.writeUInt32LE(expected);return this.request(3,Buffer.concat([header,bytes]));}
 close(){if(this.closing)return;this.closing=true;this.fail();this.child.stdin.end();const timer=setTimeout(()=>this.child.kill(),500);timer.unref();this.child.once('close',()=>clearTimeout(timer));}
}
