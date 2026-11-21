import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';

// Data-only index factory. No SCons/compiler invocation and no engine launch.
// Resolve private ABI helpers from exact COFF symbol sections and multiple
// public anchors; never reuse a V6 object offset or a nearest public label.
const [directory]=process.argv.slice(2);
if(!directory)throw Error('Usage: index_mapped_engine.mjs LINK-MAP-DIRECTORY');
const root=path.resolve(directory),output=path.join(root,'engine-unwind-index.json');
if(fs.existsSync(output)||fs.existsSync(path.join(root,'scene-boundary-object-symbols.json')))throw Error('Retain prior engine index proof');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const readJson=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
const layoutFile=path.join(root,'layout-comparison.json'),layout=readJson(layoutFile);
const mapFile=path.join(root,'main-map-index.json'),map=readJson(mapFile);
const plan=readJson(path.join(root,'plan.json')),file=path.join(root,'after.exe'),bytes=fs.readFileSync(file);
if(!layout.sameLoadableLayoutAndBytes||!layout.olderBinaryMappingAllowed||layout.before.sha256!==layout.after.sha256)throw Error('Whole-file byte-identical original/relink proof required');
if(hash(bytes)!==map.engine.sha256||map.engine.sha256!==layout.after.sha256||hash(fs.readFileSync(layout.before.file))!==layout.before.sha256)throw Error('Exact engine image pin mismatch');
if(hash(fs.readFileSync(map.map.file))!==map.map.sha256||map.map.sha256!==layout.map.sha256)throw Error('Exact linker MAP pin mismatch');
const pe=bytes.readUInt32LE(60),optional=pe+24,table=optional+bytes.readUInt16LE(pe+20),sections=[];
if(bytes.toString('ascii',pe,pe+4)!=='PE\0\0'||bytes.readUInt16LE(pe+4)!==0x8664||bytes.readUInt16LE(optional)!==0x20b)throw Error('Expected x64 PE32+');
for(let n=0;n<bytes.readUInt16LE(pe+6);++n){const at=table+n*40;sections.push({name:bytes.toString('ascii',at,at+8).split('\0')[0],rva:bytes.readUInt32LE(at+12),raw:bytes.readUInt32LE(at+20),size:bytes.readUInt32LE(at+16)});}
function imageOffset(rva,size=1){const section=sections.find(row=>rva>=row.rva&&rva+size<=row.rva+row.size);if(!section)throw Error('Unwind RVA outside complete file-backed image range');return section.raw+rva-section.rva;}
const pdataRva=bytes.readUInt32LE(optional+136),pdataSize=bytes.readUInt32LE(optional+140),fragments=[];
if(pdataSize%12)throw Error('Incomplete x64 runtime-function table');
for(let delta=0;delta<pdataSize;delta+=12){const at=imageOffset(pdataRva+delta,12),begin=bytes.readUInt32LE(at),end=bytes.readUInt32LE(at+4),unwind=bytes.readUInt32LE(at+8);if(begin&&end>begin)fragments.push({begin,end,unwind_rva:unwind});}
function unwindRoot(fragment,seen=new Set()){
 if(seen.has(fragment.unwind_rva))throw Error('Cyclic engine chained unwind');seen.add(fragment.unwind_rva);
 const at=imageOffset(fragment.unwind_rva,4),flags=bytes[at]>>3,codes=bytes[at+2];
 if(!(flags&4))return fragment.begin;
 if(flags&3)throw Error('Chained engine unwind also declares a handler');
 const chain=imageOffset(fragment.unwind_rva+4+((codes+1)&~1)*2,12);
 return unwindRoot({begin:bytes.readUInt32LE(chain),end:bytes.readUInt32LE(chain+4),unwind_rva:bytes.readUInt32LE(chain+8)},seen);
}
for(const fragment of fragments)fragment.owner_rva=unwindRoot(fragment);
const names=new Map(map.rows.map(row=>[row[0],[...row[2]]]));

