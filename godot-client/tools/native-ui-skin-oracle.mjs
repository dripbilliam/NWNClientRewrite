// Offline original-skin oracle. Raw TOML/font/image data remains installed.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
import {parseNuiSkin} from '../../src/nui_skin.js';
const run=process.argv.find(a=>a.startsWith('--run='))?.slice(6)??'native-ui-skin-oracle-v1';if(!/^[a-z0-9-]+$/.test(run))throw Error('Invalid oracle name');
const install=path.resolve('../FullDecomp/NwnRootInstall'),resolver=await openServerResourceContext({install,module:path.join(install,'data/nwm/Prelude.nwm')}),hash=b=>createHash('sha256').update(b).digest('hex');
const raw=Buffer.from(await resolver.getResource('nui_skin',2076)),skin=parseNuiSkin(raw.toString('utf8'));
const fonts=[];for(const name of new Set([...skin.fonts.map(f=>f.resref),'fnt_default','fnt_maintext'])){const bytes=Buffer.from(await resolver.getResource(name,2074));fonts.push({name,sha256:hash(bytes),bytes:bytes.length,tag:bytes.subarray(0,4).toString('hex'),tables:bytes.readUInt16BE(4)});}
const images=[...new Set(Object.values(skin.tables).flatMap(Object.values).filter(v=>typeof v==='string'&&/^[a-z0-9_]{1,32}$/i.test(v)))];
const keys=Object.entries(skin.tables).flatMap(([table,values])=>Object.entries(values).map(([key,value])=>({table,key,value})));
await fs.writeFile('godot-client/reports/'+run+'.json',JSON.stringify({install,scope:'Offline original skin scalar/font hash oracle only; original assets stay installed',skinSha256:hash(raw),keys,fontSpecs:skin.fonts,fonts,images,sources:{'src/nui_skin.js':hash(await fs.readFile('src/nui_skin.js'))}},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({tables:Object.keys(skin.tables).length,scalars:keys.length,fontSpecs:skin.fonts,fonts,images:images.length}));
