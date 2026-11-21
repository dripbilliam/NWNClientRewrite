// Mount only this user-requested cold download as the server's active context.
// Installed KEY catalogs remain ordinary base fallbacks; every demanded server
// resource must hash-match the newly downloaded manifest, never a stock table.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {NWSyncReader} from '../electron/nwsync_reader.mjs';
import {resolveServerResources} from '../src/network_resources.js';
import {parseNWSyncManifest} from '../src/nwsync_manifest.js';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {parse2da} from '../src/area.js';
import {parseTalkTable} from '../src/talk_table.js';
import {decodeResourceText} from '../src/resource_archive.js';
const [downloadFile,advertisementFile,install,output]=process.argv.slice(2),download=JSON.parse(await fs.readFile(downloadFile,'utf8')),auth=JSON.parse(await fs.readFile(advertisementFile,'utf8'));
assert.equal(download.success,true);assert.equal(download.cache.initialEntries,0);assert.equal(download.cache.reuseInstalledNWSync,false);assert.equal(auth.loginAccepted,true);assert.equal(auth.requirements.advertisement.hash,download.advertisement.hash);
const sha=bytes=>crypto.createHash('sha1').update(Buffer.from(bytes)).digest('hex'),raw=await fs.readFile(path.join(download.cache.directory,'manifests',download.advertisement.hash));assert.equal(sha(raw),download.advertisement.hash);const catalog=parseNWSyncManifest(raw).catalog;
const report={startedAt:new Date().toISOString(),sourceDownload:downloadFile,manifest:download.advertisement.hash,reads:[],diagnostics:[],httpAttempts:0,nativeCacheReadAttempts:0};
const resources=installedNetworkResources({install,cacheDirectory:download.cache.directory,reuseInstalledNWSync:false,onDiagnostic:d=>report.diagnostics.push(d),contentOptions:{fetch:()=>{report.httpAttempts++;throw new Error('Fresh download must already contain the advertised resource');},readerFactory:directory=>{const reader=new NWSyncReader(directory);for(const method of ['manifest','inventory','blob'])reader[method]=()=>{report.nativeCacheReadAttempts++;throw new Error('Original cache reuse is forbidden');};return reader;}}});
try{
 const result=await resolveServerResources(auth.requirements,{...resources,language:0,onDiagnostic:d=>report.diagnostics.push(d)});assert.equal(result.ready,true);report.resourcesReady=true;
 const resolver=await resources.openModule(null,result.resolved),rules=await loadNetworkObjectRules(resolver);
 for(const name of ['classes','racialtypes','skills','spells','feat','baseitems']){
  const entry=catalog.get(`${name}:2017`);assert.ok(entry);const bytes=await resolver.getResource(name,2017);assert.equal(sha(bytes),entry.hash);const table=parse2da(decodeResourceText(bytes));report.reads.push({name,rows:table.orderedRows.length,sha1:entry.hash,source:'freshly downloaded server manifest'});if(name==='skills')assert.equal(rules.skillCount,table.orderedRows.length&255);
 }
 const name=auth.requirements.customTlk,entry=catalog.get(`${name}:2018`);assert.ok(entry);const bytes=await resolver.getResource(name,2018);assert.equal(sha(bytes),entry.hash);const table=parseTalkTable(bytes);let index=0;while(index<table.count&&!table.get(index))index++;assert.ok(index<table.count);const selected=await resources.talkString((0x01000000|index)>>>0,0,result.resolved,d=>report.diagnostics.push(d));assert.equal(selected.text,table.get(index));report.customTlk={name,sha1:entry.hash,strings:table.count,checkedStringRef:(0x01000000|index)>>>0,checkedTextLength:selected.text.length};
 for(const [name,type]of [['pfh0_bicepl062 ',2002],['vs_okku_hide ',4]]){const entry=catalog.get(`${name}:${type}`);assert.ok(entry);const bytes=await resolver.getResource(name,type);assert.equal(sha(bytes),entry.hash);report.reads.push({name,type,sha1:entry.hash,bytes:bytes.byteLength,preservedTrailingSpace:true});}
 assert.equal(report.httpAttempts,0);assert.equal(report.nativeCacheReadAttempts,0);assert.equal(report.diagnostics.length,0);report.success=true;
}catch(error){report.failure=error.message;process.exitCode=1;}
finally{resources.close();report.finishedAt=new Date().toISOString();await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));}
