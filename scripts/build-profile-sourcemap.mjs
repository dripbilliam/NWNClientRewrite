// Generate a hidden map in memory without replacing the running/client dist.
// Require identical emitted JS before using it to symbolize a CPU profile.
import fs from 'node:fs/promises';import {build} from 'vite';import {createHash} from 'node:crypto';import {fileURLToPath} from 'node:url';
const root=new URL('../',import.meta.url),dir=new URL('backups/animations/',root),hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const outputName=process.argv[2]??'creation-performance-entry-source-v1';if(!/^[a-z0-9-]+$/.test(outputName))throw Error('Invalid map output name');
const bundle=(await fs.readFile(new URL('dist/index.html',root),'utf8')).match(/src="\.\/assets\/([^"\s]+\.js)"/)?.[1];if(!bundle)throw Error('Current bundle unavailable');
const result=await build({root:fileURLToPath(root),build:{write:false,sourcemap:'hidden'}}),chunks=(Array.isArray(result)?result:[result]).flatMap(r=>r.output).filter(o=>o.type==='chunk'&&o.isEntry);
if(chunks.length!==1)throw Error('Expected one main entry chunk');const chunk=chunks[0],actual=await fs.readFile(new URL('dist/assets/'+bundle,root),'utf8');if(chunk.code!==actual)throw Error('Hidden-map output differs from current production JS');
const mapName=outputName+'.map';await fs.writeFile(new URL(mapName,dir),chunk.map.toString());const proof={bundle,sha256:hash(actual),map:mapName,mapSha256:hash(chunk.map.toString()),sources:chunk.map.sources.length,generatedJsIdentical:true};await fs.writeFile(new URL(outputName+'.json',dir),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify(proof));
