// Read-only PE export-address projection. It does not load/execute the target,
// create a Ghidra session, or claim that a symbol name proves implementation.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';
const workspace=path.resolve(process.cwd()),target=path.resolve(workspace,'../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe');
const bytes=fs.readFileSync(target),sha256=crypto.createHash('sha256').update(bytes).digest('hex');
if(sha256!=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a')throw Error('Original target pin differs');
const pe=bytes.readUInt32LE(0x3c),optional=pe+24,sectionsAt=optional+bytes.readUInt16LE(pe+20),count=bytes.readUInt16LE(pe+6);
if(bytes.toString('ascii',pe,pe+4)!=='PE\0\0'||bytes.readUInt16LE(optional)!==0x20b)throw Error('Expected PE32+');
const imageBase=bytes.readBigUInt64LE(optional+24),sections=[];
for(let i=0;i<count;i++){const at=sectionsAt+i*40;sections.push({name:bytes.toString('ascii',at,at+8).replace(/\0.*$/s,''),virtualSize:bytes.readUInt32LE(at+8),rva:bytes.readUInt32LE(at+12),rawSize:bytes.readUInt32LE(at+16),raw:bytes.readUInt32LE(at+20)});}
function offset(rva){const section=sections.find(s=>rva>=s.rva&&rva-s.rva<s.rawSize);if(!section)throw Error('No file-backed section for '+rva.toString(16));return section.raw+rva-section.rva;}
const exportRva=bytes.readUInt32LE(optional+112),exportSize=bytes.readUInt32LE(optional+116),directory=offset(exportRva);
const ordinalBase=bytes.readUInt32LE(directory+16),functionCount=bytes.readUInt32LE(directory+20),nameCount=bytes.readUInt32LE(directory+24),functionTable=offset(bytes.readUInt32LE(directory+28)),nameTable=offset(bytes.readUInt32LE(directory+32)),ordinalTable=offset(bytes.readUInt32LE(directory+36));
const symbols=[];
for(let i=0;i<nameCount;i++){const at=offset(bytes.readUInt32LE(nameTable+i*4)),end=bytes.indexOf(0,at),name=bytes.toString('ascii',at,end);if(!/BSP|@Scene@@|@Camera@@/.test(name))continue;const index=bytes.readUInt16LE(ordinalTable+i*2),rva=bytes.readUInt32LE(functionTable+index*4),section=sections.find(s=>rva>=s.rva&&rva-s.rva<s.rawSize);symbols.push({name,address:'0x'+(imageBase+BigInt(rva)).toString(16),rva,fileOffset:section?section.raw+rva-section.rva:null,ordinal:ordinalBase+index,forwarded:rva>=exportRva&&rva<exportRva+exportSize});}
const result={version:1,authority:'shipped-artifact',confidence:'observed',target:{path:target,sha256,bytes:bytes.length,imageBase:'0x'+imageBase.toString(16)},method:'Bounded local PE32+ export directory and file-backed section mappings; symbol-name filter BSP/Scene/Camera',exportCounts:{functions:functionCount,names:nameCount},symbols,limitations:['Names/addresses are binary exports, not implementation evidence. No process, native code or deep analysis was started.']};
if(process.argv[2]){const output=path.resolve(process.argv[2]),boundary=path.join(workspace,'godot-client/.cache/native-presentation-parity/loading-agent')+path.sep;if(!output.startsWith(boundary)||fs.existsSync(output))throw Error('Fresh owned evidence path required');fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});}
console.log(JSON.stringify({target:result.target,symbols:result.symbols.filter(s=>/BSP|(?<!Aur)SetGrid|Init|Create|Size|Box|Bounds/.test(s.name))},null,2));
