// Download public manifest outside the workspace; emit only derived metadata.
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import {readServerInfoAdvertisement} from '../src/server_discovery.js';
const discovery=JSON.parse(await fs.readFile(process.argv[2],'utf8')),ad=readServerInfoAdvertisement(Buffer.from(discovery.advertisementHex,'hex'));
const directory=path.resolve(os.tmpdir(),'..','NwnReplacementClient','ContentTests','manifest-'+crypto.randomUUID());await fs.mkdir(directory,{recursive:true});
const response=await fetch(new URL('manifests/'+ad.hash,ad.url+'/'),{signal:AbortSignal.timeout(60000)});if(!response.ok)throw new Error('HTTP '+response.status);const bytes=Buffer.from(await response.arrayBuffer());await fs.writeFile(path.join(directory,ad.hash),bytes);
const count=bytes.readUInt32LE(8),mappings=bytes.readUInt32LE(12),invalid=[];
for(let i=0;i<count+mappings;i++){const at=i<count?16+i*42+24:16+count*42+(i-count)*22+4,raw=bytes.subarray(at,at+16),end=raw.indexOf(0),name=raw.subarray(0,end<0?16:end).toString('latin1'),type=bytes.readUInt16LE(at+16);if(!name||/[\x00-\x20/\\:]/.test(name)||!type)invalid.push({i,name,type});}
const report={endpoint:discovery.endpoint,hash:ad.hash,sha1:crypto.createHash('sha1').update(bytes).digest('hex'),directory,bytes:bytes.length,version:bytes.readUInt32LE(4),count,mappings,expectedLength:16+count*42+mappings*22,invalidCount:invalid.length,invalid:invalid.slice(0,40)};await fs.writeFile(process.argv[3],JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
