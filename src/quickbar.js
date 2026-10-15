import {OBJECT_INVALID} from './game_object_array.js';
export const QUICKBAR_SIZE=36;
export const QUICKBAR_TYPE=Object.freeze({EMPTY:0,ITEM:1,SPELL:2,SKILL:3,FEAT:4,SPELL_LIKE:44});
const u32=n=>n>>>0,byte=n=>n&255;
// InitializeQuickbar140396ab0: 36 zeroed 0x60-byte records. This is a
// field representation of creature +4e0, not a network/pointer serialization.
export function emptyQuickbarButton(){return {type:0,itemId:0,secondaryItemId:0,classIndex:0,intParam:0,metamagic:0,domainLevel:0,resRef:'',commandLabel:'',commandLine:'',toolTip:'',associateType:0,associateId:0};}
export function initializeQuickbar(actor){actor.nativeQuickbar4e0=Array.from({length:QUICKBAR_SIZE},emptyQuickbarButton);return actor.nativeQuickbar4e0;}
export function getQuickbarButton(actor,index){return Number.isInteger(index)&&index>=0&&index<36?actor.nativeQuickbar4e0?.[index]??null:null;}
export function setQuickbarButton(actor,index,value){
  const old=getQuickbarButton(actor,index);if(!old)return false;
  // Native setters change only the fields owned by their type; clear keeps
  // old object IDs, but resets the type and INT parameter.
  const type=byte(value?.type??0);old.type=type;
  if(type===0){old.intParam=0;return true;}
  if(type===1){old.itemId=u32(value.itemId);old.secondaryItemId=u32(value.secondaryItemId??OBJECT_INVALID);old.intParam=value.intParam??0xff00ff;}
  else {old.intParam=(value.intParam??0)|0;
    if(type===2){old.classIndex=byte(value.classIndex??0);old.metamagic=byte(value.metamagic??0);old.domainLevel=byte(value.domainLevel??0);}
    if(type===44)old.domainLevel=byte(value.domainLevel??0);
    for(const k of ['resRef','commandLabel','commandLine','toolTip','associateType','associateId'])if(value[k]!==undefined)old[k]=value[k];
  }
  return true;
}
const noParams=new Set([0,6,7,19,20,21,22,23,24,25,35,36,38,40,41]);
const ints=new Set([3,4,8,27,28,31,32,33,34,37,42,43,45,46,47,48]);
function itemAt(actor,slot,x,y,containerX,containerY,p){
  if(u32(slot??0xffffffff)!==0xffffffff)return p.equipped(actor,u32(slot));
  let repository=actor.nativeRepository;
  if(byte(containerX??255)!==255&&byte(containerY??255)!==255){const container=p.at(repository,byte(containerX),byte(containerY));repository=container?.nativeRepository;}
  return repository?p.at(repository,byte(x??255),byte(y??255)):null;
}
// LoadQuickButtons140398b90: item identities are restored from equipment
// slots/repository coordinates, NEVER by treating saved IDs as current IDs.
export function loadQuickbar(actor,list,p){
  const buttons=initializeQuickbar(actor);
  if(!Array.isArray(list))return buttons;
  for(const [i,row]of list.slice(0,36).entries()){
    const type=byte(row.QBObjectType??0),b=buttons[i];b.type=type;
    if(noParams.has(type))continue;
    if(type===1||type===9){b.type=1;
      const item=itemAt(actor,row.QBItemInvSlot,row.QBItemReposX,row.QBItemReposY,row.QBContReposX,row.QBContReposY,p);
      const second=itemAt(actor,row.QBSecItemInvSlot,row.QBSecItemReposX,row.QBSecItemReposY,255,255,p);
      b.itemId=item?.id??0;b.secondaryItemId=second?.id??0;
      b.intParam=(byte(row.QBCastPropIndex??255)|(byte(row.QBCastSubPropIdx??255)<<16))|0;
      if(item&&(item.activeProperties?.length??0)<1)b.intParam=0xff00ff;
    }else if(type===2){b.intParam=(row.QBINTParam1??0)|0;b.classIndex=byte(row.QBMultiClass??0);b.metamagic=byte(row.QBMetaType??0);b.domainLevel=byte(row.QBDomainLevel??0);}
    else if(ints.has(type)){b.intParam=(row.QBINTParam1??0)|0;if(type===4&&b.intParam>=1000&&b.intParam<1004)b.intParam+=64000;}
    else if(type===44){b.intParam=(row.QBINTParam1??0)|0;b.domainLevel=byte(row.QBDomainLevel??0);}
    else if(type===18){b.commandLabel=row.QBCommandLabel??'';b.commandLine=row.QBCommandLine??'';}
    else if([11,12,13,14,15,16,17,29,30].includes(type)){b.resRef=row.QBResRef??'';b.toolTip=row.QBToolTip??'';}
    else if(type===39){b.intParam=(row.QBINTParam1??0)|0;b.associateType=(row.QBAssociateType??0)&65535;b.associateId=u32(row.QBAssociate??OBJECT_INVALID);}
    else if(type===10){
      const legacy={2:[3,10],3:[4,28],4:[4,19],6:[4,204],7:[4,30],8:[4,389],9:[4,390],11:[4,425],12:[4,947]};const v=legacy[row.QBINTParam1];
      if(v){b.type=v[0];b.intParam=v[1];}else b.intParam=(row.QBINTParam1??0)|0;
    }else{b.type=0;p.unsupported?.(i,row,'Unknown saved quickbar type');}
  }
  return buttons;
}
export function removeQuickbarItem(actor,id){
  const removed=[];for(let i=0;i<36;i++){const b=getQuickbarButton(actor,i);if(b?.type===1&&(b.itemId===id||b.secondaryItemId===id)){setQuickbarButton(actor,i,null);removed.push(i);}}return removed;
}
// SaveQuickButtons1403a1da0: retain native QBList field names and inventory
// coordinates, allowing a new session to allocate different canonical IDs.
export function saveQuickbar(actor,p){
  return (actor.nativeQuickbar4e0??[]).map(b=>{
    const r={QBObjectType:b.type};
    if(b.type===1){
      for(const [id,prefix]of [[b.itemId,'QB'],[b.secondaryItemId,'QBSec']]){
        const item=p.object(id);if(!item)continue;
        r[`${prefix}ItemInvSlot`]=p.slot(actor,item)??0xffffffff;r[`${prefix}ItemReposX`]=byte(item.repositoryX??255);r[`${prefix}ItemReposY`]=byte(item.repositoryY??255);
        if(prefix==='QB'){const owner=p.object(item.ownerId);r.QBContReposX=owner?.objectType===6?byte(owner.repositoryX):255;r.QBContReposY=owner?.objectType===6?byte(owner.repositoryY):255;}
      }
      r.QBCastPropIndex=b.intParam&255;r.QBCastSubPropIdx=(b.intParam>>>16)&255;
    }else if(b.type===2){Object.assign(r,{QBINTParam1:b.intParam,QBMultiClass:b.classIndex,QBMetaType:b.metamagic,QBDomainLevel:b.domainLevel});}
    else if(ints.has(b.type)||b.type===10||b.type===44){r.QBINTParam1=b.intParam;if(b.type===44)r.QBDomainLevel=b.domainLevel;}
    else if(b.type===18){r.QBCommandLabel=b.commandLabel;r.QBCommandLine=b.commandLine;}
    else if(b.type===39){r.QBINTParam1=b.intParam;r.QBAssociateType=b.associateType;r.QBAssociate=b.associateId;}
    else if(b.resRef){r.QBResRef=b.resRef;r.QBToolTip=b.toolTip;}
    return r;
  });
}
export function quickbarRequest(actor,b,registry,targetId=OBJECT_INVALID){
  if(!b||b.type===0)return null;
  const common={actorId:actor.id,areaId:actor.areaId,targetId};
  if(b.type===1){const item=registry.get(b.itemId);if(!item||item.objectType!==6)return null;return {...common,action:'item.use',itemId:item.id,secondaryItemId:b.secondaryItemId,propertyIndex:b.intParam&65535,subPropertyIndex:(b.intParam>>>16)&65535};}
  if(b.type===2)return {...common,action:'spell.cast',classIndex:b.classIndex,spellId:b.intParam,metamagic:b.metamagic,domainLevel:b.domainLevel};
  if(b.type===3)return {...common,action:'skill.use',skillId:b.intParam};
  if(b.type===4)return {...common,action:'feat.use',featId:b.intParam};
  if(b.type===44)return {...common,action:'spellLike.use',spellId:b.intParam,domainLevel:b.domainLevel};
  return {...common,action:'quickbar.special',button:{...b}};
}
