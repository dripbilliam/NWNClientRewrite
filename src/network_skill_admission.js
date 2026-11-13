// Compact native-received cache projection, not server stats or a rules result.
// Original PlayerUpdate7b4f70 I/mask2 replaces stats+e0; InventoryStats7b2740
// mask128 only ORs TRUE received flags into that same field. No rank inference.
import {DM_PERMISSION_SOURCE} from './network_dm_permission.js';
const U32=0xffffffff;
const uint=value=>Number.isInteger(value)&&value>=0&&value<=U32;
const flag=value=>value===true||value===false||value===0||value===1;
const nativeOverride=value=>typeof value==='boolean'||Number.isInteger(value)&&value>=-2147483648&&value<=2147483647;
export const NATIVE_SKILL_SOURCE='native_received_skill_admission';
export function validNativeSkillAdmission(value){
 return value!==null&&typeof value==='object'&&!Array.isArray(value)&&value.version===1&&value.source===NATIVE_SKILL_SOURCE&&uint(value.knownMask)&&typeof value.playerUpdateSeen==='boolean'&&typeof value.inventoryUpdateSeen==='boolean'&&(value.knownMask===0?value.mask===null:uint(value.mask)&&((value.mask&~value.knownMask)>>>0)===0)&&(Object.hasOwn(value,'override')===Object.hasOwn(value,'overrideSource'))&&(!Object.hasOwn(value,'override')||value.override===0&&value.overrideSource===DM_PERMISSION_SOURCE);
}
export function mergeNativeSkillAdmission(current,changes,source){
 if(current!==undefined&&current!==null&&!validNativeSkillAdmission(current))throw Error('Invalid native skill-admission view');
 if(!changes||typeof changes!=='object'||Array.isArray(changes)||!['player','inventory','permission'].includes(source))throw Error('Invalid native skill-admission input');
 const value=current?{...current}:{version:1,source:NATIVE_SKILL_SOURCE,mask:null,knownMask:0,playerUpdateSeen:false,inventoryUpdateSeen:false};
 let bits=value.mask??0,known=value.knownMask;
 if(source==='player'&&Object.hasOwn(changes,'skillFlags')){
  if(!uint(changes.skillFlags))throw Error('Native player skill flags must be a DWORD');
  bits=changes.skillFlags;known=U32;value.playerUpdateSeen=true;
 }else if(source==='inventory'&&Object.hasOwn(changes,'skills')){
  if(!Array.isArray(changes.skills))throw Error('Native inventory skill changes are unavailable');
  for(const row of changes.skills){
   if(!row||!Number.isInteger(row.index)||row.index<0||row.index>=255||!flag(row.flag))throw Error('Invalid native inventory skill flag');
   if(row.flag===true||row.flag===1){const bit=(1<<(row.index&31))>>>0;bits=(bits|bit)>>>0;known=(known|bit)>>>0;}
  }
  value.inventoryUpdateSeen=true;
 }else if(source==='permission'&&Object.hasOwn(changes,'permission')){
  if(![0,1].includes(changes.permission))throw Error('Native permission BOOL is unavailable');
  if(changes.permission===0){value.override=0;value.overrideSource=DM_PERMISSION_SOURCE;}
 }
 value.knownMask=known;value.mask=known===0?null:bits;
 return value;
}
export function queryNativeSkillAdmission(view,skill,count,override=null){
 const unknown=reason=>({available:false,value:null,nativeResult:null,reason});
 if(!Number.isInteger(skill)||skill<0||skill>65535)return unknown('invalid_skill');
 if(!Number.isInteger(count)||count<0||count>255)return unknown('skill_count_unavailable');
 if(skill>=count)return{available:true,value:false,nativeResult:0,reason:'outside_active_rules'};
 if(override!==null&&!nativeOverride(override))return unknown('override_unavailable');
 if(override!==null&&override!==false&&override!==0)return{available:true,value:true,nativeResult:1,reason:'native_override'};
 if(!validNativeSkillAdmission(view))return unknown('native_mask_unavailable');
 const bit=(1<<(skill&31))>>>0;
 if((view.knownMask&bit)===0)return unknown('native_bit_unavailable');
 if(((view.mask??0)&bit)!==0)return{available:true,value:true,nativeResult:override===null?null:bit,reason:'received_set_bit'};
 if(override===null)return unknown('native_override_unavailable');
 return{available:true,value:false,nativeResult:0,reason:'received_clear_bit'};
}
