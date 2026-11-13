'use strict';
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const readline=require('node:readline');
const root=path.resolve(__dirname,'../..');
const staged=JSON.parse(fs.readFileSync(path.join(root,'.cache/nwn77/current-static-pair-a/staged.json')));
const capture=staged.capture;
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const timeline=path.join(capture,'timeline.jsonl');
const catalog=path.join(capture,'catalog-1');
const output=path.join(root,'.cache/nwn77/two-area-capture-a/areas.json');
async function main(){
 if(hash(path.join(capture,'recording.json'))!==staged.recordingSha256)throw Error('Recorded capture drift');
 const selected=new Map();
 const lines=readline.createInterface({input:fs.createReadStream(timeline)});
 for await(const line of lines){
  const row=JSON.parse(line),area=row.value?.data?.area;
  if(row.value?.kind!=='raw-world-begin'||!area||!['gs_enter','udcitydist1a'].includes(area.resRef)||selected.has(area.resRef))continue;
  selected.set(area.resRef,{sequence:row.sequence,generation:row.value.generation,area});
 }
 if(selected.size!==2)throw Error('Both saved original area begins are required');
 const result={version:1,sourceCapture:capture,recordingSha256:staged.recordingSha256,timelineSha256:hash(timeline),catalog,catalogManifestSha256:hash(path.join(catalog,'manifest.json')),areas:[selected.get('udcitydist1a'),selected.get('gs_enter'),selected.get('udcitydist1a')]};
 fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file:output,sha256:hash(output),areas:result.areas.map(x=>({resRef:x.area.resRef,sequence:x.sequence,generation:x.generation,tiles:x.area.tiles.length}))}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1});
