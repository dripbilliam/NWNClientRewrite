// Error custom properties are lost when a rejected Promise crosses Electron's
// contextBridge. Carry expected misses as data, then reconstruct in the renderer.
export function networkResourceResult(result,resRef,resourceType){
 if(result.ok)return result.value;
 const error=new Error(result.message);if(result.code==='RESOURCE_NOT_FOUND')Object.assign(error,{code:result.code,resRef,resourceType});throw error;
}
export function rendererNetworkBridge(raw){
 if(!raw)return raw;
 return{...raw,
  getResource:raw.getResourceResult?async(id,ref,type)=>networkResourceResult(await raw.getResourceResult(id,ref,type),ref,type):raw.getResource,
  getTextureResource:raw.getTextureResourceResult?async(id,ref)=>networkResourceResult(await raw.getTextureResourceResult(id,ref),ref,'texture'):raw.getTextureResource,
  lobbyResource:raw.lobbyResourceResult?async(ref,type)=>networkResourceResult(await raw.lobbyResourceResult(ref,type),ref,type):raw.lobbyResource,
  lobbyTextureResource:raw.lobbyTextureResourceResult?async ref=>networkResourceResult(await raw.lobbyTextureResourceResult(ref),ref,'texture'):raw.lobbyTextureResource
 };
}
