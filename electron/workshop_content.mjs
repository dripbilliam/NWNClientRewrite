import fs from 'node:fs/promises';import path from 'node:path';
// Snapshot one explicitly selected content root and its enabled local mods.
// The resource context mounts their HAKs globally below selected server content.
export function workshopContent(directory,{disabledMods=[]}={}){
 let items;const aliases=new Set(['portraits','hak','tlk','modules','override','ambient','music']);
 async function roots(){if(!items)items=(async()=>{if(!directory)return[];let entries;try{entries=await fs.readdir(directory,{withFileTypes:true});}catch(error){if(error.code==='ENOENT')return[];throw error;}const names=entries.filter(e=>e.isDirectory()).map(e=>e.name),installed=names.filter(n=>/^\d+$/.test(n));let order=installed;
  // Steam's installed-item section supplies stable local membership/order;
  // pending downloads/details do not admit another item's loose directories.
  try{const text=await fs.readFile(path.join(directory,'../../appworkshop_704450.acf'),'utf8'),start=text.indexOf('"WorkshopItemsInstalled"');if(start>=0){const open=text.indexOf('{',start);let depth=0,end=open;for(;end<text.length;end++){if(text[end]==='{')depth++;if(text[end]==='}'&&--depth===0)break;}const section=text.slice(open+1,end);order=[...section.matchAll(/^\s*"(\d+)"\s*\r?\n\s*\{/gm)].map(m=>m[1]).filter(id=>installed.includes(id));}}catch(error){if(error.code!=='ENOENT')throw error;}
  return[...(names.some(n=>aliases.has(n.toLowerCase()))?[path.resolve(directory)]:[]),...order.map(id=>path.resolve(directory,id))];})();return items;}
 const id=root=>path.resolve(root)===path.resolve(directory)?'local':path.basename(root),enabled=root=>!disabledMods.includes(id(root));
 return{async mods(){const result=[];for(const root of await roots()){const content={};for(const alias of aliases){try{const files=await fs.readdir(path.join(root,alias),{withFileTypes:true});content[alias]=files.filter(e=>e.isFile()).length;if(alias==='hak')content.firstHak=files.find(e=>e.isFile()&&/\.hak$/i.test(e.name))?.name;}catch(error){if(error.code!=='ENOENT')throw error;}}result.push({id:id(root),directory:root,enabled:enabled(root),label:content.firstHak?content.firstHak.replace(/\.hak$/i,''):(content.portraits?'Portraits':'Workshop mod'),content});}return result;},async directories(alias){if(!aliases.has(alias))throw Error('Unsupported Workshop resource directory');const result=[];for(const root of await roots()){if(!enabled(root))continue;const p=path.join(root,alias);try{if((await fs.stat(p)).isDirectory())result.push(p);}catch(error){if(error.code!=='ENOENT')throw error;}}return result;}};
}
