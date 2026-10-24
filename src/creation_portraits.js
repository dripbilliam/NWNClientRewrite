import {RESOURCE_TYPE} from './resource_archive.js';
import {portraitCandidates} from './portrait_resource.js';

// Native9d04a0: only a medium file introduces a custom base into the chooser.
export const customCreationPortraits=names=>[...new Set(names.filter(name=>/m$/i.test(name)).map(name=>name.slice(0,-1).toLowerCase()))];

// CGuiPortraitSelect add1409d0cd0 resolves size3, then requires TGA/DDS Exists.
// Catalog checks read no image bytes and belong to the active resource owner.
export async function availableCreationPortraits(resolver,refs){
 if(!Array.isArray(refs)||refs.length>32768||refs.some(ref=>typeof ref!=='string'||!/^[^\x00-\x1f/\\:]{0,32}$/.test(ref)))throw new Error('Invalid character creation portrait references');
 if(typeof resolver?.hasResource!=='function')throw new Error('Character creation portrait catalog is unavailable');
 const available=[];
 for(const ref of new Set(refs))for(const candidate of portraitCandidates(ref,3)){
  if(await resolver.hasResource(candidate,RESOURCE_TYPE.TGA)||await resolver.hasResource(candidate,RESOURCE_TYPE.DDS)){available.push(ref);break;}
 }
 return available;
}
