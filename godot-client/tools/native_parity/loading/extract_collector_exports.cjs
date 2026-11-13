// Read-only shipped PE export table. No target execution or analysis import.
const fs=require('node:fs'),crypto=require('node:crypto');
const file='C:/Users/Niflheim/Desktop/Tools/Local Tools/FullDecomp/NwnRootInstall/bin/win32/nwmain.exe';
const raw=fs.readFileSync(file),sha=crypto.createHash('sha256').update(raw).digest('hex');
if(sha!=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a')throw Error('Original identity differs');
const pe=raw.readUInt32LE(0x3c);if(raw.toString('ascii',pe,pe+4)!=='PE\0\0')throw Error('Invalid PE');
const sections=raw.readUInt16LE(pe+6),optionalSize=raw.readUInt16LE(pe+20),optional=pe+24;
if(raw.readUInt16LE(optional)!==0x20b)throw Error('Expected PE32+');
const imageBase=raw.readBigUInt64LE(optional+24),sectionBase=optional+optionalSize;
function offset(rva){if(rva<raw.readUInt32LE(optional+60))return rva;for(let i=0;i<sections;i++){const at=sectionBase+i*40,base=raw.readUInt32LE(at+12),length=Math.max(raw.readUInt32LE(at+8),raw.readUInt32LE(at+16));if(rva>=base&&rva<base+length){const result=raw.readUInt32LE(at+20)+rva-base;if(result<raw.length)return result;}}throw Error('Unmapped export RVA');}
function string(at){const end=raw.indexOf(0,at);if(end<0||end-at>10000)throw Error('Unterminated export name');return raw.toString('ascii',at,end);}
const directoryRva=raw.readUInt32LE(optional+112),directorySize=raw.readUInt32LE(optional+116),directory=offset(directoryRva),count=raw.readUInt32LE(directory+24),functions=offset(raw.readUInt32LE(directory+28)),names=offset(raw.readUInt32LE(directory+32)),ordinals=offset(raw.readUInt32LE(directory+36)),matches=[];
for(let i=0;i<count;i++){const name=string(offset(raw.readUInt32LE(names+i*4)));if(!/BSP|TileData|(?:Build|Create|Init|Set).*(?:Scene|Tile)|(?:Scene|Tile).*(?:Build|Create|Init)/i.test(name))continue;const rva=raw.readUInt32LE(functions+raw.readUInt16LE(ordinals+i*2)*4);matches.push({name,address:'0x'+(imageBase+BigInt(rva)).toString(16),forwarded:rva>=directoryRva&&rva<directoryRva+directorySize});}
console.log(JSON.stringify({source:file,sha256:sha,exportCount:count,matches},null,2));
