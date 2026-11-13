import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)),project=path.resolve(here,'../../..'),label=process.argv[2];
if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Overlay label required');
const overlay=path.join(project,'.cache/native-render-gap/particles',label),output=path.join(overlay,'kernel-project');
if(fs.existsSync(output))throw Error('Previous compiler project retained');fs.mkdirSync(output);
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),pins=[];
function copy(directory){for(const entry of fs.readdirSync(path.join(project,directory),{withFileTypes:true})){if(entry.isSymbolicLink())throw Error('No reparse inputs');const relative=directory+'/'+entry.name;if(entry.isDirectory()){copy(relative);continue;}if(!entry.isFile())throw Error('Unsupported input');const original=fs.readFileSync(path.join(project,relative)),source=fs.existsSync(path.join(overlay,relative))?path.join(overlay,relative):path.join(project,relative),bytes=fs.readFileSync(source),dest=path.join(output,relative);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes);pins.push({relative,source,originalSha256:hash(original),sha256:hash(bytes),bytes:bytes.length});}}
copy('native');
const added='native/particle_scene_boundary.hpp',bytes=fs.readFileSync(path.join(overlay,added));fs.writeFileSync(path.join(output,added),bytes);pins.push({relative:added,source:path.join(overlay,added),originalSha256:null,sha256:hash(bytes),bytes:bytes.length});
fs.writeFileSync(path.join(overlay,'kernel-source-pins.json'),JSON.stringify({version:1,project:output,pins,engineStarts:0,compilerInvoked:false,scope:'Complete frozen current native-directory inputs plus isolated boundary overlay; no build or acceptance'},null,2)+'\n');console.log(JSON.stringify({project:output,files:pins.length,bytes:pins.reduce((a,b)=>a+b.bytes,0)}));
