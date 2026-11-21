// Independent read-only diagnostics. Never imported by the game renderer.
import fs from 'node:fs/promises';import path from 'node:path';import {createHash} from 'node:crypto';
import {parseGff,getGffFieldTypes,getGffStructType} from '../../src/gff.js';
const arg=name=>process.argv.find(v=>v.startsWith('--'+name+'='))?.slice(name.length+3);
const install=arg('install'),output=arg('output');if(!install||!output)throw Error('Explicit read-only install and new report required');
const directory=path.join(install,'data/lcv'),rows=[];
const numeric=node=>Object.fromEntries(Object.entries(node).filter(([,value])=>typeof value==='number'));
for(const name of(await fs.readdir(directory)).filter(n=>/\.bic$/i.test(n)).sort()){
 const file=path.join(directory,name),bytes=await fs.readFile(file),root=parseGff(bytes,'BIC ').root;
 rows.push({file,sha256:createHash('sha256').update(bytes).digest('hex'),fields:numeric(root),types:getGffFieldTypes(root),equipment:(root.Equip_ItemList??[]).map(item=>({slot:getGffStructType(item),fields:numeric(item),types:getGffFieldTypes(item)}))});
}
await fs.writeFile(output,JSON.stringify({rows,publicConnections:0,scope:'Independent raw GFF numeric fields/types/physical equipment slots only, not a rendered appearance oracle'},null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({rows:rows.length,output}));
