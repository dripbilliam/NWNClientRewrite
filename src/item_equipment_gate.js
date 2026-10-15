const required=(p,n)=>{if(typeof p?.[n]!=='function')throw new Error(`Native equipment provider ${n} is unavailable`);return p[n];};
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native equipment ${n} is unavailable`);return v|0;};
const special=i=>i.baseItem>=0&&i.baseItem<48&&(0x800800000010n>>BigInt(i.baseItem)&1n)!==0n;

// CanEquipWeapon1403d19c0. The mutable slot and return codes are distinct:
// 1 free, 2 occupied, 3 conflicts with the other hand. Client equipment
// preview cells are optional only when native client lookup found no preview.
export async function canEquipWeapon(o,item,ref,check,feedback,p){
  const context=await required(p,'weaponClientContext')(o),recipient=context?.actor??o,preview=context?.preview??null;
  if(ref.slot!==16&&ref.slot!==32)return 0;
  const base=required(p,'baseInfo')(item);if(!base)throw new Error('Native equipment base storage is unavailable');
  const size=integer(base.weaponSize,'weapon size')-integer(o.nativeSize718,'creature size');
  const right=required(p,'equipmentSlot')(o,16),left=required(p,'equipmentSlot')(o,32),rightBase=right?required(p,'baseInfo')(right):null;
  const enabled=check===1&&feedback===1;
  const send=code=>required(p,'feedback')(recipient,code);
  const choose=(slot,result)=>{ref.slot=slot;return result;};
  const clear=slot=>{if(preview)preview[slot===16?'rightItemId':'leftItemId']=0x7f000000;};
  const oneHand=b=>b.ranged===0||b.weaponWield===10||b.weaponWield===11;
  const leftOnly=b=>b.weaponWield===7||b.weaponType===0;
  if(size>1){if(enabled)await send(120);return 0;}
  if(size< -2){if(enabled)await send(260);return 0;}
  if(right?.id===item.id&&ref.slot===32){clear(32);return 0;}
  if(left?.id===item.id&&ref.slot===16){clear(16);return 0;}
  if(!right&&!left){
    if(!leftOnly(base)){if(enabled&&oneHand(base))await send(size<1?121:122);return choose(16,1);}
    return choose(32,1);
  }
  if(right&&left){
    if(special(item)){
      if(ref.slot===32)clear(32);ref.slot=16;
      if(enabled)await send(123);
      if(size<1){if(enabled)await send(121);return 2;}
      if(enabled)await send(122);return 3;
    }
    if(base.ranged===0&&size<1){
      if(leftOnly(base)){if(ref.slot===16)clear(16);if(enabled)await send(123);return choose(32,2);}
      if(rightBase.weaponWield===10||rightBase.weaponWield===11){if(ref.slot===32)clear(32);ref.slot=16;}
      if(enabled){await send(123);await send(121);}return 2;
    }
    if(base.ranged!==0&&(base.weaponWield===10||base.weaponWield===11)){
      ref.slot=16;
      const leftBase=required(p,'baseInfo')(left),result=leftOnly(leftBase)?2:3;
      if(enabled){await send(123);await send(121);}return result;
    }
    if(enabled&&size>=1){await send(123);await send(122);}return choose(16,3);
  }
  if(right){
    if(special(item)){
      if(enabled){
        if(ref.slot===32){if(special(right))await send(124);await send(123);}
        if(size>0){await send(122);return choose(16,2);}
        await send(121);
      }
      return choose(16,2);
    }
    if(base.ranged===0){
      if(size>0){if(enabled){await send(123);await send(122);}return choose(16,2);}
      const rightSize=rightBase.weaponSize-o.nativeSize718;
      if(base.weaponType===0){
        if(ref.slot===16)clear(16);ref.slot=32;
        if(oneHand(rightBase)&&rightSize<1)return 1;
        if(enabled)await send(123);return 3;
      }
      if(rightBase.ranged===0&&rightSize<1&&ref.slot===32){if(enabled)await send(121);return 1;}
      if(enabled){await send(123);await send(121);}return choose(16,2);
    }
    if(!enabled||ref.slot===16)return choose(16,2);
    await send(123);
    if(base.weaponWield!==10&&base.weaponWield!==11){await send(122);return choose(16,2);}
    await send(121);return choose(16,2);
  }
  // Only the left slot is occupied.
  if(leftOnly(base)){if(enabled)await send(123);return choose(32,2);}
  if(oneHand(base)&&size<1){if(ref.slot===32)clear(32);if(enabled)await send(121);return choose(16,1);}
  if(enabled){await send(123);if(size>=1)await send(122);}return choose(16,3);
}

// ReadItemsFromGff calls CanEquipItem with (check1,ignore1,feedback1,NULL).
// This entry implements that loading phase only; interactive identification,
// ILR, polymorph and alternate player recipient gates belong to other calls.
export async function canEquipImportedItem(o,item,ref,p){
  return canEquipCreatureItem(o,item,ref,1,1,1,p);
}

// CanEquipItem1403d12c0 with no alternate player recipient. Preserve the
// distinction between check==1/feedback==1 and unrestricted BOOL flags.
export async function canEquipCreatureItem(o,item,ref,check,ignore,feedback,p){
  check=integer(check,'check flag');ignore=integer(ignore,'ignore flag');feedback=integer(feedback,'feedback flag');
  const enabled=check===1&&feedback===1,send=code=>required(p,'feedback')(o,code),reject=async code=>{if(enabled)await send(code);return 0;};
  if(await required(p,'isDM')(o)===0){
    if(check===1&&ignore===0){
      const natural=[16384,32768,65536,131072].includes(ref.slot),pc=integer(o.nativeStatsIsPCb0,'stats PC')===1||integer(o.associateType,'associate type')===1&&!natural;
      if(pc){
        if(integer(item.identified,'identified flag')===0){if(feedback===1)await send(76);return 0;}
        if(await required(p,'itemLevelRestrictions')()!==0&&await required(p,'level')(o)<await required(p,'minimumEquipLevel')(item)){
          if(feedback===1)await send(98);return 0;
        }
      }
    }
    for(const [name,code] of [['alignmentRestrictions',207],['classRestrictions',208],['raceRestrictions',209]])
      if(await required(p,name)(o,item)===0)return reject(code);
    if(ignore===0&&integer(o.nativeEquipmentLock97c,'equipment lock')===1)return 0;
    if(await required(p,'possessedFamiliar')(o)===1&&await required(p,'associatesCanInteract')()===0)return reject(172);
  }
  const base=required(p,'baseInfo')(item);if(!base)throw new Error('Native equipment base storage is unavailable');
  if([14,56,57].includes(item.baseItem))ref.slot=32;
  if(await required(p,'proficient')(o,item,ref.slot)===0)return reject(119);
  let result;
  if(ref.slot===16||ref.slot===32&&![14,56,57].includes(item.baseItem))result=await canEquipWeapon(o,item,ref,check,feedback,p);
  else{
    if(ref.slot===32){
      if(item.baseItem===57&&((o.nativeSize718-1)>>>0)<2)return reject(120);
      const right=p.equipmentSlot(o,16);
      if(right){const b=p.baseInfo(right);if(b.weaponSize-o.nativeSize718>0||b.ranged!==0&&b.weaponWield!==10&&b.weaponWield!==11){if(enabled)await send(123);result=3;}}
    }
    if(result===undefined){
      const existing=p.equipmentSlot(o,ref.slot);
      const cache={2048:'nativeField868',8192:'nativeField86c',4096:'nativeField870'}[ref.slot];
      if(cache&&integer(o[cache],cache)===1)result=0;
      else{result=existing?2:1;if(existing&&enabled)await send(123);}
    }
  }
  return(ref.slot&base.equipableSlots)!==0?result:0;
}
