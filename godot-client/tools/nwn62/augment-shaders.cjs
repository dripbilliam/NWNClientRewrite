'use strict';
// Explicitly derived original-resource fixture; never edits its parent capture.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'../..');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const check=(ok,message)=>{if(!ok)throw Error(message);};
function fileHash(file){const hash=crypto.createHash('sha256'),fd=fs.openSync(file,'r'),buffer=Buffer.alloc(1024*1024);try{for(let at=0;;){const count=fs.readSync(fd,buffer,0,buffer.length,at);if(!count)break;hash.update(buffer.subarray(0,count));at+=count;}}finally{fs.closeSync(fd);}return hash.digest('hex');}
function seal(destination,expectedProposal){
 const proposalFile=path.join(project,'.cache/nwn62/shader-augmentation-proposal.json'),rawProposal=fs.readFileSync(proposalFile),proposal=JSON.parse(rawProposal);
 check(/^[a-f0-9]{64}$/.test(expectedProposal)&&sha(rawProposal)===expectedProposal,'Approved proposal changed');
 const destinationRoot=path.join(project,'.cache/loading-benchmark-worlds');destination=path.resolve(destinationRoot,destination);
 check(path.dirname(destination)===destinationRoot&&!fs.existsSync(destination),'Fresh owned direct fixture directory required');
 const base=proposal.base.directory,recordingFile=path.join(base,'recording.json'),rawRecording=fs.readFileSync(recordingFile),recording=JSON.parse(rawRecording),catalogFile=path.join(base,'catalog-1/manifest.json'),rawCatalog=fs.readFileSync(catalogFile),catalog=JSON.parse(rawCatalog);
 check(sha(rawRecording)===proposal.base.recordingSHA256&&sha(rawCatalog)===proposal.base.catalogManifestSHA256,'Original recording/catalog changed');
 check(recording.complete===true&&recording.catalogs.length===1&&recording.catalogs[0].directory==='catalog-1'&&recording.catalogs[0].sha256===sha(rawCatalog),'Original recording catalog seal differs');
 check(catalog.complete===true&&catalog.packedSource?.version===1,'Expected sealed native packed catalog');
 check(proposal.additions.length===7&&proposal.addedBytes===23110,'Only exact approved shader additions allowed');
 check(fileHash(path.join(project,proposal.source.probe))===proposal.source.probeSHA256,'Native selection probe changed');
 for(const row of [...proposal.source.keySources,...proposal.source.archives])check(fileHash(row.file)===row.sha256,'Installed original source archive/KEY changed');
 const sourceArchive=path.join(base,'catalog-1/resources.erf');check(fileHash(sourceArchive)===catalog.packedSource.sha256,'Original synthetic payload archive changed');
 const originalTimeline=path.join(base,'timeline.jsonl');check(fileHash(originalTimeline)===recording.timelineSha256,'Original timeline changed');
 const source=fs.openSync(sourceArchive,'r'),header=Buffer.alloc(160);fs.readSync(source,header,0,header.length,0);
 check(header.toString('ascii',0,8)==='ERF V1.1','Expected exact native-readable ERF V1.1');
 const count=header.readUInt32LE(16),keysOffset=header.readUInt32LE(24),locationsOffset=header.readUInt32LE(28),keys=Buffer.alloc(count*40),locations=Buffer.alloc(count*8);
 check(count===Object.keys(catalog.availability).length&&count===catalog.packedSource.namespaceEntries,'Original namespace bound differs');
 fs.readSync(source,keys,0,keys.length,keysOffset);fs.readSync(source,locations,0,locations.length,locationsOffset);
 const wanted=new Map(proposal.additions.map(row=>[row.key,row])),slots=new Map();
 for(let i=0;i<count;i++){const at=i*40;let end=keys.indexOf(0,at);if(end<at||end>at+32)end=at+32;const key=keys.toString('latin1',at,end).toLowerCase()+':'+keys.readUInt16LE(at+36);if(wanted.has(key))slots.set(key,keys.readUInt32LE(at+32));}
 check(slots.size===7,'Approved shader names absent from existing native namespace');
 const payloads=[];
 for(const row of proposal.additions){
  check(catalog.availability[row.key]===1&&!catalog.resources[row.key]&&row.key.endsWith(':2069'),'Addition is not an advertised-present unread shader gap');
  const slot=slots.get(row.key);check(slot<count&&locations.readUInt32LE(slot*8+4)===0,'Shader already has captured payload bytes');
  const fd=fs.openSync(row.archive.file,'r'),data=Buffer.alloc(row.bytes);try{check(fs.readSync(fd,data,0,data.length,row.archive.selected_entry.offset)===data.length,'Installed shader read truncated');}finally{fs.closeSync(fd);}
  check(sha(data)===row.sha256&&row.sha256===row.expectedProfileSHA&&row.archive.selected_entry.type===2069,'Native selected original shader profile differs');payloads.push({row,slot,data});
 }
 fs.mkdirSync(destination);const targetCatalog=path.join(destination,'catalog-1');fs.mkdirSync(targetCatalog);fs.mkdirSync(path.join(targetCatalog,'objects'));
 fs.copyFileSync(sourceArchive,path.join(targetCatalog,'resources.erf'));
 const output=fs.openSync(path.join(targetCatalog,'resources.erf'),'r+');let end=fs.statSync(sourceArchive).size;const patches=[];
 try{
  for(const item of payloads){
   check(end+item.data.length<=0xffffffff,'Derived ERF exceeds native range');fs.writeSync(output,item.data,0,item.data.length,end);
   const replacement=Buffer.alloc(8);replacement.writeUInt32LE(end,0);replacement.writeUInt32LE(item.data.length,4);const offset=locationsOffset+item.slot*8;
   fs.writeSync(output,replacement,0,8,offset);patches.push({key:item.row.key,table_offset:offset,old:locations.subarray(item.slot*8,item.slot*8+8).toString('hex'),replacement:replacement.toString('hex'),payload_offset:end,bytes:item.data.length,sha256:item.row.sha256});end+=item.data.length;
  }
  fs.ftruncateSync(output,end);fs.fsyncSync(output);
 }finally{fs.closeSync(output);}
 // Verify every original captured payload against both old/new archive bytes.
 const target=fs.openSync(path.join(targetCatalog,'resources.erf'),'r');const unique=new Map();for(const row of Object.values(catalog.resources))if(!row.error)unique.set(row.sha256,row.bytes);
 const ranges=new Map();for(let slot=0;slot<count;slot++){const size=locations.readUInt32LE(slot*8+4);if(size)ranges.set(locations.readUInt32LE(slot*8)+':'+size,{offset:locations.readUInt32LE(slot*8),size});}
 let verifiedPayloads=0;for(const range of ranges.values()){const a=Buffer.alloc(range.size),b=Buffer.alloc(range.size);fs.readSync(source,a,0,a.length,range.offset);fs.readSync(target,b,0,b.length,range.offset);check(a.equals(b),'Existing captured payload bytes changed');const hash=sha(a);check(unique.get(hash)===a.length,'Existing payload differs from captured resource seal');verifiedPayloads++;}
 fs.closeSync(target);fs.closeSync(source);
 for(const row of Object.values(catalog.talk||{})){const file=path.join(base,'catalog-1/objects',row.sha256);check(fileHash(file)===row.sha256,'Original direct-file TLK changed');fs.copyFileSync(file,path.join(targetCatalog,'objects',row.sha256));}
 const archiveSHA=fileHash(path.join(targetCatalog,'resources.erf'));const derived=structuredClone(catalog);
 for(const row of proposal.additions)derived.resources[row.key]={bytes:row.bytes,sha256:row.sha256};
 for(const [key,row]of Object.entries(catalog.resources))check(JSON.stringify(derived.resources[key])===JSON.stringify(row),'Existing resource record changed');
 const addedHashes=new Set(proposal.additions.map(row=>row.sha256).filter(value=>!unique.has(value)));
 derived.packedSource={...catalog.packedSource,bytes:end,sha256:archiveSHA,uniquePayloads:catalog.packedSource.uniquePayloads+addedHashes.size,unrecordedOrFailed:catalog.packedSource.unrecordedOrFailed-7,sourceManifestSha256:sha(rawCatalog),scope:'Explicitly derived synthetic ERF: unchanged captured payload bytes plus seven separately proven installed original enhanced shader payloads; not an unchanged historical capture or complete visual fixture.'};
 derived.derivedShaderAugmentation={version:1,proposalSha256:expectedProposal,parentCatalogSha256:sha(rawCatalog),addedKeys:proposal.additions.map(row=>row.key),provenance:'../shader-augmentation-provenance.json',unfilled:['fxpa_cloud02','alc_chunk_s01:2002','alc_chunk_s02:2002']};
 const derivedBytes=Buffer.from(JSON.stringify(derived));fs.writeFileSync(path.join(targetCatalog,'manifest.json'),derivedBytes,{flag:'wx'});
 fs.copyFileSync(originalTimeline,path.join(destination,'timeline.jsonl'));
 const next=structuredClone(recording);next.catalogs[0]={...next.catalogs[0],sha256:sha(derivedBytes),resources:Object.keys(derived.resources).length};
 next.benchmarkClone={...next.benchmarkClone,sourceRecordingSha256:sha(rawRecording),sourceTimelineSha256:recording.timelineSha256,catalogs:[{directory:'catalog-1',sha256:sha(derivedBytes),archiveSha256:archiveSHA,bytes:end,namespaceEntries:count,uniquePayloads:derived.packedSource.uniquePayloads,gaps:derived.packedSource.unrecordedOrFailed}],scope:'Explicitly derived shader-augmented original recording; same captured timeline/resource bytes plus separately proven seven original2069 shader payloads. Headless commit/load evidence only; missing FX remains explicit, no complete visual/Arelith acceptance.'};
 next.derivedShaderAugmentation={version:1,proposalSha256:expectedProposal,parentRecordingSha256:sha(rawRecording),provenance:'shader-augmentation-provenance.json',addedResources:7,addedBytes:proposal.addedBytes,scope:next.benchmarkClone.scope};
 const nextBytes=Buffer.from(JSON.stringify(next,null,2)+'\n');fs.writeFileSync(path.join(destination,'recording.json'),nextBytes,{flag:'wx'});
 const provenance={version:1,sealed:true,destination,approvedProposalSHA256:expectedProposal,proposal,nativeSelectionProbe:JSON.parse(fs.readFileSync(path.join(project,proposal.source.probe))),parentBenchmarkClone:recording.benchmarkClone,patches,originalPayloadsByteVerified:verifiedPayloads,originalResourceRecordsPreserved:Object.keys(catalog.resources).length,originalNamespaceUnchanged:true,originalTimelineUnchanged:fileHash(path.join(destination,'timeline.jsonl'))===recording.timelineSha256,originalArchiveUnchanged:fileHash(sourceArchive)===catalog.packedSource.sha256,originalManifestsUnchanged:sha(fs.readFileSync(recordingFile))===sha(rawRecording)&&sha(fs.readFileSync(catalogFile))===sha(rawCatalog),originalNotFoundUnchanged:['alc_chunk_s01:2002','alc_chunk_s02:2002'].every(key=>JSON.stringify(derived.resources[key])===JSON.stringify(catalog.resources[key])),sealedFiles:{recording:{sha256:sha(nextBytes),bytes:nextBytes.length},catalog:{sha256:sha(derivedBytes),bytes:derivedBytes.length},archive:{sha256:archiveSHA,bytes:end},timeline:{sha256:recording.timelineSha256,bytes:recording.bytes}},networkConnections:0,engineLaunches:0,scope:next.benchmarkClone.scope};
 check(provenance.originalTimelineUnchanged&&provenance.originalArchiveUnchanged&&provenance.originalManifestsUnchanged&&provenance.originalNotFoundUnchanged,'Original preservation check failed');
 fs.writeFileSync(path.join(destination,'shader-augmentation-provenance.json'),JSON.stringify(provenance,null,2)+'\n',{flag:'wx'});
 return {destination,recordingSHA256:sha(nextBytes),catalogSHA256:sha(derivedBytes),archiveSHA256:archiveSHA,addedResources:7,addedBytes:proposal.addedBytes,originalPayloadsByteVerified:verifiedPayloads};
}
if(require.main===module){try{const [label,expected]=process.argv.slice(2);console.log(JSON.stringify(seal(label,expected)));}catch(error){console.error(error.stack);process.exitCode=1;}}
module.exports={seal};
