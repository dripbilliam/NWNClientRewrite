// Independent read-only diagnostic expectations. Not imported by game rendering.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {parseGff} from '../../src/gff.js';
import {localCharacterFile} from './native-local-character-files.mjs';
const arg=name=>process.argv.find(v=>v.startsWith('--'+name+'='))?.slice(name.length+3);
const install=arg('install'),output=arg('output');if(!install||!output)throw Error('Explicit source and new output required');
const directory=path.join(install,'data/lcv'),rows=[];
const name=v=>v?.entries?.find(e=>e.languageId===0)?.text??v?.entries?.[0]?.text??'';
for(const filename of(await fs.readdir(directory)).filter(v=>v.toLowerCase().endsWith('.bic')).sort()){
 const file=path.join(directory,filename),bytes=await fs.readFile(file),root=parseGff(bytes,'BIC ').root;
 rows.push({key:'installed:'+filename,label:'transport fallback only',source:'installed',catalogStem:filename.slice(0,-4),nativeFile:await localCharacterFile(file),expected:{name:[name(root.FirstName),name(root.LastName)].filter(Boolean).join(' '),classes:root.ClassList.map(row=>({id:row.Class,level:row.ClassLevel})),portrait:root.PortraitId??65535,portraitRef:root.Portrait??''}});
}
await fs.writeFile(output,JSON.stringify({directory,rows,sourceDigests:rows.map(row=>row.nativeFile.sha256),fixtureSourceSha256:createHash('sha256').update(await fs.readFile(new URL(import.meta.url))).digest('hex'),publicConnections:0},null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({output,rows:rows.length}));
