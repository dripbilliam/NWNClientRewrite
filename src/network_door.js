// CNWSDoor::SetOpenState140423230 and client creation796dd0 map the
// replicated animation WORD to the client BYTE19c used by door clicks.
export const networkDoorState=animation=>({22:0,50:1,51:2,72:3})[animation]??null;
// Common update79c050 only writes BYTE19c for22/50/51; other animation
// updates preserve it. Creation796dd0 also initializes dead72 ->3.
export function applyNetworkDoorOpenState(previous,animation,creation){
 const next=networkDoorState(animation);return next!==null&&(creation||next!==3)?next:previous;
}
export const networkDoorClickState=object=>object.replicated?.doorOpenState??networkDoorState(object.replicated?.animation);
