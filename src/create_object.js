import {OBJECT_INVALID} from './game_object_array.js';
import {nativeItemTag} from './item_stack_compare.js';

const kinds=new Map([[1,'creature'],[2,'item'],[32,'waypoint'],[64,'placeable'],[128,'store']]);
const warnings={creature:'Creature',item:'Item',waypoint:'Store',placeable:'Place',store:'Store'};
const f=Math.fround;

// CResRef::operator=14018ded0 -> InitFromCharArray140190d30. The command
// truncates bytes at NUL/16, preserving case. Resource resolution owns folding.
export function objectTemplateResRef(text){
 const bytes=nativeItemTag(text).bytes,out=[];
 for(const byte of bytes){if(byte===0||out.length===16)break;out.push(byte);}
 // Each supported code point encodes to exactly one byte. Retain the input
 // spelling: Node builds may decode the 1252 C1 range differently to Chromium.
 return [...text].slice(0,out.length).join('');
}

// ExecuteCommandCreateObject140513be0..14051470f, after typed VM argument
// pops and before its PushObject. Constructor/load/area/effect boundaries are
// explicit; this owner never executes OnSpawn directly. Its location is an
// owned VM copy, not the caller's original structure.
export async function scriptCreateObject(args,self,p){
 const [type,reference,source]=args,appear=args.length>=4?args[3]|0:0,newTag=args.length>=5?args[4]:'';
 if(!source||!Number.isInteger(source.areaId)||![source.position,source.nativeOrientation].every(v=>Array.isArray(v)&&v.length===3&&v.every(Number.isFinite)))
  throw new Error('Native CreateObject location storage is unavailable');
 const location={areaId:source.areaId>>>0,position:source.position.map(f),nativeOrientation:source.nativeOrientation.map(f)},lookup=await p.getGameObject(location.areaId);
 if(lookup.status!==0)return OBJECT_INVALID;
 const resRef=objectTemplateResRef(reference),kind=kinds.get(type|0);
 if(!kind)return OBJECT_INVALID;
 const object=await p.construct(kind);
 if(await p.loadTemplate(kind,object,resRef,newTag)===0){
  await p.warning(`CNWSVirtualMachineCommands::ExecuteCommandCreateObject()  Invalid ${warnings[kind]} file`);
  if(object)await p.destroy(object);
  return OBJECT_INVALID;
 }
 if(kind==='creature'){
  await p.orientation(object,location.nativeOrientation);
  const point=[...location.position];
  if(await p.safeLocation(await p.asArea(lookup.object),[...location.position],20,object.nativePathInfo,1,point)!==0)
   location.position=[...point];
  // Height and placement consume the output even when safe-location fails.
  point[2]=f(await p.height(await p.asArea(lookup.object),[...point]));
  if(appear!==0){
   const effect=await p.createEffect(1);effect.type=81;
   await p.setCreator(effect,self>>>0);await p.applyEffect(object,effect,0,0);
  }
  await p.addToArea(kind,object,await p.asArea(lookup.object),...point,0,1);
 }else{
  await p.position(object,[...location.position],0);
  if(kind==='placeable')await p.placeableOrientation(object,location.nativeOrientation);
  else await p.orientation(object,location.nativeOrientation);
  await p.addToArea(kind,object,await p.asArea(lookup.object),...location.position,1);
  if(kind==='placeable'&&(object.trapped|0)!==0)await p.appendTrap(await p.asArea(lookup.object),object.id);
  if(kind==='waypoint'&&(object.nativeMessageFields[0x308]|0)!==0){
   const point=await p.nativePosition(object),message=await p.message(),clients=await p.clients();
   for(const client of clients){
    const player=await p.clientObject(client);
    if(player&&(player.areaId>>>0)===(object.areaId>>>0))
     await p.mapPin(message,client,object.id,[...point],object.nativeMapNote310,object.nativeMessageFields[0x30c]|0);
   }
  }
 }
 return object.id>>>0;
}
