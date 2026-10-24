// GetCompressedRaster1400f56c0..0f584f: format ties are KTX, DDS,
// native16-bit resource2059, TGA. A higher table class wins first.
// Exists reports the winning table TYPE for each format, not its priority.
export function nativeCompressedTextureType(locations){
 for(const location of [2,5,3,1])for(const type of [2073,2033,2059,3])
  if(locations[type]===location)return [2073,2033].includes(type)?type:null;
 return null;
}

export async function resolveTextureResource(resolver,name){
 if(resolver.getTextureResource)return resolver.getTextureResource(name);
 // In-memory/legacy consumers lack catalog provenance. Keep this fallback
 // bounded; production ResourceResolver and IPC use the native catalog path.
 for(const [extension,type]of [['dds',2033],['tga',3],['plt',6]]){
  try{return{extension,type,bytes:await resolver.getResource(name,type)};}
  catch(error){if(error.code&&error.code!=='RESOURCE_NOT_FOUND')throw error;}
 }
 throw Object.assign(new Error(`Texture ${name} is unavailable`),{code:'RESOURCE_NOT_FOUND'});
}

export function textureResourceFile(name,resource){
 return{name:`${name}.${resource.extension}`,arrayBuffer:async()=>resource.bytes};
}
