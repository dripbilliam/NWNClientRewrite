import {decodeGffText} from './gff_text.js';
import {spellMessageColors} from './client_spell_message.js';
import {damageMessageColor} from './network_damage_feedback.js';

// Server4cf090 -> client772612/773d98. Server outcomes only: these fields
// never roll attacks, deal damage, or update canonical objects on this client.
export function readNetworkAttackFeedback(r,minor){
 const sourceId=r.readObjectIdClient(),targetId=r.readObjectIdClient(),modifier=r.readChar(8),roll=r.readByte(5),result=r.readByte(4),attackType=minor===6?r.readWord(16):null,combatMode=r.readByte(4);
 const offhand=r.readBool(),sneakAttack=r.readBool(),deathAttack=r.readBool(),specialMinus534=minor===5?r.readBool():0,coupDeGrace=minor===5?r.readBool():0,threatened=r.readBool();
 const confirmation=threatened?r.readByte(5):null,concealmentChance=result===8||result===9?r.readByte(7):0;
 let debug=null;if(r.readBool()){const value=r.readCExoString();debug=value.bytes?decodeGffText(value.bytes):'';}
 return{kind:'attack-feedback',minor,sourceId,targetId,modifier,roll,result,attackType,combatMode,offhand,sneakAttack,deathAttack,specialMinus534,coupDeGrace,threatened,confirmation,concealmentChance,debug};
}
const resultRefs={1:511,2:1463,3:5224,4:514,10:1769};
const modeRefs={2:417,3:403,5:1060,6:419,7:2773,8:2777,11:76423};
export async function presentAttackFeedback(m,p){
 const special=m.minor===6,sign=m.modifier<0?'-':'+',absolute=Math.abs(m.modifier),total=m.roll+m.modifier;
 let confirmation='',attackName='',result='';
 if(m.threatened===1){await p.token(0,String(m.confirmation));confirmation=await p.parse(61953)+' '+sign+' '+absolute+' = '+(m.confirmation+m.modifier);}
 if(special&&m.attackType!==0){
  const builtin={65001:517,65000:518,65003:5606}[m.attackType];
  if(builtin!==undefined)attackName=await p.tlk(builtin);
  else{const feat=await p.feat(m.attackType);if(feat)attackName=await p.tlk(feat.name>>>0);}
 }
 const ref=resultRefs[m.result]??(special?{5:53241,6:53300}[m.result]:{7:61628}[m.result]);
 if(ref!==undefined)result=await p.tlk(ref);
 else if(m.result===8||m.result===9){await p.token(0,String(m.concealmentChance));result=await p.parse(m.result===8?62337:62336);}
 let target=await p.name(m.targetId);if(target===null)target=await p.tlk(8349);
 let source=await p.name(m.sourceId);
 if(source===null)source=await p.tlk(8349);
 else if(await p.player())source=((await p.player()).id===m.sourceId?spellMessageColors.self:spellMessageColors.other)+source+'</c>';
 await p.token(0,source);
 if(special){await p.token(2,target);await p.token(1,attackName);}
 else await p.token(1,target);
 const offset=special?1:0;
 for(const [id,value]of [[2,result],[3,String(m.roll)],[4,sign],[5,String(absolute)],[6,String(total)],[7,confirmation]])await p.token(id+offset,value);
 let raw=await p.parse(special?10471:10470),modeBuffer=raw;
 if(!special&&m.coupDeGrace===1){modeBuffer=await p.tlk(61629);raw=modeBuffer+' : '+raw;}
 if(m.sneakAttack||m.deathAttack){const sneak=await p.tlk(5225),death=await p.tlk(3952);raw=(m.sneakAttack?sneak:'')+(m.sneakAttack&&m.deathAttack?' + ':'')+(m.deathAttack?death:'')+' : '+raw;}
 if(special?m.combatMode>=2:m.combatMode!==0&&m.combatMode!==9){
  const mode=modeRefs[m.combatMode]??(!special?{4:53239,10:2803}[m.combatMode]:undefined);
  if(mode!==undefined)modeBuffer=await p.tlk(mode);
  else await p.warning('Error! Unrecognized attack mode!');
  // Unknown modes retain the native scratch string, even when it is the
  // already-formatted header. Diagnose rather than substitute a guessed mode.
  raw=modeBuffer+' : '+raw;
 }
 if(!special&&m.specialMinus534===1)raw=await p.tlk(6626)+' : '+raw;
 if(m.offhand===1)raw=await p.tlk(1559)+' : '+raw;
 await p.display(damageMessageColor+raw+'</c>',128);
 if(m.debug!==null)await p.display(m.debug,128);
 if(!(await p.options()).enabled||!await p.creature(m.sourceId))return;
 const emit=raw=>p.floating({objectId:m.sourceId,raw,rgb:[1,1,1],font:'',flags:0});
 if(special){if(m.attackType!==867&&m.attackType!==868)await emit(attackName+': *'+result+'*');return;}
 if(m.sneakAttack===1)await emit('*'+await p.tlk(53237)+'*');
 else if(m.deathAttack===1)await emit('*'+await p.tlk(3952)+'*');
 if(m.coupDeGrace===1)await emit('*'+await p.tlk(61630)+'*');
 if(m.specialMinus534===1)await emit('*'+await p.tlk(67595)+'*');
 if(m.result===3)await emit('*'+await p.tlk(67510)+'*');
 if(m.result===10)await emit('*'+await p.tlk(1770)+'*');
}
