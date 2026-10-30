import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
// Raw protocol/local BIC transport only. No GFF/rules/UI interpretation.
export class NativeCharacterPreviewStore {
 constructor(directory){this.directory=path.resolve(directory);this.files=new Map();this.work=Promise.resolve();this.closed=false;this.stats={written:0,reused:0,removed:0,bytes:0};}
 async open(){await fs.mkdir(path.dirname(this.directory),{recursive:true});await fs.mkdir(this.directory);return this;}
 encode(input){
  if(this.closed||!(input instanceof Uint8Array)||input.length<56||input.length>948*65535-16)throw Error('Native character preview bytes are unavailable');
  const bytes=Uint8Array.from(input);
  const operation=this.work.then(async()=>{
   if(this.closed)throw Error('Native character preview storage is closed');
   const sha256=createHash('sha256').update(bytes).digest('hex'),file=path.join(this.directory,sha256+'.bic');
   if(this.files.has(sha256)){const actual=await fs.readFile(file);if(actual.length!==bytes.length||createHash('sha256').update(actual).digest('hex')!==sha256)throw Error('Native character preview storage changed');this.stats.reused++;}
   else{await fs.writeFile(file,bytes,{flag:'wx',mode:0o600});this.files.set(sha256,file);this.stats.written++;this.stats.bytes+=bytes.length;}
   // Keep the newest eight byte sources. A native decoder opens its source at
   // dispatch; there is only one active task and one latest pending selection.
   for(const [digest,old]of this.files){if(this.files.size<=8)break;if(digest===sha256)continue;await this.remove(old);this.files.delete(digest);}
   return{format:'native-bic-file-v1',path:file,sha256,bytes:bytes.length};
  }).finally(()=>bytes.fill(0));
  this.work=operation.catch(()=>{});return operation;
 }
 async remove(file){if(path.dirname(file)!==this.directory||!/^[a-f0-9]{64}\.bic$/.test(path.basename(file)))throw Error('Native character preview ownership differs');await fs.unlink(file);this.stats.removed++;}
 snapshot(){return{...this.stats,files:this.files.size,closed:this.closed,nativeProjection:true};}
 async close(){if(this.closed)return;this.closed=true;await this.work;for(const file of this.files.values())await this.remove(file);this.files.clear();await fs.rmdir(this.directory);}
}
