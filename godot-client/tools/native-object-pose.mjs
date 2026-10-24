import {networkTriggerSurface} from '../../src/network_trigger.js';
export function nativeObjectPose(object){
 // Trigger vertices are already world-space, with the native +0.05 pick
 // offset. The ordinary object position is not their rendering origin.
 if(object.objectType===7){const surface=networkTriggerSurface(object);return surface?{position:surface.center,rotation:0}:null;}
 const s=object.replicated??object.staticState??object.lightState,p=s?.position;if(!p)return null;
 const o=s.orientation,v=Array.isArray(o)?o:o?.vector;
 return{position:[p[0],p[2],-p[1]],rotation:v?-Math.atan2(v[0],v[1]):(o?.yaw??0)*Math.PI/180};
}
