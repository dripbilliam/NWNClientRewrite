import fs from 'node:fs/promises';
const output=process.argv.find(arg=>arg.startsWith('--output='))?.slice(9);
if(!output)throw Error('Provide an unused --output path');
const build='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
function encode(value){
 if(typeof value==='number'){const bytes=Buffer.alloc(8);bytes.writeDoubleLE(value);return{$f64:bytes.toString('hex')};}
 if(Array.isArray(value))return value.map(encode);
 if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).map(([key,row])=>[key,encode(row)]));
 return value;
}
const cases={};
for(const [kind,count] of [['playback',2173],['run-clock',474]]){
 const oracle=JSON.parse(await fs.readFile(new URL(`../../backups/animations/native-model-${kind}-observations.json`,import.meta.url)));
 if(oracle.binarySha256!==build||oracle.rows.length!==count)throw Error('Original observation identity changed');
 cases[kind]=oracle;
}
await fs.writeFile(output,JSON.stringify(encode(cases))+'\n',{flag:'wx'});
console.log(JSON.stringify({output,build,cases:2647,numberEncoding:'exact binary64 little-endian hex'}));
