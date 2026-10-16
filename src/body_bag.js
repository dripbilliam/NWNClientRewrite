import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native body bag ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native body bag provider ${n} is unavailable`);return p[n];};

// Full LoadBodyBag1404b4080..4648. Field offsets are retained where a name
// has not been established. This synthetic load has no UTP resource lookup.
export async function loadBodyBag(bag,appearance,p){
 appearance=integer(appearance,'appearance')&65535;
 // Native AsTAG14016ac40 filters the literal "Body Bag" to "BodyBag".
 await required(p,'resref')(bag,0x568,'');await required(p,'tag')(bag,'BodyBag');
 await required(p,'localized')(bag,0x308,{strRef:0xffffffff,entries:[]});
 for(const [offset,value,width]of [[0x3a4,0,4],[0x350,1,4],[0x3bc,1,4],[0x3c0,1,4],[0x3b8,15,1],[0x3b0,0,1],[0x3b4,0,4],[0x3c4,1,4],[0x3d0,0,1],[0xfc,0,4],[0x3a8,18,1]])await required(p,'field')(bag,offset,value,width);
 await required(p,'string')(bag,0x380,'');
 for(const [offset,value,width]of [[0x32c,appearance,2],[0xe4,15,4],[0xe0,15,4],[0x370,5,1],[0x4e0,16,2],[0x4e2,0,1],[0x500,0,4],[0x378,0,4],[0x264,1,4],[0x4f8,1,4],[0x3a0,0,4],[0x3a9,0,1]])await p.field(bag,offset,value,width);
 await required(p,'portrait')(bag,'PO_PLC_B04_');await p.resref(bag,0x354,'');
 await p.localized(bag,0x330,{strRef:0xffffffff,entries:[]});
 for(const offset of [0x580,0x480,0x3e0,0x3f0,0x400,0x410,0x420,0x430,0x440,0x450,0x460,0x470,0x490,0x4a0,0x4b0,0x4c0,0x4d0])await p.string(bag,offset,'');
 await p.field(bag,0x5a0,0,4);await required(p,'animation')(bag,0);
 await required(p,'addTag')(bag);return 1;
}

// Full SpawnBodyBag14049c170..c4ae. A lootable corpse is linked to the bag
// before loading; failed loading retains that native stale link. Area lookup
// repeats after transfer, and transferred count is deliberately ignored.
export async function spawnBodyBag(source,p){
 if(![5,9].includes(source.objectType))return;
 const creature=required(p,'asCreature')(source),placeable=required(p,'asPlaceable')(source);if(!creature&&!placeable)return;
 const areaObject=await required(p,'object')(source.areaId>>>0),area=areaObject?required(p,'asArea')(areaObject):null;
 const fallback=async()=>{if(creature&&integer(creature.nativeLootable4e8,'lootable')===1)await required(p,'enqueue')(0,integer(creature.nativeDecayTime4ec,'decay')>>>0,creature.id,creature.id,11,null);};
 if(!area){await fallback();return;}
 if(creature&&await required(p,'creatureCount')(creature,1)===0){await fallback();return;}
 if(placeable&&await required(p,'placeableCount')(placeable,0)===0){await fallback();return;}
 const bag=await required(p,'construct')(OBJECT_INVALID);if(!bag)return;
 let appearance=0;
 if(creature){appearance=(await required(p,'appearance')(creature))&65535;
  if(integer(creature.nativeLootable4e8,'lootable')===1){creature.nativeBodyBagId4f0=bag.id>>>0;bag.nativeBodyBagSource510=creature.id>>>0;}
 }else if(placeable)appearance=(await p.appearance(placeable))&65535;
 if(await required(p,'load')(bag,appearance)===0){await required(p,'destroy')(bag,1);return;}
 await required(p,'transfer')(bag,source.id,1);
 const payload=await required(p,'payload')();if(!payload){await p.destroy(bag,1);return;}
 await required(p,'localized')(bag,0x308,{strRef:0x9cac,entries:[]});
 await p.localized(bag,0x330,await required(p,'sourceName')(source));
 payload.id=bag.id>>>0;payload.position=[...required(p,'position')(source)];
 for(const [offset,value]of [[0x514,1],[0x504,1],[0xfc,1],[0xe0,12],[0xe4,12]])await required(p,'field')(bag,offset,value,4);
 const currentAreaObject=await p.object(source.areaId>>>0),currentArea=currentAreaObject?p.asArea(currentAreaObject):null;
 if(!currentArea)throw new Error('Native body-bag area became null before event scheduling');
 await p.enqueue(0,1000,source.id,currentArea.id,17,payload);
}

// Area EventHandler event17 at14035dba0..dc26. A stale/non-placeable ID
// skips insertion; the payload is released even when lookup fails.
export async function receiveBodyBagAreaEvent(area,payload,p){
 if(!payload)return;
 const result=await required(p,'lookup')(payload.id>>>0);
 if(result.status===0){const bag=required(p,'asPlaceable')(result.object);if(bag)await required(p,'addToArea')(bag,area,...payload.position,1);}
 await required(p,'releasePayload')(payload);
}
