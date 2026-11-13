'use strict';
// Owned CreationCheck evidence. These values come from the original server's
// exported BIC, separately from the uploaded native draft and host ACK.
const BODY=['ArmorPart_RFoot','BodyPart_LFoot','BodyPart_RShin','BodyPart_LShin','BodyPart_LThigh','BodyPart_RThigh','BodyPart_Pelvis','BodyPart_Torso','BodyPart_Belt','BodyPart_Neck','BodyPart_RFArm','BodyPart_LFArm','BodyPart_RBicep','BodyPart_LBicep','BodyPart_RShoul','BodyPart_LShoul','BodyPart_RHand','BodyPart_LHand','BodyPart_Robe'];
const loc=value=>value?.entries?.[0]?.text??'';
const part=(row,label)=>row?.[('x'+label).slice(0,16)]??row?.[label]??null;
function snapshot(root,structType,fieldTypes=()=>({})){
 const types=fieldTypes(root);
 return {firstName:loc(root.FirstName),lastName:loc(root.LastName),soundset:root.SoundSetFile,deity:root.Deity??'',phenotype:root.Phenotype,head:root.xAppearance_Head??root.Appearance_Head,pets:{familiar:root.FamiliarType??null,familiarName:root.FamiliarName??null,companion:root.CompanionType??null,companionName:root.CompanionName??null,familiarFieldType:types.FamiliarType??null,companionFieldType:types.CompanionType??null},colors:{skin:root.Color_Skin,hair:root.Color_Hair,tattoo1:root.Color_Tattoo1,tattoo2:root.Color_Tattoo2},skinParts:BODY.map(key=>part(root,key)),equipment:(root.Equip_ItemList??[]).map(row=>({slot:structType(row),template:row.TemplateResRef??row.EquippedRes??null,baseItem:row.BaseItem??null,parts:BODY.map(key=>part(row,key.replace('BodyPart_','ArmorPart_'))),colors:['Leather1','Leather2','Cloth1','Cloth2','Metal1','Metal2'].map(key=>row[key+'Color']??null)}))};
}
function compare(expected,actual){
 const a=expected.sourceTailAppearance?.value,i=expected.sourceTailInformation;
 if(!a||!i||!Array.isArray(a.skinParts)||a.skinParts.length!==19||!Array.isArray(a.bodyParts)||a.bodyParts.length!==19)return {success:false,checks:{sourceTailPresent:false}};
 const clothing=(Array.isArray(actual.equipment)?actual.equipment:[]).find(row=>row.slot===2);
 const checks={firstName:actual.firstName===expected.firstName,lastName:actual.lastName===expected.lastName,soundset:actual.soundset===i.soundset,deity:actual.deity===i.deity,phenotype:actual.phenotype===a.phenotype,head:actual.head===a.head,colors:['skin','hair','tattoo1','tattoo2'].every(key=>actual.colors?.[key]===a[key]),skinParts:Array.isArray(actual.skinParts)&&a.skinParts.slice(0,18).every((value,index)=>actual.skinParts[index]===value),equippedOutfit:Boolean(clothing)&&Number.isInteger(clothing.baseItem),outfitBodyParts:Array.isArray(clothing?.parts)&&a.bodyParts.slice(0,18).every((value,index)=>clothing.parts[index]===value)};
 return {success:Object.values(checks).every(Boolean),checks,expectedOutfit:expected.sourceTailAppearance.choice?.resRef??null,actualOutfitTemplate:clothing?.template??null,source:'Original-server exported BIC after received world admission; compared to native source-control accepted values, not upload ACK'};
}
module.exports={snapshot,compare};
