// Received transport metadata for the new private native level-up clone.
// No rule calculation or canonical snapshot/actor mutation belongs here.
export function nativeLevelUpDraftContext(actor){
 const stats=actor?.inventoryStats;
 const value=stats&&Object.hasOwn(stats,'field9c')?stats.field9c:null;
 return{baseFortitude:typeof value==='number'&&Number.isInteger(value)&&value>=-128&&value<=127?value:null};
}
