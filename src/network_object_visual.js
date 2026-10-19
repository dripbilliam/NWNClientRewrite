import {satisfiesNativeBuild} from './network_build.js';
import {readObjectVisualTransform} from './network_object_updates.js';
const INVALID=0x7f000000;
// Area effects have their own CNWCVisualEffect owner (7da460), not a creature
// dummy or the object-visual P/B extension. Sender4cea60, receiver76da53.
export function readNetworkAreaVisual(r,build){
 const visualId=r.readWord(),position=[r.readFloat(1,32),r.readFloat(1,32),r.readFloat(1,32)];
 return{kind:'area-visual',visualId,position,visualTransform:satisfiesNativeBuild(build,{number:8193,revision:14,postfix:0})?readObjectVisualTransform(r,build):{keys:[],entries:[]}};
}
// Sender4d9640 -> receiver7857f0, server5/3. The extended source/parts/
// source-position fields exist only for exact Type_FD P/B or visual999.
export function readNetworkObjectVisual(r,build,p){
 const targetId=r.readObjectIdClient(),visualId=r.readWord(),position=[r.readFloat(1,32),r.readFloat(1,32),r.readFloat(1,32)],beam=p.isBeam?.(visualId);
 if(typeof beam!=='boolean')throw new Error('Native visual classification is unavailable');
 const value={kind:'object-visual',targetId,visualId,position,sourceId:INVALID,flag:0,missMode:0,duration:0};
 if(beam||visualId===999){value.sourceId=r.readObjectIdClient();value.flag=r.readByte();value.missMode=r.readByte();value.sourcePosition=[r.readFloat(1,32),r.readFloat(1,32),r.readFloat(1,32)];if(targetId===INVALID)value.duration=r.readFloat(1,32);}
 value.visualTransform=satisfiesNativeBuild(build,{number:8193,revision:14,postfix:0})?readObjectVisualTransform(r,build):{keys:[],entries:[]};return value;
}
