import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

// Creates a new capsule from an already completed, private same-object MAP link.
// It never compiles, links, edits an existing image, or normalizes PE metadata.
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const cache=path.join(project,'.cache/native-render-gap/particles');
const [baseLabel,label,mapLabel='kernel-map-a']=process.argv.slice(2);
for(const value of [baseLabel,label,mapLabel])if(!value||!/^[a-z0-9-]+$/.test(value))throw Error('Usage: prepare_mapped_kernel.mjs BASE FRESH-LABEL [kernel-map-a]');
if(baseLabel===label)throw Error('Mapped capsule must have a fresh label');
const base=path.join(cache,baseLabel),stage=path.join(cache,label);
if(fs.existsSync(stage))throw Error('Prior mapped capsule evidence retained');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const readJson=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
const originalReceiptFile=path.join(base,'kernel-build/build-receipt.json');
const relinkReceiptFile=path.join(base,mapLabel,'receipt.json');
const original=readJson(originalReceiptFile),relink=readJson(relinkReceiptFile);
const manifest=readJson(path.join(base,'kernel-source-pins.json'));
if(!original.success||original.exit!==0||!relink.success||relink.linkExit!==0||relink.sourceCompilation!==0||!relink.originalInputsUnchanged||relink.normalizationApplied!==false)throw Error('Successful unchanged same-object provenance is required');
const expectedOriginal=path.join(base,'kernel-build/nwn-particle-kernel.dll');
if(path.resolve(original.binary)!==expectedOriginal||path.resolve(relink.originalBinary)!==expectedOriginal||relink.originalBinarySha256!==original.binarySha256)throw Error('Original image identity mismatch');
if(path.resolve(relink.binary)!==path.join(base,mapLabel,'nwn-particle-kernel.dll')||path.resolve(relink.map)!==path.join(base,mapLabel,'nwn-particle-kernel.map'))throw Error('Unexpected private relink output');
const originalBytes=fs.readFileSync(original.binary),bytes=fs.readFileSync(relink.binary),mapBytes=fs.readFileSync(relink.map);
if(hash(originalBytes)!==original.binarySha256||hash(bytes)!==relink.binarySha256||hash(mapBytes)!==relink.mapSha256||hash(fs.readFileSync(relink.object))!==relink.objectSha256)throw Error('Retained binary/map/object pin drift');
if(hash(fs.readFileSync(original.compiler))!==original.compilerSha256)throw Error('Original compiler pin drift');
const originalPins=new Map(original.sourcePins.map(pin=>[pin.relative,pin.sha256]));
if(originalPins.size!==manifest.pins.length)throw Error('Original compiler source closure differs');
const inputs=manifest.pins.map(pin=>{
 if(originalPins.get(pin.relative)!==pin.sha256)throw Error('Compile source pin differs: '+pin.relative);
 const source=path.join(manifest.project,pin.relative),data=fs.readFileSync(source);
 if(hash(data)!==pin.sha256)throw Error('Sealed compiler input drift: '+pin.relative);
 return {pin,source,data};
});
const groupRelative='systems/native_render/particle_stream_group.gd';
const group=fs.readFileSync(path.join(base,groupRelative));
const layoutFile=path.join(base,mapLabel,'layout-proof.json'),layout=readJson(layoutFile);
if(layout.before.sha256!==original.binarySha256||layout.after.sha256!==relink.binarySha256||layout.olderBinaryMappingAllowed!==relink.olderBinaryMappingAllowed)throw Error('Layout proof provenance differs');

