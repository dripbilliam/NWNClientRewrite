import {createInflate,inflateSync,constants} from 'node:zlib';
import {isNetworkBytes} from '../src/network_bytes.js';

// UncompressMessage255c80: bit2=compressed, bit0=persistent window stream,
// expected output DWORD LE at12, compressed bytes at16, maximum20MiB.
export class NetworkMessageInflater{
 #stream=null;#pending=null;#failed=false;#closed=false;
 async decode(record){
  if(this.#closed||this.#failed)throw new Error('Native message inflater is unavailable');
  if(!isNetworkBytes(record)||record.length<12)throw new Error('Invalid native message record');
  if(!(record[7]&4))return Uint8Array.from(record.subarray(12));
  if(record.length<16)throw new Error('Truncated native compressed message');
  const expected=new DataView(record.buffer,record.byteOffset+12,4).getUint32(0,true);
  if(expected>0x1400000)throw new Error('Invalid native decompressed message size');
  const source=record.subarray(16);
  if(!(record[7]&1)){
   try{const output=inflateSync(source,{maxOutputLength:Math.max(1,expected)});if(output.length>expected)throw new Error();return output;}
   catch{throw new Error('Native block message decompression failed');}
  }
  if(this.#pending)throw new Error('Concurrent native stream decompression is unavailable');
  if(!this.#stream){
   this.#stream=createInflate();this.#stream.on('error',()=>{this.#failed=true;this.#pending?.fail();});
  }
  return new Promise((resolve,reject)=>{
   const chunks=[];let size=0,settled=false;
   const finish=(failed=false)=>{
    if(settled)return;settled=true;this.#stream.removeListener('data',onData);this.#pending=null;
    if(failed||size!==expected){this.#failed=true;this.#stream.destroy();reject(new Error('Native stream message decompression failed'));}
    else resolve(Buffer.concat(chunks,size));
   };
   const onData=chunk=>{size+=chunk.length;if(size>expected){finish(true);return;}chunks.push(chunk);};
   this.#pending={fail:()=>finish(true)};this.#stream.on('data',onData);
   this.#stream.write(source,error=>{if(error){finish(true);return;}this.#stream.flush(constants.Z_SYNC_FLUSH,error=>finish(Boolean(error)));});
  });
 }
 close(){if(this.#closed)return;this.#closed=true;this.#pending?.fail();this.#stream?.destroy();}
}
