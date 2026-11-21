import fs from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {NWSyncContent as CurrentContent} from '../electron/nwsync_content.mjs';
const [directory,hash,output,baseline]=process.argv.slice(2);let Content=CurrentContent;
if(baseline){let source=await fs.readFile(baseline,'utf8');for(const name of ['../src/nwsync_manifest.js','./nwsync_reader.mjs'])source=source.replace(`'${name}'`,JSON.stringify(new URL(name,new URL('../electron/nwsync_content.mjs',import.meta.url)).href));Content=(await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'))).NWSyncContent;}
const report={implementation:baseline?'sealed pre-inventory':'current',hash,httpAttempts:0,progress:[],demands:[]},owner=new Content({directory,fetch:()=>{report.httpAttempts++;throw Error('Offline benchmark may not fetch');},onProgress:p=>report.progress.push(p)});
try{const at=performance.now(),view=await owner.findManifest(hash);report.admissionMs=performance.now()-at;report.entries=view.entries.length;report.ready=owner.ready.size;
 for(const name of ['classes','feat']){const start=performance.now(),bytes=await view.getResource(name,2017);report.demands.push({name,bytes:bytes.byteLength,sha1:createHash('sha1').update(new Uint8Array(bytes)).digest('hex'),ms:performance.now()-start});}
 report.success=true;
}catch(error){report.failure=error.message;process.exitCode=1;}finally{owner.close();await fs.writeFile(output,JSON.stringify(report,null,2));console.log(JSON.stringify({...report,progress:report.progress.length}));}
