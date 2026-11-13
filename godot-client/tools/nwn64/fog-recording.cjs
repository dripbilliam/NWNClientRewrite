'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../..'),label=process.argv[2];assert(/^fog-recording-[a-z0-9-]+$/.test(label||''));
const source=path.join(project,'.cache/loading-benchmark-worlds/arelith-archive-shaders-v1'),output=path.join(project,'.cache/nwn64',label);assert(!fs.existsSync(output));
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
async function fileHash(file){const h=crypto.createHash('sha256');for await(const bytes of fs.createReadStream(file))h.update(bytes);return h.digest('hex');}
(async()=>{
 const originalManifest=fs.readFileSync(path.join(source,'recording.json')),manifest=JSON.parse(originalManifest),original=fs.readFileSync(path.join(source,'timeline.jsonl'));assert.equal(hash(original),manifest.timelineSha256);
 const lines=original.toString().split('\n'),changed=[];let views=0;
 const updated=lines.map(line=>{
  if(!line)return line;const row=JSON.parse(line);if(row.kind!=='view')return line;
  views++;if(row.value.particles===true)return line;const next=structuredClone(row);next.value.particles=true;
  const proof=structuredClone(next);if(Object.hasOwn(row.value,'particles'))proof.value.particles=row.value.particles;else delete proof.value.particles;
  assert.deepEqual(proof,row,'Only view.particles may change');changed.push({sequence:row.sequence,at:row.at,before:row.value.particles??null,after:true});return JSON.stringify(next);
 }).join('\n');
 assert(views>0&&changed.length>0);const timeline=Buffer.from(updated);fs.mkdirSync(output,{recursive:true});fs.writeFileSync(path.join(output,'timeline.jsonl'),timeline,{flag:'wx'});
 const catalogPins=[];
 for(const catalog of manifest.catalogs){assert(/^catalog-\d+$/.test(catalog.directory));assert.equal(await fileHash(path.join(source,catalog.directory,'manifest.json')),catalog.sha256);
  async function walk(relative){for(const entry of fs.readdirSync(path.join(source,relative),{withFileTypes:true})){const name=path.posix.join(relative,entry.name);assert(!entry.isSymbolicLink());if(entry.isDirectory())await walk(name);else{const from=path.join(source,name),to=path.join(output,name);fs.mkdirSync(path.dirname(to),{recursive:true});fs.linkSync(from,to);const a=fs.statSync(from),b=fs.statSync(to);assert(a.ino===b.ino&&a.dev===b.dev&&a.size===b.size);catalogPins.push({relative:name,bytes:a.size,sha256:await fileHash(from),kind:'immutable original catalog hardlink'});}}}
  await walk(catalog.directory);
 }
 const next={...manifest,bytes:timeline.length,timelineSha256:hash(timeline)};fs.writeFileSync(path.join(output,'recording.json'),JSON.stringify(next,null,2)+'\n',{flag:'wx'});
 const provenance={issue:'NWN-64',source,sourceManifestSHA256:hash(originalManifest),sourceTimelineSHA256:hash(original),timelineSHA256:hash(timeline),events:manifest.events,views,changedViews:changed,catalogPins,mutation:'Only each view.value.particles is set to true. All other timeline rows remain byte-exact; all other view fields deep-equal; ordering/clock/collision/camera/resources unchanged.',scope:'Recorded original assets, immutable catalog hardlinks, no credentials/new assets or public connection; before/after replay must use this exact same derived capture.'};
 fs.writeFileSync(path.join(output,'fog-provenance.json'),JSON.stringify(provenance,null,2)+'\n',{flag:'wx'});assert.equal(hash(fs.readFileSync(path.join(source,'timeline.jsonl'))),manifest.timelineSha256);
 console.log(JSON.stringify({output,timelineSHA256:hash(timeline),views,changed:changed.length,catalogPins:catalogPins.length,provenanceSHA256:await fileHash(path.join(output,'fog-provenance.json'))}));
})().catch(error=>{console.error(error.stack);process.exitCode=1;});
