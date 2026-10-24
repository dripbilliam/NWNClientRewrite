// Complete selection flow805d20. This consumes only the client's cosmetic CRT
// draws; the server has already supplied the attack result and duration.
export function clientAttackSound(actor,record,phase,p){
 if(!record)return false;const target=p.object(record.targetId);if(!target)return false;
 const result=record.result&255,ranged=(record.ranged|0)===1;
 const category=()=>p.animationCategory(target,p.currentAnimation(target));
 const appearanceSound=o=>p.int('appearance',p.appearance(o),'SoundAppType').value;
 const held=()=>p.equipped(actor,record.weaponAttackType===2?32:[1,6].includes(record.weaponAttackType)?16:null);
 const materialFallback=index=>{const item=held();return item?p.weaponMaterial(item):index;};
 const sound=(row,column,delay=0)=>p.play(actor,p.string('weaponsounds',row,column).value,delay);
 const miss=()=>{
  const index=p.int('appearancesndset',appearanceSound(actor),'MissIndex'),row=index.found?index.value:materialFallback(index.value),column='Miss'+p.random()%2,quarter=(record.duration&65535)>>>2,draw=p.random();
  if(quarter===0)throw new Error('Native attack sound delay divides by zero');
  sound(row,column,quarter+draw%quarter);return true;
 };
 if(phase===1){if(ranged||(!(result<11&&(0x4ab>>>result&1))&&category()===0))return miss();return true;}
 if(ranged)return miss();
 const sourceSound=appearanceSound(actor),animation=p.currentAnimation(actor),column=({200:'WeapTypeL',263:'WeapTypeL',201:'WeapTypeR',264:'WeapTypeR',202:'WeapTypeS',265:'WeapTypeS',204:'WeapTypeClsLw',203:'WeapTypeClsH',205:'WeapTypeRch'})[animation]??'WeapTypeL';
 let weapon=p.int('appearancesndset',sourceSound,column).value;if(weapon===0)weapon=materialFallback(weapon);
 if(weapon===19&&result!==4)sound(weapon,'Miss'+p.random()%2);
 if(result===3||result===10)sound(weapon,'Critical0');
 if((result===2||result===4)&&category()!==0){sound(weapon,'Parry0');return true;}
 let armor='';
 if(target.objectType===5){
  armor=p.armorOverride(target);
  if(!armor){const soundType=appearanceSound(target),custom=p.string('appearancesndset',soundType,'Custom');if(custom.found){p.play(actor,custom.value,0);return true;}
   armor=p.string('appearancesndset',soundType,'ArmorType').value;
   if(!armor){const item=p.equipped(target,2);armor=p.string('defaultacsounds',item?p.armorIndex(item):0,'ArmorType').value;}
  }
 }else if(target.objectType===10){const type=p.doorTypes(target),row=p.int(type.doorType===0?'genericdoors':'doortypes',type.doorType===0?type.genericType:type.doorType,'SoundAppType').value;armor=p.string('placeableobjsnds',row,'ArmorType').value;}
 else if(target.objectType===9){const row=p.int('placeables',p.appearance(target),'SoundAppType').value;armor=p.string('placeableobjsnds',row,'ArmorType').value;}
 sound(weapon,armor+p.random()%2);return true;
}