// Parse exact RUNTIME_FUNCTION fragments, including shrink-wrapped chained tails.
const pe=bytes.readUInt32LE(60);
if(bytes.toString('ascii',pe,pe+4)!=='PE\0\0'||bytes.readUInt16LE(pe+4)!==0x8664)throw Error('Only exact x64 PE images are supported');
const optional=pe+24,table=optional+bytes.readUInt16LE(pe+20);
if(bytes.readUInt16LE(optional)!==0x20b)throw Error('PE32+ is required');
const imageBase=bytes.readBigUInt64LE(optional+24),imageSize=bytes.readUInt32LE(optional+56),sections=[];
for(let index=0;index<bytes.readUInt16LE(pe+6);++index){
 const at=table+index*40;
 sections.push({name:bytes.toString('ascii',at,at+8).split('\0')[0],rva:bytes.readUInt32LE(at+12),virtualSize:bytes.readUInt32LE(at+8),rawSize:bytes.readUInt32LE(at+16),raw:bytes.readUInt32LE(at+20),flags:bytes.readUInt32LE(at+36)});
}
function offset(rva,size=1){
 const section=sections.find(row=>rva>=row.rva&&rva+size<=row.rva+row.rawSize);
 if(!section)throw Error('RVA has no complete file-backed range: '+rva.toString(16));
 return section.raw+rva-section.rva;
}
const pdataRva=bytes.readUInt32LE(optional+112+3*8),pdataSize=bytes.readUInt32LE(optional+116+3*8),fragments=[];
if(pdataSize%12)throw Error('Incomplete x64 exception table');
for(let delta=0;delta<pdataSize;delta+=12){
 const at=offset(pdataRva+delta,12);
 fragments.push({begin:bytes.readUInt32LE(at),end:bytes.readUInt32LE(at+4),unwind_rva:bytes.readUInt32LE(at+8)});
}
function root(fragment,seen=new Set()){
 if(seen.has(fragment.unwind_rva))throw Error('Cyclic chained unwind');
 seen.add(fragment.unwind_rva);
 const at=offset(fragment.unwind_rva,4),flags=bytes[at]>>3,codes=bytes[at+2];
 if(!(flags&4))return fragment.begin;
 if(flags&3)throw Error('Chained unwind also has an exception handler');
 const chainRva=fragment.unwind_rva+4+((codes+1)&~1)*2,chain=offset(chainRva,12);
 return root({begin:bytes.readUInt32LE(chain),end:bytes.readUInt32LE(chain+4),unwind_rva:bytes.readUInt32LE(chain+8)},seen);
}
const symbols=new Map();
for(const line of mapBytes.toString().split(/\r?\n/)){
 const match=/^\s+([0-9a-f]{4}):([0-9a-f]{8,16})\s+(\S+)\s+([0-9a-f]{8,16})(?:\s+(.*))?$/i.exec(line);
 if(!match)continue;
 const address=BigInt('0x'+match[4]);
 if(address<imageBase||address>=imageBase+BigInt(imageSize))continue;
 const rva=Number(address-imageBase),section=sections.find(row=>rva>=row.rva&&rva<row.rva+row.virtualSize);
 if(!section||(section.flags&0x20000000)===0)continue;
 let symbol=symbols.get(rva);
 if(!symbol){symbol={rva,aliases:[],map_tail:[],ranges:[]};symbols.set(rva,symbol);}
 symbol.aliases.push(match[3]);symbol.map_tail.push(match[5]??'');
}
let chainedFragments=0,unnamedRootFragments=0;
for(const fragment of fragments){
 fragment.owner_rva=root(fragment);
 if(fragment.owner_rva!==fragment.begin)++chainedFragments;
 const symbol=symbols.get(fragment.owner_rva);
 if(symbol)symbol.ranges.push(fragment);else ++unnamedRootFragments;
}
const functions=[...symbols.values()].sort((a,b)=>a.rva-b.rva);
for(let index=0;index<functions.length;++index){
 const symbol=functions[index];
 if(symbol.ranges.length){
  symbol.end_rva=Math.max(...symbol.ranges.map(row=>row.end));
  symbol.size=symbol.ranges.reduce((sum,row)=>sum+row.end-row.begin,0);
  symbol.range_source='Exact PE x64 RUNTIME_FUNCTION fragments with recursive UNW_FLAG_CHAININFO ownership';
 }else{
  const section=sections.find(row=>symbol.rva>=row.rva&&symbol.rva<row.rva+row.virtualSize);
  symbol.end_rva=Math.min(functions[index+1]?.rva??Infinity,section.rva+section.virtualSize);
  symbol.size=symbol.end_rva-symbol.rva;
  symbol.range_source='Next MAP code-symbol fallback; no named runtime function root, approximate leaf/padding coverage';
 }
}
if(!functions.length||!fragments.length)throw Error('Missing MAP symbols or x64 runtime functions');

