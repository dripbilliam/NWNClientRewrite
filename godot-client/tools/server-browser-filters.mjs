// Modern original Internet-row callback8c6c20: exact full count and literal
// CExoString::Find in module text. The older enumeration path differs; it is
// not silently treated as evidence for this callback's policy.
export const defaultBrowserFilters=()=>({hideEmpty:false,hideFull:false,module:''});
export function browserFilters(value){
 if(!value||Array.isArray(value)||typeof value!=='object'||Object.keys(value).length!==3||Object.keys(value).some(k=>!['hideEmpty','hideFull','module'].includes(k))||typeof value.hideEmpty!=='boolean'||typeof value.hideFull!=='boolean'||typeof value.module!=='string'||value.module.length>1024||/[\x00-\x1f]/.test(value.module))throw Error('Invalid advanced server filters');
 return {hideEmpty:value.hideEmpty,hideFull:value.hideFull,module:value.module};
}
export function matchesBrowserFilters(row,filters,visibility={local:true,server:true,password:true}){
 return !(row.allowLocalVaultCharacters===true&&!visibility.local||row.allowLocalVaultCharacters===false&&!visibility.server||row.passwordRequired&&!visibility.password||filters.hideEmpty&&row.playerCount===0||filters.hideFull&&row.playerCount!==undefined&&row.maximumPlayers!==undefined&&row.playerCount===row.maximumPlayers||filters.module&&!row.moduleName.includes(filters.module));
}
