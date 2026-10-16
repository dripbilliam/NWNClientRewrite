import {OBJECT_INVALID} from './game_object_array.js';

// Ownership/state cells of full constructors1404af9c0/1404f9a70/140508d60.
// The base constructor has already allocated the canonical ID. Repository
// allocation and AI registration are observable constructor phases, not loads.
export function initializeWorldObjectOwnership(object,p,requestedId=OBJECT_INVALID){
 if(object.objectType===9){
  object.nativePlaceableActionPoints550??=[[0,0,0],[0,0,0]];
  p.setAILevel(object,0);
  object.nativeRepository??=p.repository(object.id,7,5,35,1);
  object.nativeField504??=0;object.nativeField508??=0;object.nativeCollisionSlot??=-1;
  object.nativeOccupant36c??=OBJECT_INVALID;object.nativeEffectSpellId590??=-1;
  object.nativeBodyBagSource510??=OBJECT_INVALID;object.nativeField514??=0; // ctor1404afd42 qword510.
  object.nativeTrapActive3d4??=1;object.nativeTrapFaction3d8??=0; // ctor1404afc2d qword3d4.
  object.nativeTrapRecoverable3c8??=1;object.nativeTrapType3d0??=255; // ctor1404afbf6/1404afc93.
  object.nativeGroundPile368??=0;object.nativeBodyBag59c??=0; // ctor1404afc9a/1404afd3b.
  object.factionId??=0; // Unloaded compatibility view; Load always writes regular350.
  object.nativeStaticLoadOverride5a4??=Number((requestedId>>>0)===OBJECT_INVALID);
 }else if(object.objectType===14){
  object.nativeStoreClients350??=[];object.nativeStoreEnumeration388??=0;object.nativeStoreEnumeration38a??=0;
  object.nativeStoreName360??={strRef:0xffffffff,entries:[]};object.nativeStoreStrings??={0x308:'',0x318:''};
  object.nativeStoreBuyArrays??={0x398:{values:[],capacity:0},0x3a8:{values:[],capacity:0}}; // ctor1404f9ab2..9b0d.
  object.nativeStoreRepositories??=Array.from({length:5},()=>{const repository=p.repository(object.id,10,10,100,0);repository.expand=1;return repository;});
  p.setAILevel(object,0);
 }else if(object.objectType===12){
  object.nativeAnimationD8??=1;
  const fields=object.nativeMessageFields??={};fields[0x308]??=0;fields[0x30c]??=0;
  object.nativeMapNote310??={strRef:0xffffffff,entries:[]};
  object.nativeName320??={strRef:0xffffffff,entries:[]}; // ctor140508da8..daf.
 }
}

// Placeable Load1404b50b9..50d5 /1404b52a2..52be read BYTEasBOOL/default0.
// HasInventory4f8 is load-owned; the constructor does not initialize that cell.
export function importPlaceableInventoryState(object,data){
 const bool=name=>{const value=data[name]??0;if(!Number.isInteger(value))throw new Error(`Native placeable BYTE ${name} is unavailable`);return Number((value&255)!==0);};
 object.nativeHasInventory4f8=bool('HasInventory');object.nativeField504=bool('DieWhenEmpty');
 object.locked=bool('Locked');
 const active=data.TrapActive??object.nativeTrapActive3d4;if(!Number.isInteger(active))throw new Error('Native placeable TrapActive BYTE is unavailable');
 object.nativeTrapActive3d4=Number((active&255)!==0);
 const faction=data.TrapFaction??0;if(!Number.isInteger(faction))throw new Error('Native placeable TrapFaction DWORD is unavailable');object.nativeTrapFaction3d8=faction>>>0;
}
