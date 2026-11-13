import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2];
if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Usage: index_kernel_build.mjs PRIVATE-LABEL');
const stage=path.join(project,'.cache/native-render-gap/particles',label),build=path.join(stage,'kernel-build'),output=path.join(build,'nwn-particle-kernel.symbols.json');
if(fs.existsSync(output))throw Error('Retain existing exact index');
const receipt=JSON.parse(fs.readFileSync(path.join(build,'build-receipt.json'),'utf8').replace(/^\uFEFF/,'')),hash=data=>crypto.createHash('sha256').update(data).digest('hex');
if(!receipt.success||receipt.exit!==0||!receipt.map||!receipt.mapSha256||receipt.sourceCompilation===0)throw Error('Successful source build with original-link MAP required');
const binary=path.resolve(receipt.binary),map=path.resolve(receipt.map),bytes=fs.readFileSync(binary),mapBytes=fs.readFileSync(map);
if(binary!==path.join(build,'nwn-particle-kernel.dll')||map!==path.join(build,'nwn-particle-kernel.map')||hash(bytes)!==receipt.binarySha256||hash(mapBytes)!==receipt.mapSha256)throw Error('Exact built image/MAP identity drift');
const pe=bytes.readUInt32LE(60),optional=pe+24,table=optional+bytes.readUInt16LE(pe+20);
if(bytes.toString('ascii',pe,pe+4)!=='PE\0\0'||bytes.readUInt16LE(pe+4)!==0x8664||bytes.readUInt16LE(optional)!==0x20b)throw Error('Expected x64 PE32+');
const imageBase=bytes.readBigUInt64LE(optional+24),imageSize=bytes.readUInt32LE(optional+56),sections=[];
for(let n=0;n<bytes.readUInt16LE(pe+6);++n){const at=table+n*40;sections.push({rva:bytes.readUInt32LE(at+12),virtualSize:bytes.readUInt32LE(at+8),rawSize:bytes.readUInt32LE(at+16),raw:bytes.readUInt32LE(at+20),flags:bytes.readUInt32LE(at+36)});}
function offset(rva,size=1){const section=sections.find(row=>rva>=row.rva&&rva+size<=row.rva+row.rawSize);if(!section)throw Error('Incomplete file-backed RVA');return section.raw+rva-section.rva;}
const pr=bytes.readUInt32LE(optional+136),pn=bytes.readUInt32LE(optional+140),fragments=[];
if(pn%12)throw Error('Incomplete x64 exception table');
for(let delta=0;delta<pn;delta+=12){const at=offset(pr+delta,12);fragments.push({begin:bytes.readUInt32LE(at),end:bytes.readUInt32LE(at+4),unwind_rva:bytes.readUInt32LE(at+8)});}
function owner(fragment,seen=new Set()){
 if(seen.has(fragment.unwind_rva))throw Error('Cyclic chained unwind');seen.add(fragment.unwind_rva);
 const at=offset(fragment.unwind_rva,4),flags=bytes[at]>>3,codes=bytes[at+2];if(!(flags&4))return fragment.begin;
 if(flags&3)throw Error('Chained unwind also declares handler');const chain=offset(fragment.unwind_rva+4+((codes+1)&~1)*2,12);
 return owner({begin:bytes.readUInt32LE(chain),end:bytes.readUInt32LE(chain+4),unwind_rva:bytes.readUInt32LE(chain+8)},seen);
}
const symbols=new Map();
for(const line of mapBytes.toString().split(/\r?\n/)){
 const match=/^\s+([0-9a-f]{4}):([0-9a-f]{8,16})\s+(\S+)\s+([0-9a-f]{8,16})(?:\s+(.*))?$/i.exec(line);if(!match)continue;
 const address=BigInt('0x'+match[4]);if(address<imageBase||address>=imageBase+BigInt(imageSize))continue;
 const rva=Number(address-imageBase),section=sections.find(row=>rva>=row.rva&&rva<row.rva+row.virtualSize);if(!section||!(section.flags&0x20000000))continue;
 let row=symbols.get(rva);if(!row){row={rva,aliases:[],map_tail:[],ranges:[]};symbols.set(rva,row);}row.aliases.push(match[3]);row.map_tail.push(match[5]??'');
}
let chainedFragments=0,unnamedRootFragments=0;
for(const fragment of fragments){fragment.owner_rva=owner(fragment);if(fragment.owner_rva!==fragment.begin)++chainedFragments;const symbol=symbols.get(fragment.owner_rva);if(symbol)symbol.ranges.push(fragment);else ++unnamedRootFragments;}
const functions=[...symbols.values()].sort((a,b)=>a.rva-b.rva);
for(let n=0;n<functions.length;++n){const row=functions[n];if(row.ranges.length){row.end_rva=Math.max(...row.ranges.map(fragment=>fragment.end));row.size=row.ranges.reduce((sum,fragment)=>sum+fragment.end-fragment.begin,0);row.range_source='Exact PE x64 RUNTIME_FUNCTION fragments with recursive chained-unwind ownership';}else{const section=sections.find(section=>row.rva>=section.rva&&row.rva<section.rva+section.virtualSize);row.end_rva=Math.min(functions[n+1]?.rva??Infinity,section.rva+section.virtualSize);row.size=row.end_rva-row.rva;row.range_source='Approximate next-MAP-symbol leaf/padding interval; no runtime-function root';}}
if(!functions.length||!fragments.length)throw Error('Missing exact MAP/runtime functions');
const result={version:2,binary,binarySha256:receipt.binarySha256,map,mapSha256:receipt.mapSha256,imageBase:'0x'+imageBase.toString(16),imageSize,buildReceipt:path.join(build,'build-receipt.json'),buildReceiptSha256:hash(fs.readFileSync(path.join(build,'build-receipt.json'))),scope:'Exact original source-build image and original-link MAP. No relink/normalization or address reuse. Match exact chained-unwind fragments first; retained leaf fallback intervals are explicitly approximate.',unwindRangeCount:fragments.length,chainedFragments,unnamedRootFragments,functionCount:functions.length,unwindFragments:fragments,functions};
fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({output,sha256:hash(fs.readFileSync(output)),binarySha256:receipt.binarySha256,mapSha256:receipt.mapSha256,symbols:functions.length,fragments:fragments.length,chainedFragments,unnamedRootFragments}));
