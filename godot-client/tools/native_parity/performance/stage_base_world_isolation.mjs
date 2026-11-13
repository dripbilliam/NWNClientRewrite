// Source-only composition of one reviewed isolation row. Never launches/builds.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';

const self=fileURLToPath(import.meta.url),project=path.resolve(path.dirname(self),'../../..');
const parity=path.join(project,'.cache/native-presentation-parity');
const [rowId,label,...extra]=process.argv.slice(2);
assert.ok(!extra.length&&/^[a-z0-9-]+$/.test(rowId??'')&&/^base-world-isolation-[a-z0-9-]+$/.test(label??''),'Explicit row and fresh isolation label required');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const read=(file,expected)=>{const bytes=fs.readFileSync(file);assert.equal(sha(bytes),expected,'Changed pinned input: '+file);return bytes;};
const matrixFile=path.join(parity,'base-world-scheduler-review-agent/isolation-matrix.json');
const matrixBytes=fs.readFileSync(matrixFile),matrix=JSON.parse(matrixBytes);
assert.equal(matrix.kind,'source-only-isolation-patch-matrix');
const row=matrix.rows.find(value=>value.id===rowId);assert.ok(row,'Unknown reviewed row');
assert.ok(['7d6111133aecd9dcebf9f10b1f5e9705c6174f061b776b817b92c298a8c2b8ab','92c8c6591d252b480d8afa3297aedcc68fbec1c5d6d997cc5a4869df13a5a504'].includes(row.baseManifestSha256),'Unreviewed base manifest');
const base=JSON.parse(read(row.baseManifest,row.baseManifestSha256));
const safe=relative=>typeof relative==='string'&&relative.split('/').every(part=>part&&part!=='.'&&part!=='..')&&!relative.includes('\\')&&!relative.includes(':');
const originals=new Map();
for(const pin of base.pins){assert.ok(safe(pin.relative));assert.ok(!originals.has(pin.relative));originals.set(pin.relative,read(path.join(base.project,pin.relative),pin.sha256));}

function applyPatch(before,patch){
 const input=before?before.slice(0,-1).split('\n'):[],lines=patch.slice(0,-1).split('\n'),out=[];
 assert.ok((!before||before.endsWith('\n'))&&!before.includes('\r')&&patch.endsWith('\n'));
 let cursor=0;
 for(let at=2;at<lines.length;){
  const header=/^@@ -(\d+),(\d+) \+(\d+),(\d+) @@$/.exec(lines[at++]);assert.ok(header,'Invalid patch hunk');
  const count=Number(header[2]),start=Number(header[1])-(count?1:0);assert.ok(start>=cursor&&start<=input.length);
  out.push(...input.slice(cursor,start));cursor=start;
  let consumed=0,emitted=0;
  while(at<lines.length&&!lines[at].startsWith('@@ ')){
   const line=lines[at++],kind=line[0],value=line.slice(1);assert.ok([' ','+','-'].includes(kind));
   if(kind!=='+'){assert.equal(input[cursor++],value,'Patch source context differs');consumed++;}
   if(kind!=='-'){out.push(value);emitted++;}
  }
  assert.equal(consumed,count);assert.equal(emitted,Number(header[4]));
 }
 out.push(...input.slice(cursor));return out.length?out.join('\n')+'\n':'';
}

const changed=new Map();
for(const change of row.changes){
 assert.ok(safe(change.relative)&&!changed.has(change.relative));
 const before=originals.get(change.relative);
 if(change.mustBeAbsent){assert.equal(before,undefined);assert.ok(!fs.existsSync(path.join(base.project,change.relative)));}
 else assert.equal(sha(before),change.beforeSha256);
 const patch=read(change.patchFile,change.patchSha256).toString('utf8');
 const after=Buffer.from(applyPatch(before?.toString('utf8')??'',patch));assert.equal(sha(after),change.afterSha256);
 changed.set(change.relative,after);
}
const folder=path.join(parity,'root',label),target=path.join(folder,'project');
assert.ok(!fs.existsSync(folder),'Existing isolation capsule retained; choose fresh label');
const preferences=fs.readFileSync(base.settings.file);
fs.mkdirSync(target,{recursive:true});
const pins=[];
for(const [relative,bytes] of new Map([...originals,...changed])){
 const file=path.join(target,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes,{flag:'wx'});
 const hash=sha(bytes);assert.equal(sha(fs.readFileSync(file)),hash);
 pins.push({...base.pins.find(pin=>pin.relative===relative),relative,sha256:hash,bytes:bytes.length,overlay:changed.has(relative)});
}
const preferencesFile=path.join(folder,'render-preferences.cfg');fs.writeFileSync(preferencesFile,preferences,{flag:'wx'});
for(const pin of base.pins)read(path.join(base.project,pin.relative),pin.sha256);
assert.equal(sha(fs.readFileSync(matrixFile)),sha(matrixBytes));assert.equal(sha(fs.readFileSync(base.settings.file)),sha(preferences));
const manifest={...base,label,created:new Date().toISOString(),project:target,pins,base:{file:row.baseManifest,sha256:row.baseManifestSha256},
 settings:{...base.settings,file:preferencesFile,initialSha256:sha(preferences)},
 isolation:{row:rowId,matrix:{file:matrixFile,sha256:sha(matrixBytes)},question:row.question,consequence:row.consequence,changes:row.changes},
 builder:{file:self,sha256:sha(fs.readFileSync(self))},validationState:'staged-not-validated',releaseReady:false,launchState:'unlaunched',performanceAccepted:false,engineStarts:0,nativeBuilds:0,serverConnections:0};
const file=path.join(folder,'manifest.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({staged:true,launched:false,file,sha256:sha(fs.readFileSync(file)),changes:row.changes.map(value=>value.relative)}));
