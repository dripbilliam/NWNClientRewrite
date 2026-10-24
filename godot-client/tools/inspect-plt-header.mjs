import fs from 'node:fs/promises';import path from 'node:path';import {createHash} from 'node:crypto';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const name=process.argv.find(arg=>arg.startsWith('--resource='))?.slice(11),report=process.argv.find(arg=>arg.startsWith('--report='))?.slice(9);
if(!/^[a-z0-9_]{1,16}$/.test(name??'')||!/^[a-z0-9-]+\.json$/.test(report??''))throw Error('Provide --resource and an unused --report name');
const resolver=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')}),resource=await resolver.getResource(name,6),bytes=resource instanceof ArrayBuffer?new Uint8Array(resource):new Uint8Array(resource.buffer,resource.byteOffset,resource.byteLength),view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
if(bytes.byteLength<24)throw Error('PLT header truncated');
const width=view.getUint32(16,true),height=view.getUint32(20,true);if(width*height>16_777_216||24+width*height*2>bytes.byteLength)throw Error('PLT pixel range invalid');
const histogram={};for(let index=0;index<width*height;index++){const layer=bytes[25+index*2];histogram[layer]=(histogram[layer]??0)+1;}
const result={scope:'Read-only installed PLT metadata; no original payload copied',resource:name,sha256:createHash('sha256').update(bytes).digest('hex'),bytes:bytes.byteLength,header8:view.getUint32(8,true),header12:view.getUint32(12,true),width,height,paletteHistogram:histogram};
await fs.writeFile(path.resolve('godot-client/reports',report),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
