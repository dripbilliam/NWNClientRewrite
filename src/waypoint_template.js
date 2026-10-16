import {nativeItemTag} from './item_stack_compare.js';
import {normalizeOrientation} from './combat_lifecycle.js';
const f=Math.fround,empty=()=>({strRef:0xffffffff,entries:[]});

// Full LoadWaypoint140509f80..14050a462. GFF reads, native string/localized
// assignments and UUID loading remain explicit lower-owner boundaries.
// All vectors passed to providers are native XYZ, not renderer coordinates.
export async function loadWaypointData(object,newTag,p){
 const tag=newTag!==null&&nativeItemTag(newTag).length!==0?newTag:(await p.read('string','Tag','')).value;
 await p.setTag(object,tag);
 await p.localized(object,0x320,(await p.read('localized','LocalizedName',empty())).value);
 const point=[],vector=[];
 for(const name of ['XPosition','YPosition','ZPosition'])point.push(f((await p.read('float',name,0)).value));
 for(const name of ['XOrientation','YOrientation','ZOrientation'])vector.push(f((await p.read('float',name,0)).value));
 const squared=f(f(f(vector[1]*vector[1])+f(vector[0]*vector[0]))+f(vector[2]*vector[2]));
 let orientation=vector;
 if(squared!==1){
  const result=normalizeOrientation([vector[0],vector[2],f(-vector[1])]);
  orientation=[result[0],f(-result[2]),result[1]];
 }
 await p.position(object,point,0);await p.orientation(object,orientation);
 const has=await p.read('bool','HasMapNote',0);
 if((has.status|0)!==0&&(has.value|0)!==0){
  const enabled=await p.read('bool','MapNoteEnabled',0),note=await p.read('localized','MapNote',empty());
  if((note.status|0)!==0){
   object.nativeMessageFields[0x308]=has.value|0;object.nativeMessageFields[0x30c]=enabled.value|0;
   await p.localized(object,0x310,note.value);
  }
 }
 await p.setTemplate(object,(await p.read('resref','TemplateResRef','')).value);
 await p.addTag(object);
 await p.loadUUID(object);
 return 1;
}
