// Inspect only verified assets created by the current cold-download test.
// Never accesses an original NWN profile/install or fetches missing objects.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {NWSyncContent} from '../electron/nwsync_content.mjs';
import {parseNWSyncManifest} from '../src/nwsync_manifest.js';
import {parse2da} from '../src/area.js';
import {decodeResourceText} from '../src/resource_archive.js';
import {parseTalkTable} from '../src/talk_table.js';
const [input,output]=process.argv.slice(2),source=JSON.parse(await fs.readFile(input,'utf8'));
if(source.cache.initialEntries!==0||source.cache.reuseInstalledNWSync!==false)throw new Error('A fresh download test is required');
const content=new NWSyncContent({directory:source.cache.directory,nativeDirectory:null,fetch:()=>{throw new Error('Only this test\'s completed downloads may be read');}}),report={source:input,startedAt:new Date().toISOString(),cache:source.cache.directory,reads:[],pending:0,failures:[]};
const sha=bytes=>crypto.createHash('sha1').update(bytes).digest('hex');
try{
 for(const advertised of source.downloads.manifests){
  const bytes=await fs.readFile(path.join(source.cache.directory,'manifests',advertised.hash));if(sha(bytes)!==advertised.hash)throw new Error('Downloaded manifest hash mismatch');
  for(const entry of parseNWSyncManifest(bytes).entries){
   if(entry.type!==2017&&entry.type!==2018)continue;
   let stat;try{stat=await fs.stat(path.join(source.cache.directory,'objects',entry.hash));}catch(error){if(error.code!=='ENOENT')throw error;report.pending++;continue;}
   try{
    if(stat.mtimeMs<Date.parse(source.startedAt)-2000)throw new Error('Object predates this cold-download test');
    const bytes=await content.blob(entry,null);if(sha(bytes)!==entry.hash)throw new Error('Object hash mismatch');
    const row={name:entry.name,type:entry.type,sha1:entry.hash,bytes:bytes.length,downloadedThisTest:true};
    if(entry.type===2017){const table=parse2da(decodeResourceText(bytes));row.rows=table.orderedRows.length;row.columns=table.columns;}
    else{const table=parseTalkTable(bytes);row.strings=table.count;row.nonemptyStringsRead=0;for(let i=0;i<table.count;i++)if(table.get(i))row.nonemptyStringsRead++;}
    report.reads.push(row);
   }catch(error){report.failures.push({name:entry.name,type:entry.type,error:error.message});}
  }
 }
}finally{content.close();report.finishedAt=new Date().toISOString();await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');}
console.log(JSON.stringify({read:report.reads.length,pending:report.pending,failures:report.failures,core:report.reads.filter(row=>['classes','racialtypes','spells','feat','skills','baseitems'].includes(row.name))}));if(report.failures.length)process.exitCode=1;
