import {openLocalModule} from './local-module.mjs';
import {RESOURCE_TYPE,decodeResourceText} from '../src/resource_archive.js';
import {parseNcs,parseScriptApi} from '../src/ncs.js';
const install='../FullDecomp/NwnRootInstall',resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`);
const source=decodeResourceText(await resolver.getResource('nwscript',RESOURCE_TYPE.NSS)),api=parseScriptApi(source);
console.log(JSON.stringify({commands:[api[417],api[504]],cameraModes:[...source.matchAll(/int\s+(CAMERA_MODE_\w+)\s*=\s*(\d+)/g)].map(m=>({name:m[1],value:Number(m[2])}))}));
for(const name of ['nw_od_feedback8','m1q0apaveslg03']){const p=parseNcs(await resolver.getResource(name,RESOURCE_TYPE.NCS),name);console.log(name,JSON.stringify([...p.instructions.values()].filter(i=>[4,5].includes(i.op))));}