// All validation precedes creation, preserving prior evidence on every path.
const kernel=path.join(stage,'kernel-project'),build=path.join(stage,'kernel-build');
fs.mkdirSync(build,{recursive:true});
const pins=[];
for(const {pin,source,data} of inputs){
 const output=path.join(kernel,pin.relative);fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,data);pins.push({...pin,source});
}
const binary=path.join(build,'nwn-particle-kernel.dll'),map=path.join(build,'nwn-particle-kernel.map');
fs.writeFileSync(binary,bytes);fs.writeFileSync(map,mapBytes);
const groupOutput=path.join(stage,groupRelative);fs.mkdirSync(path.dirname(groupOutput),{recursive:true});fs.writeFileSync(groupOutput,group);
for(const [source,name] of [[originalReceiptFile,'original-compile-receipt.json'],[relinkReceiptFile,'same-object-relink-receipt.json'],[layoutFile,'older-image-layout-proof.json']])fs.copyFileSync(source,path.join(build,name));
const symbolsFile=path.join(build,'nwn-particle-kernel.symbols.json');
const symbolIndex={version:2,binary,binarySha256:relink.binarySha256,map,mapSha256:relink.mapSha256,imageBase:'0x'+imageBase.toString(16),imageSize,scope:'THIS exact mapped image only. Match exact unwind fragment first, then its root symbol; retain identical-code-fold aliases. Leaf next-symbol ranges are explicitly approximate.',olderBinaryMappingAllowed:relink.olderBinaryMappingAllowed,unwindRangeCount:fragments.length,chainedFragments,unnamedRootFragments,functionCount:functions.length,unwindFragments:fragments,functions};
fs.writeFileSync(symbolsFile,JSON.stringify(symbolIndex,null,2)+'\n');
fs.writeFileSync(path.join(stage,'kernel-source-pins.json'),JSON.stringify({version:1,project:kernel,pins,compilerInvoked:false,sourceCompilation:0,scope:'Exact copied compiler inputs; capsule binary is the retained same-object MAP relink, no source compilation in this capsule'},null,2)+'\n');
const originalCompileReceipt=path.join(build,'original-compile-receipt.json'),sameObjectRelinkReceipt=path.join(build,'same-object-relink-receipt.json');
const receipt={version:2,success:true,exit:relink.linkExit,exitProvenance:'Actual retained same-object link exit, not a new source compile',sourceCompilation:0,compilerInvokedHere:false,linkerInvokedHere:false,createdBy:'Capsule copy of retained same-object MAP relink',scope:'Same-object MAP relink. Use this exact mapped image for capture unless the strict retained all-loadable-byte proof explicitly accepts the original image.',binary,binarySha256:relink.binarySha256,compiler:original.compiler,compilerSha256:original.compilerSha256,flags:original.flags,arguments:relink.arguments,sourcePins:pins,object:relink.object,objectSha256:relink.objectSha256,map,mapSha256:relink.mapSha256,symbolIndex:symbolsFile,symbolIndexSha256:hash(fs.readFileSync(symbolsFile)),originalCompileReceipt,originalCompileReceiptSha256:hash(fs.readFileSync(originalCompileReceipt)),sameObjectRelinkReceipt,sameObjectRelinkReceiptSha256:hash(fs.readFileSync(sameObjectRelinkReceipt)),originalBinary:original.binary,originalBinarySha256:original.binarySha256,olderBinaryMappingAllowed:relink.olderBinaryMappingAllowed,originalInputsUnchanged:true,normalizationApplied:false,sharedBinaryWrites:0,engineStarts:0};
fs.writeFileSync(path.join(build,'build-receipt.json'),JSON.stringify(receipt,null,2)+'\n');
fs.writeFileSync(path.join(stage,'proposal.json'),JSON.stringify({label,baseLabel,kernel,sourcePins:pins,groupSha256:hash(group),scope:receipt.scope,originalCompileReceipt,originalCompileReceiptSha256:receipt.originalCompileReceiptSha256,sameObjectRelinkReceipt,sameObjectRelinkReceiptSha256:receipt.sameObjectRelinkReceiptSha256,sourceCompilation:0},null,2)+'\n');
console.log(JSON.stringify({stage,binarySha256:relink.binarySha256,files:pins.length,mapSha256:relink.mapSha256,symbolIndex:symbolsFile,functionCount:functions.length,unwindRangeCount:fragments.length,chainedFragments,unnamedRootFragments,olderBinaryMappingAllowed:relink.olderBinaryMappingAllowed}));
