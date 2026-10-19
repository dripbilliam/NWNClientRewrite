// Complete appearance branch of CopyItemAndModify140512a79..140513295.
// Native warnings identify original source lines. Failed validation can either
// retain an unchanged copy or discard it; those outcomes are deliberately distinct.
export async function modifyCopiedItemAppearance(destination,source,type,index,value,p){
 const info=p.baseInfo(source);if(!info)throw new Error('Native CopyItemAndModify base storage is unavailable');
 let resourceType=3;
 if(info.category===5&&type===3){index=0;type=0;resourceType=6;}
 else if(info.category===4&&source.baseItem===80&&info.modelType===1&&type===0){index=0;resourceType=6;}
 if(type===1){
  if(index>2)await p.warning(0x66d6);if(((value-1)>>>0)>8)await p.warning(0x66d7);
  if(index<3&&((value-1)>>>0)<9&&(index&255)<3)destination.modelParts[index&255]=(Math.trunc((source.modelParts[index&255]&65535)/10)*10+value)&65535;
 }else if(type===2){
  if(index>2){await p.warning(0x66e4);return true;}
  const original=(index&255)<3?source.modelParts[index&255]&65535:0,model=(original+Math.imul((value-Math.trunc(original/10))|0,10))|0;
  let modelRef=await p.modelReference(info,index&255,model&65535,109);const iconRef=await p.iconReference(info,index&255,model&65535,109);
  if([20,25,26,49,65,101,104].includes(source.baseItem))modelRef=info.defaultModel;
  if(!await p.exists(modelRef,2002)||!await p.exists(iconRef,3))return false;
  if((index&255)<3)destination.modelParts[index&255]=model&65535;
 }else if(type===3){
  if(index>18)await p.warning(0x6708);const table=await p.partTable(index>>>0);
  if(!table){await p.warning(0x671a);return false;}
  const count=p.rowCount(table);if(value>=count)await p.warning(0x670e);
  if(index<19&&value<count){if((index&255)<19)destination.armorParts[index&255]=value&65535;destination.nativeBaseArmor35c=await p.armor(destination);await p.weight(destination);}
 }else if(type===4){
  if(index<6){if(value<176){if((index&255)<6)destination.colors[index&255]=value&255;}else await p.warning(0x6726);}
  else if(value<176||value===255){const offset=(index-6)|0,part=Math.trunc(offset/6);await p.partColor(destination,(offset-Math.imul(part,6))&255,part&255,value&255);}
  else await p.warning(0x6730);
 }else if(type===0){
  let variant=value&65535;
  if(source.baseItem===80&&info.modelType===1){const table=await p.cloakTable();variant=0;if(!table)await p.warning(0x126);else variant=(await p.cloakIcon(table,value))&65535;}
  const icon=await p.iconReference(info,0,variant,109);
  if(!await p.exists(icon,resourceType)&&!await p.exists(info.defaultIcon,resourceType))return false;
  destination.modelParts[0]=value&65535;
 }
 return true;
}
