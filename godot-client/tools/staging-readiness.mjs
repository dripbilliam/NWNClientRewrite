// Compatibility launcher only. One failed optional entity must not discard all
// successfully prepared terrain/actors. The controlled actor remains required.
export function stagingReadiness(snapshot,scope){
 if(!snapshot||snapshot.areaId!==scope.areaId||snapshot.generation!==scope.generation)return{ready:false,reason:'Waiting for the current area'};
 if(snapshot.pending||snapshot.graphicsPending)return{ready:false,reason:`Preparing world models (${snapshot.models??0} ready, ${snapshot.pending??0} pending)`};
 if(!snapshot.controlled)return{ready:false,reason:'Preparing your character model'};
 if(!(snapshot.models>0)||snapshot.phase!=='playing')return{ready:false,reason:'Waiting for world presentation'};
 return{ready:true,failedEntities:[...(snapshot.failures??[])]};
}
