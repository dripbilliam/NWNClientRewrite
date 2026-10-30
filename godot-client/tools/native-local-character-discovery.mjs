import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {workshopContent} from '../../electron/workshop_content.mjs';
// Raw filesystem catalog for the existing upload service, not a BIC/UI parser.
// Original705f10 enumerates install, profile and Workshop aliases. Resolve the
// LOCALVAULT alias through the first enabled Workshop match before the profile;
// its81M resource tier overrides the installed80M tier. Keep enumeration rows.
async function files(directory){
 try{const info=await fs.lstat(directory);if(!info.isDirectory()||info.isSymbolicLink())return[];return(await fs.readdir(directory,{withFileTypes:true})).filter(e=>e.isFile()&&/^[^/\\:\x00-\x1f]+\.bic$/i.test(e.name)).map(e=>e.name).sort();}
 catch(error){if(error.code==='ENOENT')return[];throw error;}
}
export async function discoverLocalCharacterFiles({install,profileDirectory,modsDirectory='',disabledMods=[]}){
 const descriptors=[{source:'installed',directory:path.join(install,'data/lcv')},{source:'local',directory:path.join(profileDirectory,'localvault')}];
 for(const directory of await workshopContent(modsDirectory,{disabledMods}).directories('localvault'))descriptors.push({source:'workshop',directory});
 const groups=[];
 for(const descriptor of descriptors)groups.push({...descriptor,directory:path.resolve(descriptor.directory),files:await files(descriptor.directory)});
 const selected=new Map();
 for(const group of [...groups.filter(v=>v.source==='workshop'),...groups.filter(v=>v.source==='local'),...groups.filter(v=>v.source==='installed')])for(const filename of group.files){const name=filename.toLowerCase();if(!selected.has(name))selected.set(name,{file:path.join(group.directory,filename),storageSource:group.source});}
 const rows=[];
 for(const group of groups)for(const filename of group.files){const file=path.join(group.directory,filename),resolved=selected.get(filename.toLowerCase());rows.push({key:group.source==='installed'?'installed:'+filename:group.source==='local'?'local:'+filename:'workshop:'+createHash('sha256').update(file.toLowerCase()).digest('hex'),label:filename.slice(0,-4),source:group.source,catalogStem:filename.slice(0,-4),...resolved});}
 return{roots:groups.map(v=>v.directory),rows};
}
