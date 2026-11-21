// Root may run this against a composed PRIVATE trial after reviewing changes.
// It never writes to the shared project and preserves the previous descriptor.
import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
import {buildDescriptor} from './processor-descriptor.mjs';import {digest} from './processor-graph.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),target=path.resolve(process.argv[2]??''),cache=path.resolve(project,'.cache');
const relative=path.relative(cache,target);if(!relative||relative.startsWith('..')||path.isAbsolute(relative)||!fs.existsSync(path.join(target,'project.godot')))throw Error('Explicit private .cache Godot project required');
const descriptor=path.join(target,'systems/native_data/scoped_processor_graph.json'),backup=descriptor+'.before-regenerate';
if(fs.existsSync(backup))throw Error('Existing descriptor backup preserved');
const generated=buildDescriptor(target),bytes=Buffer.from(JSON.stringify(generated.descriptor,null,2)+'\n');
if(fs.existsSync(descriptor))fs.copyFileSync(descriptor,backup);fs.writeFileSync(descriptor,bytes);
console.log(JSON.stringify({target,descriptor,sha256:digest(bytes),backup:fs.existsSync(backup)?backup:null,inventory:generated.inventoryCount,globalClasses:generated.globalClasses,graphs:Object.values(generated.descriptor.graphs).map(v=>({kind:v.kind,files:v.files.length,libraries:v.libraries.length})),sharedFilesChanged:0,serverConnections:0}));
