const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native corpse ${name} is unavailable`);return value|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native corpse provider ${n} is unavailable`);return p[n];};
// Bounded ReadStatsFromGff14040ff47..1404100da and1404104d8..504.
// DecayTime is unsigned and has a5000ms floor. Lootable bodies override the
// imported raiseable/selectable flags; body-bag data retains BYTE storage.
export function importCreatureCorpseFields(actor,data){
  const bool=(name,otherwise)=>Number((integer(data[name]??otherwise,name)&255)!==0),decay=integer(data.DecayTime??5000,'decay time')>>>0;
  actor.nativeNoPermDeath8bc=bool('NoPermDeath',0);actor.nativeLootable4e8=bool('Lootable',0);actor.nativeDecayTime4ec=Math.max(decay,5000);
  actor.nativeDestroyableF0=bool('IsDestroyable',1);actor.nativeRaiseableF4=bool('IsRaiseable',1);
  actor.nativeSelectableWhenDeadF8=bool('DeadSelectable',actor.nativeStatsIsPCb0===1?1:0);
  if(actor.nativeLootable4e8===1){actor.nativeRaiseableF4=0;actor.nativeSelectableWhenDeadF8=1;}
  actor.nativeBodyBag8a8=integer(data.BodyBag??actor.nativeBodyBag8a8??0,'body bag')&255;
}
// GetItemCount1403916b0: first FOURTEEN physical slots, direct repository
// nodes (no bag recursion), optional +448 filter and one count for any gold.
export function creatureCorpseItemCount(actor,filter,p){
  filter=integer(filter,'item filter');let count=0;
  const admit=item=>{if(item&&(filter===0||integer(item.droppable,'droppable')!==0))count=(count+1)>>>0;};
  if(required(p,'hasEquipment')(actor))for(let slot=1,n=0;n<14;n++,slot=(slot<<1)|(slot>>>31))admit(required(p,'equipment')(actor,slot));
  const repo=required(p,'repository')(actor);for(let node=repo?.head??null;node;node=node.next)admit(required(p,'repositoryItem')(repo,node));
  if(integer(actor.nativeGold898,'gold')!==0)count=(count+1)>>>0;return count;
}
// ExecuteCommandGetLootable14052b590 and SetLootable1405436e0. Raw INTs
// remain raw; only living, non-dying NPCs without possession may be changed.
export function getCreatureLootable(actor){return actor?.objectType===5?integer(actor.nativeLootable4e8,'lootable'):0;}
export async function setCreatureLootable(actor,value,p){
  value=integer(value,'lootable input');if(actor?.objectType!==5)return;
  if(await required(p,'dead')(actor)!==0||await required(p,'dying')(actor)!==0||integer(actor.nativeField89c,'PC field')!==0||await required(p,'possessed')(actor)!==0)return;
  actor.nativeLootable4e8=value;
}

// GetBodyBagAppearance140390230 /1404b3b80. Physical table rows and
// different fallback column names for creatures/placeables are intentional.
export async function corpseBagAppearance(actor,p){
  if(actor.objectType!==5&&actor.objectType!==9)throw new Error('Native body-bag appearance owner is unavailable');
  if(actor.objectType===5&&integer(actor.nativeLootable4e8,'lootable')===1)return 157;
  const bag=integer(actor.objectType===5?actor.nativeBodyBag8a8:actor.nativeBodyBag59c,'body bag')&255;
  let entry=await required(p,'entry')('bodybag',bag,'Appearance');
  if(entry.found)return integer(entry.value,'selected bag appearance')&65535;
  entry=await p.entry('appearance',integer(required(p,'appearance')(actor),'appearance')&65535,actor.objectType===5?'Body_Bag':'BodyBag');
  const row=entry.found?integer(entry.value,'fallback body bag'):0;
  entry=await p.entry('bodybag',row,'Appearance');return entry.found?integer(entry.value,'fallback bag appearance')&65535:13;
}
// Native script getter14051fa50. No table query is performed.
export function getBodyBag(actor){
  return actor?.objectType===5?integer(actor.nativeBodyBag8a8,'body bag')&255:actor?.objectType===9?integer(actor.nativeBodyBag59c,'body bag')&255:-1;
}
// SetBodyBag14053e2f0 validates the requested raw INT physical row BEFORE
// object lookup, then narrows only the successful write to BYTE.
export async function setBodyBag(objectId,value,p){
  value=integer(value,'requested body bag');const entry=await required(p,'entry')('bodybag',value,'Appearance');if(!entry.found)return;
  const creature=required(p,'creature')(objectId);if(creature){creature.nativeBodyBag8a8=value&255;return;}
  const placeable=required(p,'placeable')(objectId);if(placeable)placeable.nativeBodyBag59c=value&255;
}
// Placeable ctor1404afd3b / ReadFromGff1404b527a..52a2.
export function importPlaceableBodyBag(actor,data){actor.nativeBodyBag59c=integer(data.BodyBag??actor.nativeBodyBag59c,'placeable body bag')&255;}
