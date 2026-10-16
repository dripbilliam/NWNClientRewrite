import {placeableMessageLight} from './area_message_pack.js';

// Placeable ctor1404afd17 clears dirty598 and starts light-on594 at1.
// Appearance32c is populated by Load; no unknown constructor value is invented.
export function initializePlaceableMessageState(object){
 const fields=object.nativeMessageFields??={};fields[0x594]??=1;fields[0x598]??=0;
}
// Appearance1404b4f7e..1404b4fa1 reads DWORD/default0 then stores WORD.
// LightState1404b52ef..1404b53e1 defaults through GetLightIsOn and, when
// changed, queries LightColor again before committing state/dirty. A failed
// query's numeric fallback is not confused with successful table status.
export async function loadPlaceableMessageState(object,data,p){
 const fields=object.nativeMessageFields;
 if(!fields||!Number.isInteger(fields[0x594]))throw new Error('Native placeable light constructor state is unavailable');
 const appearance=data.Appearance??0;if(!Number.isInteger(appearance))throw new Error('Native placeable Appearance DWORD is unavailable');fields[0x32c]=appearance&65535;
 const fallback=await placeableMessageLight(object,p),input=data.LightState??fallback;
 if(!Number.isInteger(input))throw new Error('Native placeable LightState BYTE is unavailable');
 const wanted=Number((input&255)!==0);
 if(wanted!==fields[0x594]&&(await p.lightColor(fields[0x32c],'LightColor')).status!==0){fields[0x598]=1;fields[0x594]=wanted;}
}
