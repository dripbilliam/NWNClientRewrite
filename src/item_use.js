const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native item-use ${name} is unavailable`);return v|0;};
const required=(p,name)=>{if(typeof p?.[name]!=='function')throw new Error(`Native item-use provider ${name} is unavailable`);return p[name];};

// CanUseItem1403d2410..1403d2821. Eligibility is not possession/acquisition
// or script casting. Guards are ordered as native, including post-failure
// polymorph and player/identification queries.
export async function canUseItem(o,item,ignoreIdentification,p){
  if(!item)return 0;
  if(integer(await required(p,'isDM')(o),'DM flag')!==0||(integer(o.associateType,'associate type')&65535)===8)return 1;
  let result=1;
  for(const name of ['alignmentRestrictions','classRestrictions','raceRestrictions']){
    if(integer(await required(p,name)(o,item),name)===0){result=0;break;}
  }
  const base=integer(await required(p,'baseItem')(item),'base item');
  if(result!==0&&base===75)result=integer(await required(p,'scrollSchoolAllowed')(o,item),'scroll school');
  if(integer(o.nativeField97c,'polymorph field97c')===1&&base!==49&&base!==104)result=0;
  if(integer(o.nativeField89c,'creature PC field89c')!==0||(integer(o.associateType,'associate type')&65535)===3&&integer(await required(p,'controlledByPlayer')(o),'player controller')!==0){
    if(integer(await required(p,'itemLevelRestrictions')(),'server item-level restrictions')!==0&&
      (integer(await required(p,'level')(o),'creature level')&255)<(integer(await required(p,'minimumEquipLevel')(item),'minimum equip level')&255))return 0;
    if(integer(ignoreIdentification,'ignore identification')===0&&integer(await required(p,'identified')(item),'identified flag')===0)return 0;
  }
  if(result===1){
    const info=await required(p,'baseInfo')(item);
    if(!info)throw new Error('Native CanUseItem reads unavailable base-item storage');
    if((integer(info.weaponWield,'weapon wield')&255)!==1&&(integer(info.weaponType,'weapon type')&255)!==0&&base!==36&&base!==78&&
      (((integer(info.weaponSize,'weapon size')&255)-integer(o.nativeSize718,'creature size')+2)>>>0)>3)result=0;
    for(let slot=0;slot<18;slot++)if((integer(info.equipableSlots,'equipable slots')&(1<<slot))!==0){
      if(integer(await required(p,'proficient')(o,item,1<<slot),'proficiency')===0)return 0;
      break;
    }
    if(result===1&&base===57&&((integer(o.nativeSize718,'creature size')-1)>>>0)<2)result=0;
  }
  return result;
}
