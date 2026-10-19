import {OBJECT_INVALID} from './game_object_array.js';
import {readNativeGff} from './native_gff_fields.js';
import {getGffFieldTypes} from './gff.js';
const integer=v=>{if(!Number.isInteger(v))throw new Error('Native henchman INT storage is unavailable');return v|0;};

// Module ctor140478922 defaults1. LoadModuleStart140480dc6..def uses the
// signed INT GFF reader1770, default1; unlike the script setter it does NOT clamp.
export function importModuleHenchmen(module,data){
  module.nativeMaxHenchmen3fc=getGffFieldTypes(data)?readNativeGff(data,'Mod_MaxHenchmen',5,1).value:integer(data?.Mod_MaxHenchmen??1);
}
export function getMaxHenchmen(module){return module?integer(module.nativeMaxHenchmen3fc):1;}
export function setMaxHenchmen(module,value){const n=Math.max(1,Math.min(100,integer(value)));if(module)module.nativeMaxHenchmen3fc=n;}

// ExecuteCommandAssociateAccess140510b50..ceb. The raw wrapper leaves the
// second ID INVALID unless argc==2; the compiler normally supplies defaults.
// Add rejects PC/possessed-familiar/DM targets. Remove requires type1+master,
// clears activity1, then combat invisibility, then calls the existing owner.
export async function scriptAssociateAccess(command,args,p){
  const masterId=(args[0]??OBJECT_INVALID)>>>0,id=args.length===2?args[1]>>>0:OBJECT_INVALID;
  const master=p.creature(masterId);if(!master)return;
  if(command===365){
    const target=p.creature(id);if(!target)return;
    if(integer(target.nativeField89c)!==0||await p.possessed(target)!==0||await p.dm(target)!==0)return;
    await p.add(master,id);
  }else if(command===366){
    const target=p.creature(id);if(!target||(target.associateType&65535)!==1||(target.masterId>>>0)!==masterId)return;
    await p.activity(target,1,0);await p.removeInvisibility(target);await p.remove(master,id);
  }else if(command===503){if((await p.associate(master,4,1)>>>0)===id)await p.remove(master,id);}
}
