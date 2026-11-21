import {openLocalModule} from './local-module.mjs';
import {RESOURCE_TYPE} from '../src/resource_archive.js';
import {parseModel} from '../src/model_parser.js';
const install='../FullDecomp/NwnRootInstall',r=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`);
const bytes=await r.getResource('tic01_e01_01',RESOURCE_TYPE.MDL),d=new DataView(bytes),u=o=>d.getUint32(o,true),base=12;
const parsed=parseModel(bytes);
for(const n of parsed.nodes.filter(n=>n.verts.length))console.log(JSON.stringify({name:n.name,parent:n.parent,position:n.position,orientation:n.orientation,render:n.render,bitmap:n.bitmap,min:[0,1,2].map(a=>Math.min(...n.verts.map(v=>v[a]))),max:[0,1,2].map(a=>Math.max(...n.verts.map(v=>v[a])))}));
const read=p=>{const s=base+p,name=new TextDecoder().decode(new Uint8Array(bytes,s+32,32)).split('\0')[0],flags=u(s+108);let c=s+112;if(flags&2)c+=92;if(flags&4)c+=216;if(flags&16)c+=68;
 if(flags&32){const fields=[0x1ec,0x1f8,0x204,0x210].map(o=>[o.toString(16),u(s+o),u(s+o+4)]);console.log(name,JSON.stringify(fields));if(name==='Object49')for(const o of [0x1ec,0x1f8,0x204,0x210]){const p=base+u(s+o);console.log(o.toString(16),Array.from({length:Math.min(15,u(s+o+4))},(_,i)=>u(p+i*4)));}}
 for(let i=0;i<u(s+76);i++)read(u(base+u(s+72)+i*4));};read(u(84));
