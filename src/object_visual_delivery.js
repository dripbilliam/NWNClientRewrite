import {visualMilliseconds} from './visual_phase_control.js';
const INVALID=0x7f000000,f=Math.fround,validType=object=>object&&[5,9,10].includes(object.objectType);

// Decoded routing from client receiver1407857f0..14078644b. Packet reads,
// negotiated transform-map import and dummy allocation/registration remain
// explicit lower owners. Normal effects discard source/part/duration fields;
// exact Type_FD P/B (or native999) take the extended source/target path.
export function deliverObjectVisual(message,p){
 const visualId=message.visualId&65535,targetId=message.targetId>>>0;
 const kind=String(p.visualType(visualId).value).split('\0')[0],special=kind==='P'||kind==='B'||visualId===999;
 const point=message.position.map(f);let actor,sourceId=INVALID,sourcePart=0,targetPart=0,instant=1;
 if(!special){
  actor=targetId===INVALID?p.createDummy('point',point,10000):p.object(targetId);
  if(!actor)return 0;
 }else{
  sourceId=message.sourceId>>>0;sourcePart=message.flag&255;targetPart=message.missMode&255;
  const duration=targetId===INVALID?f(message.duration):0,lifetime=duration===0?6000:visualMilliseconds(duration);
  if(!validType(p.object(sourceId))){
   if(!Array.isArray(message.sourcePosition))throw new Error('Native extended visual source position is unavailable');
   if(!p.createDummy('source',message.sourcePosition.map(f),lifetime))return 0;
  }
  const target=p.object(targetId);actor=validType(target)?p.renderObject(target):p.createDummy('target',point,lifetime);
  if(!actor)return 0;
  instant=duration===0?1:0;
 }
 p.add(actor,{visualId,sourceId,bodyPart:0,transform:structuredClone(message.transform),
  delivery:{instant,sourcePart,targetPart,point:special&&targetId!==INVALID?[0,0,0]:point}});
 // The receiver ignores AddVisual's return value after successful routing.
 return 1;
}

// Local server-to-client semantic adapter. The real sender1404d9640 supplies
// the live target position when present, and its source position for P/B/999.
// Snapshot those at emission so async model I/O cannot change packet semantics.
export function snapshotObjectVisual(message,objects){
 const result=structuredClone(message),target=objects.get(message.targetId),source=objects.get(message.sourceId);
 const position=o=>[o.position[0],-o.position[2],o.position[1]].map(f);
 if(target)result.position=position(target);
 if(source)result.sourcePosition=position(source);
 return result;
}
