export const referenceModelName=node=>node.reference?.model??node.properties?.refmodel;

// Data prefetch only. Runtime instances are created separately at the original
// CreateReferenceObjects boundary. A shared resource never shares Part state.
export async function loadModelReferenceAssets(name,{load,release}){
 const cache=new Map(),owned=new Set();
 const read=async(name,ancestors)=>{
  const key=String(name).split('\0')[0].toLowerCase();
  if(!key)throw new Error('Referenced model name is unavailable');
  if(ancestors.includes(key))throw new Error(`Referenced model cycle: ${[...ancestors,key].join(' -> ')}`);
  if(cache.has(key))return cache.get(key);
  const pending=(async()=>{
   const asset=await load(key);owned.add(asset);asset.references=new Map();
   for(const node of asset.model.nodes)if(node.type==='reference'){
    const child=referenceModelName(node);
    if(typeof child!=='string')throw new Error(`Referenced model name is unavailable at ${key}/${node.name}`);
    asset.references.set(child.toLowerCase(),await read(child,[...ancestors,key]));
   }
   return asset;
  })();cache.set(key,pending);return pending;
 };
 try{return await read(name,[]);}catch(error){for(const asset of owned)release(asset);throw error;}
}

export function releaseModelReferenceAssets(asset,release,seen=new Set()){
 if(seen.has(asset))return;seen.add(asset);
 for(const child of asset.references?.values()??[])releaseModelReferenceAssets(child,release,seen);
 release(asset);
}