// Parse the exact unstripped COFF object rather than assuming that every nm
// text symbol belongs to its ordinary .text input section.
const objectRelative='bin/obj/modules/nwn_particle_snapshot/scene_boundary.windows.template_release.x86_64.o';
const objectFile=path.join(plan.source,objectRelative),objectBytes=fs.readFileSync(objectFile),objectSha256=hash(objectBytes);
const bigobj=objectBytes.readUInt16LE(0)===0&&objectBytes.readUInt16LE(2)===0xffff;
if(bigobj){
 if(objectBytes.length<56||objectBytes.readUInt16LE(4)<2||objectBytes.readUInt16LE(6)!==0x8664||objectBytes.subarray(12,28).toString('hex')!=='c7a1bad1eebaa94baf20faf66aa4dcb8')throw Error('Expected x64 bigobj COFF header');
}else if(objectBytes.readUInt16LE(0)!==0x8664)throw Error('Expected x64 COFF object');
const objectSymbolTable=objectBytes.readUInt32LE(bigobj?48:8),objectSymbolCount=objectBytes.readUInt32LE(bigobj?52:12),objectSectionTable=bigobj?56:20+objectBytes.readUInt16LE(16),objectSectionCount=bigobj?objectBytes.readUInt32LE(44):objectBytes.readUInt16LE(2),symbolSize=bigobj?20:18,stringsAt=objectSymbolTable+objectSymbolCount*symbolSize;
const stringSize=objectBytes.readUInt32LE(stringsAt);
if(stringsAt+stringSize>objectBytes.length)throw Error('COFF string table outside object');
function coffString(offset){if(offset<4||offset>=stringSize)throw Error('Invalid COFF string offset');const start=stringsAt+offset,end=objectBytes.indexOf(0,start);if(end<0||end>=stringsAt+stringSize)throw Error('Unterminated COFF string');return objectBytes.toString('utf8',start,end);}
const objectSections=[];
for(let n=0;n<objectSectionCount;++n){const at=objectSectionTable+n*40,raw=objectBytes.toString('ascii',at,at+8).split('\0')[0],name=raw.startsWith('/')?coffString(Number(raw.slice(1))):raw;objectSections.push({number:n+1,name,size:objectBytes.readUInt32LE(at+16),raw:objectBytes.readUInt32LE(at+20),flags:objectBytes.readUInt32LE(at+36)});}
const objectSymbols=[];
for(let n=0;n<objectSymbolCount;){
 const at=objectSymbolTable+n*symbolSize,name=objectBytes.readUInt32LE(at)===0?coffString(objectBytes.readUInt32LE(at+4)):objectBytes.toString('ascii',at,at+8).split('\0')[0];
 const symbol={name,value:objectBytes.readUInt32LE(at+8),sectionNumber:bigobj?objectBytes.readInt32LE(at+12):objectBytes.readInt16LE(at+12),type:objectBytes.readUInt16LE(at+(bigobj?16:14)),storageClass:objectBytes[at+(bigobj?18:16)]};
 if(symbol.sectionNumber>0&&(symbol.type&0x20)!==0)objectSymbols.push(symbol);
 n+=1+objectBytes[at+(bigobj?19:17)];
}
if(!objectSymbols.length)throw Error('No exact COFF function symbols');
const compiler=path.resolve(plan.compiler),demangler=path.join(path.dirname(compiler),path.basename(compiler).replace(/g\+\+(\.exe)?$/,'c++filt$1'));
if(demangler===compiler)throw Error('Expected pinned MinGW g++ toolchain');
if(hash(fs.readFileSync(compiler))!==plan.compilerSha256)throw Error('Compiler toolchain pin drift');
const demangle=spawnSync(demangler,[],{input:objectSymbols.map(row=>row.name).join('\n')+'\n',encoding:'utf8',windowsHide:true,timeout:10000,maxBuffer:2*1024*1024});
if(demangle.status!==0)throw Error('Exact toolchain c++filt failed');
const demangled=demangle.stdout.trimEnd().split(/\r?\n/);
if(demangled.length!==objectSymbols.length)throw Error('Demangler symbol cardinality differs');
for(let n=0;n<objectSymbols.length;++n)objectSymbols[n].demangled=demangled[n];
const privateSymbols=objectSymbols.filter(row=>/^\(anonymous namespace\)::direct_(?:abi|eligibility|transform)\(/.test(row.demangled));
if(privateSymbols.length!==3)throw Error('Expected exactly three private direct ABI helpers');
const privateSections=new Set(privateSymbols.map(row=>row.sectionNumber));
if(privateSections.size!==1)throw Error('Private helper functions do not share one COFF input section');
const sectionNumber=privateSymbols[0].sectionNumber,inputSection=objectSections[sectionNumber-1];
const normalize=value=>value.replaceAll('\\','/').toLowerCase();
const objectOwner=normalize(objectRelative),anchors=[];
for(const symbol of objectSymbols.filter(row=>row.sectionNumber===sectionNumber&&row.storageClass===2&&/^NwnParticleSceneBoundary::/.test(row.demangled))){
 const candidates=map.rows.filter(row=>row[2].includes(symbol.demangled)&&normalize(row[3])===objectOwner&&row[4]===inputSection.name);
 if(candidates.length!==1)throw Error('Public COFF/MAP anchor is missing or ambiguous: '+symbol.demangled);
 anchors.push({name:symbol.demangled,mangled:symbol.name,mapRva:candidates[0][0],objectTextOffset:symbol.value,inputObject:candidates[0][3],inputSection:candidates[0][4],inputTextBaseRva:candidates[0][0]-symbol.value});
}
if(anchors.length<2||new Set(anchors.map(row=>row.objectTextOffset)).size<2||new Set(anchors.map(row=>row.inputTextBaseRva)).size!==1)throw Error('At least two distinct exact public anchors must agree on the input section base');
const inputTextBaseRva=anchors[0].inputTextBaseRva,runtimeBegins=new Set(fragments.map(row=>row.begin)),privateCorrections=[];
for(const symbol of privateSymbols){
 const rva=inputTextBaseRva+symbol.value;
 if(!runtimeBegins.has(rva))throw Error('Private function does not start an exact runtime-function fragment: '+symbol.demangled);
 const prior=names.get(rva)??[];
 if(prior.length&&!prior.includes(symbol.demangled))throw Error('Private helper collides with a different exact public symbol');
 names.set(rva,[...new Set([...prior,symbol.demangled])]);
 privateCorrections.push({rva,name:symbol.demangled,mangled:symbol.name,objectTextOffset:symbol.value,coffSectionNumber:symbol.sectionNumber,inputSection:inputSection.name});
}
if(hash(fs.readFileSync(objectFile))!==objectSha256)throw Error('Private helper object changed during analysis');
const symbolFile=path.join(root,'scene-boundary-object-symbols.json');
const symbolProof={version:2,objectFile,objectSha256,coffFormat:bigobj?'bigobj20':'ordinary18',objectSections,functions:objectSymbols,demangler,demanglerSha256:hash(fs.readFileSync(demangler)),scope:'Exact COFF function value + section numbers, demangled using the pinned compiler toolchain; no nearest-symbol inference'};
const rows=fragments.map(fragment=>[fragment.begin,fragment.end,fragment.unwind_rva,names.get(fragment.owner_rva)??[]]);
const result={version:2,binary:{file,sha256:hash(bytes)},map:{file:mapFile,sha256:hash(fs.readFileSync(mapFile))},columns:['begin_rva','end_rva','unwind_info_rva','exact_begin_names'],rows,unwindFragments:fragments,chainedFragments:fragments.filter(row=>row.owner_rva!==row.begin).length,privateCorrections:{objectFile,objectSha256,symbolFile,symbolSha256:hash(Buffer.from(JSON.stringify(symbolProof)+'\n')),anchorCount:anchors.length,anchors,inputSection,inputTextBaseRva,rows:privateCorrections},scope:'Exact x64 runtime-function fragments with recursive chained-unwind ownership. Names are joined only at the exact root begin RVA. Three private ABI helpers require exact COFF section membership and at least two agreeing same-object public MAP anchors. Whole original/relink EXE SHA identity is required; missing names remain unresolved.'};
fs.writeFileSync(symbolFile,JSON.stringify(symbolProof)+'\n',{flag:'wx'});
fs.writeFileSync(output,JSON.stringify(result)+'\n',{flag:'wx'});
console.log(JSON.stringify({output,sha256:hash(fs.readFileSync(output)),ranges:rows.length,chainedFragments:result.chainedFragments,privateCorrections,anchorCount:anchors.length,objectSha256}));
