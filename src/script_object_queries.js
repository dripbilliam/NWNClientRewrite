import {OBJECT_INVALID} from './game_object_array.js';
import {normalizeOrientation} from './combat_lifecycle.js';
import {scriptFloatToInt} from './script_scalar.js';
import {nativeAtan2f,nativeCosf,nativeSinf} from './native_math.js';

// Door GetOpenState1404207f0. The query refreshes the cached BYTE42c only
// for four recognized animations; field498 zero returns3 without cache write.
export function nativeDoorOpenState(door){
  if(!Number.isInteger(door.nativeDoorField498))throw new Error('Native door field498 is unavailable');
  if(door.nativeDoorField498===0)return 3;
  if(!Number.isInteger(door.nativeAnimationD8))throw new Error('Native door animation is unavailable');
  const state=new Map([[22,0],[50,1],[51,2],[72,3]]).get(door.nativeAnimationD8|0);
  if(state!==undefined)door.animationState=state;
  if(!Number.isInteger(door.animationState))throw new Error('Native door cached state42c is unavailable');
  return door.animationState&255;
}
// GetIsOpen140527490: door cast twice before considering placeable; a
// placeable is open exactly when its common animation DWORDd8 equals75.
export async function scriptIsOpen(id,p){
  if(!Number.isInteger(id))throw new Error('Native GetIsOpen object ID is unavailable');
  const object=await p.object(id>>>0);if(!object)return 0;
  if(p.asDoor(object)){const door=p.asDoor(object);if(!door)throw new Error('Native GetIsOpen dereferences null repeated door cast');const state=await p.openState(door);if(!Number.isInteger(state))throw new Error('Native door open-state return is unavailable');return Number((state&255)!==0);}
  if(!p.asPlaceable(object))return 0;
  const placeable=p.asPlaceable(object);if(!placeable)throw new Error('Native GetIsOpen dereferences null repeated placeable cast');
  if(!Number.isInteger(placeable.nativeAnimationD8))throw new Error('Native GetIsOpen placeable animation is unavailable');return Number((placeable.nativeAnimationD8|0)===75);
}

// ExecuteCommandGetAssociateType14051f470 reads WORD908 only when the
// actual master ID8fc is valid. A type alone does not make an associate.
export function scriptAssociateType(actor){
  if(actor?.objectType!==5||(actor.masterId>>>0)===OBJECT_INVALID)return 0;
  if(!Number.isInteger(actor.masterId)||!Number.isInteger(actor.associateType))throw new Error('Native associate query fields are unavailable');
  return actor.associateType&65535;
}
// ExecuteCommandGetSittingCreature14052ff70 returns the raw placeable
// occupant ID36c; it does not validate the referenced creature again.
export function scriptSittingCreature(actor){
  if(actor?.objectType!==9)return OBJECT_INVALID;
  if(!Number.isInteger(actor.nativeOccupant36c))throw new Error('Native placeable occupant ID is unavailable');
  return actor.nativeOccupant36c>>>0;
}
// ExecuteCommandGetFacing140523a70 uses original (unnormalized) XY for
// atan2f, normalized Y only for its360-degree adjustment, FLOAT constants
// and CVTTSS2SI after adding0.5. Missing/non-world objects return0, not-1.
export function scriptObjectFacing(actor){
  let degrees=-1;const f=Math.fround;
  if(actor&&actor.objectType>4){
    if(!Array.isArray(actor.orientation)||actor.orientation.length!==3||!actor.orientation.every(Number.isFinite))throw new Error('Native object orientation is unavailable');
    const [x,z,negativeY]=actor.orientation.map(f),y=f(-negativeY);
    degrees=f(nativeAtan2f(y,x)*57.2957763671875);
    const normalized=normalizeOrientation([x,z,negativeY]);
    if(f(-normalized[2])<0)degrees=f(degrees+360);
  }
  return f(scriptFloatToInt(f(degrees+.5)));
}

// GIT LoadCreatures140360815..140360898 stores the raw FLOAT vector;
// LoadWaypoint14050a149..14050a21d normalizes it first. In both cases
// fields default to0. The renderer basis is(nativeX,nativeZ,-nativeY).
export function authoredVectorOrientation(entry,normalize=false){
  const f=Math.fround,vector=[entry.XOrientation??0,entry.ZOrientation??0,-(entry.YOrientation??0)].map(f);
  if(!vector.every(Number.isFinite))throw new Error('Native authored orientation exceptional input is unavailable');
  return normalize?normalizeOrientation(vector):vector;
}
// DoorLoad140360a85..140360b9e and PlaceableLoad140361b8b..
//140361cac construct a half-angle quaternion and rotate native(0,1,0).
// Preserve each FLOAT operation; using plain sin(Bearing) differs in bits.
export function authoredBearingOrientation(entry){
  const f=Math.fround,half=f(f(entry.Bearing??0)*.5),sine=nativeSinf(half),cosine=nativeCosf(half);
  const x=f(f(0-f(cosine*sine))*2),y=f(1-f(f(sine*sine)*2));
  const vector=[x,0,f(-y)],squared=f(f(f(y*y)+f(x*x))+0);
  return squared<=f(1e-8)?[0,0,-1]:normalizeOrientation(vector);
}
