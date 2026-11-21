import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const stage=path.join(project,'.cache/native-140fps/render-agent/engine-builtin-light-v2');
const destination=path.join(project,'.cache/native-140fps/render-agent/crash-symbolization-v1');
if(fs.existsSync(destination))throw Error('Previous symbol proof is retained');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const archived=path.join(stage,'build-1793905781252/binaries/godot.windows.template_release.x86_64.exe');
const relinked=path.join(stage,'source/bin/godot.windows.template_release.x86_64.exe');
function pe(file){
 const b=fs.readFileSync(file),offset=b.readUInt32LE(60),optional=offset+24;
 if(b.readUInt16LE(optional)!==0x20b)throw Error('Expected PE32+');
 const result={file,sha256:hash(b),preferredBase:'0x'+b.readBigUInt64LE(optional+24).toString(16),symbols:b.readUInt32LE(offset+16),sections:[]};
 const sectionStart=optional+b.readUInt16LE(offset+20);
 for(let i=0;i<b.readUInt16LE(offset+6);i++){
  const s=sectionStart+i*40,name=b.toString('ascii',s,s+8).replace(/\0/g,'');
  if(name!=='.text')continue;
  const size=b.readUInt32LE(s+16),start=b.readUInt32LE(s+20);
  result.sections.push({name,rva:b.readUInt32LE(s+12),virtualBytes:b.readUInt32LE(s+8),fileBytes:size,sha256:hash(b.subarray(start,start+size))});
 }
 return result;
}
const original=pe(archived),mapped=pe(relinked);
if(original.sha256!=='ce2d36407d0a6107a3076a00faf7d9f9dae185c86994ccea8dfd7e450c50f12a')throw Error('Archived fault engine changed');
if(JSON.stringify(original.sections)!==JSON.stringify(mapped.sections))throw Error('Map relink changed executable code/RVA layout');
const mapFile=path.join(stage,'source/crash-main-symbols.map'),mapBytes=fs.readFileSync(mapFile);
const symbols=mapBytes.toString().split(/\r?\n/).flatMap(line=>{
 const m=/^\s+(0x[0-9a-f]+)\s+([^=].*)$/.exec(line);
 return m?[{address:BigInt(m[1]),name:m[2]}]:[];
}).sort((a,b)=>a.address<b.address?-1:a.address>b.address?1:0);
const logFile=path.join(project,'reports/native-perf140-builtin-light-crash-trace-v1.cdb.log'),logBytes=fs.readFileSync(logFile),log=logBytes.toString();
const load=/ModLoad:\s+([0-9a-f`]+)\s+[0-9a-f`]+\s+godot\.windows\.template_release\.x86_64\.exe/i.exec(log);
const exception=/ExceptionAddress:\s+([0-9a-f`]+)/i.exec(log);
if(!load||!exception)throw Error('Missing observed module/exception witness');
const loadedBase=BigInt('0x'+load[1].replace(/`/g,'')),preferred=BigInt(original.preferredBase);
const actualAddresses=[exception[1],...Array.from(log.matchAll(/^\s*[0-9a-f`]+\s+([0-9a-f`]+)\s+:/gmi),m=>m[1])];
const unique=[...new Set(actualAddresses)].map(s=>BigInt('0x'+s.replace(/`/g,'')));
const entries=unique.filter(a=>a>=loadedBase&&a<loadedBase+0x580f000n).map(actual=>{
  const address=actual-loadedBase+preferred;let match;
  for(const s of symbols){if(s.address>address)break;match=s;}
  return {actual:'0x'+actual.toString(16),rva:'0x'+(actual-loadedBase).toString(16),preferred:'0x'+address.toString(16),nearestSymbol:match?.name,offset:match?'0x'+(address-match.address).toString(16):null};
});
fs.mkdirSync(destination,{recursive:true});
fs.copyFileSync(mapFile,path.join(destination,'main-link.map'));
const receipt={success:true,original,mapped,identicalExecutableText:true,map:{file:path.join(destination,'main-link.map'),sha256:hash(mapBytes)},log:{file:logFile,sha256:hash(logBytes)},loadedBase:'0x'+loadedBase.toString(16),entries,limitations:['Optimized stripped binary has no source-line DWARF. Names come from an otherwise identical linker-map relink; nearest-symbol labels require disassembly when gaps/inlined code exist.','Object::_call_bind fault instruction is a direct null Object receiver dereference. This does not identify the GDScript source method by itself; the separate actual constructor oracle and runtime source isolation supply that evidence.'],engineSourceChanged:false,archivedEngineChanged:false};
fs.writeFileSync(path.join(destination,'receipt.json'),JSON.stringify(receipt,null,2));
console.log(JSON.stringify({success:true,destination,text:original.sections,entries:entries.slice(0,12)},null,2));
