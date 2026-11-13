import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)),project=path.resolve(here,'../../..'),label=process.argv[2];
if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Private label required');
const stage=path.join(project,'.cache/native-render-gap/particles',label),base=path.join(project,'.cache/native-render-gap/particles/hot-parameters-c'),original=JSON.parse(fs.readFileSync(path.join(base,'test-project-receipt.json'))),build=JSON.parse(fs.readFileSync(path.join(stage,'kernel-build/build-receipt.json'))),output=path.join(stage,'test-project');
if(fs.existsSync(output)||!build.success||build.exit!==0)throw Error('Fresh successful private build required');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),pins=[];
function write(relative,bytes,source){const file=path.join(output,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);pins.push({relative,source,sha256:hash(bytes)});}
for(const pin of original.pins){if(pin.relative==='.cache/native-kernel/nwn-particle-kernel.dll')continue;const source=path.join(original.project,pin.relative),bytes=fs.readFileSync(source);if(hash(bytes)!==pin.sha256)throw Error('Frozen functional input drift');write(pin.relative,bytes,source);}
const binary=fs.readFileSync(build.binary);if(hash(binary)!==build.binarySha256)throw Error('Private binary drift');write('.cache/native-kernel/nwn-particle-kernel.dll',binary,build.binary);
const fixture=path.join(here,'resident_text_test.gd');write('tests/native_render_gap_resident_text_test.gd',fs.readFileSync(fixture),fixture);
fs.mkdirSync(path.join(stage,'backups/animations'),{recursive:true});
for(const name of ['native-emitter-bucket-v1.json','native-emitter-admission-observations-v2.json','chunk-childless-radius-a.json'])fs.copyFileSync(path.join(base,'backups/animations',name),path.join(stage,'backups/animations',name));
fs.writeFileSync(path.join(stage,'test-project-receipt.json'),JSON.stringify({project:output,pins,binarySha256:build.binarySha256,scope:'Exact prior accepted functional closure plus private string type/lifetime oracle; no runtime acceptance yet'},null,2)+'\n');
console.log(JSON.stringify({project:output,pins:pins.length,binarySha256:build.binarySha256,mapSha256:build.mapSha256}));
