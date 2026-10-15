import {openLocalModule} from './local-module.mjs';
import {decodeResourceText} from '../src/resource_archive.js';
const root='../FullDecomp/NwnRootInstall',r=await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`);
const text=decodeResourceText(await r.getResource('nwscript',2009));
console.log(JSON.stringify([...text.matchAll(/int\s+(EVENT_SCRIPT_\w*(?:LOCK|UNLOCK)\w*)\s*=\s*(\d+)/g)].map(m=>({name:m[1],value:Number(m[2])}))));
