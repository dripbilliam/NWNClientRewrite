import {satisfiesNativeBuild} from './network_build.js';
import {decodeGffText} from './gff_text.js';
import {spellMessageColors} from './client_spell_message.js';
export const damageMessageColor=String.fromCharCode(60,99,255,102,1,62);
// CC3/77115e: the server build gates13 vs32 optional14-bit unsigned values.
// These are replicated outcomes, not damage rolls or local hit-point changes.
export function readNetworkDamageFeedback(r,serverBuild){
 const sourceId=r.readObjectIdClient(),targetId=r.readObjectIdClient(),count=satisfiesNativeBuild(serverBuild,{number:8193,revision:35,postfix:0})?32:13,damage=[];
 for(let index=0;index<count;index++)damage.push(r.readBool()?r.readWord(14):-1);
 let debug=null;if(r.readBool()){const s=r.readCExoString();debug=s.bytes?decodeGffText(s.bytes):'';}
 return{kind:'damage-feedback',sourceId,targetId,damage,debug};
}
const colorControl=rgb=>'<c'+String.fromCharCode(...rgb.map(v=>v<1?1:v&255)).split('\0')[0]+'>';
// Native CC3 accumulation/formatting. p.cell reads active tables; group totals
// are only text presentation, never written to objects, HP, effects or slots.
export async function presentDamageFeedback(message,p){
 const count=message.damage.length,groupData=Array.from({length:count},()=>({amount:-1,color:''}));
 if(p.typeRows()>count)throw new Error('Native damage table exceeds the available server damage slots');
 for(let row=0;row<count;row++){
  const rgb=[];for(const column of ['ColorR','ColorG','ColorB']){const cell=p.cell('groups',row,column);if(!cell.found)break;rgb.push(cell.value);}
  if(rgb.length===3)groupData[row].color=colorControl(rgb);
 }
 let total=0;for(const value of message.damage)if(value!==-1)total=(total+value)|0;
 for(let row=0;row<Math.min(p.typeRows(),32);row++){
  const amount=message.damage[row];if(amount===-1)continue;const cell=p.cell('types',row,'DamageTypeGroup');if(!cell.found)continue;
  if(cell.value<0||cell.value>=count)throw new Error('Native damage group index is outside the available display groups');
  const group=groupData[cell.value];if(group.amount===-1)group.amount=0;group.amount=(group.amount+amount)|0;
 }
 let target=await p.name(message.targetId);if(target===null)target=await p.tlk(8349);
 let source=await p.name(message.sourceId);
 if(source!==null){const player=await p.player();if(player)source=((await p.player()).id===message.sourceId?spellMessageColors.self:spellMessageColors.other)+source+'</c>';}
 else source=await p.tlk(8349);
 await p.token(0,source);await p.token(1,target);await p.token(2,String(total));
 const header=await p.parse(10466),parts=[];
 for(let row=0;row<count;row++){
  const group=groupData[row];if(group.amount===-1)continue;
  const ref=p.cell('groups',row,'FeedbackStrref');await p.token(0,String(group.amount));let part=await p.parse((ref.found?ref.value:-1)>>>0);
  if(group.color)part=group.color+part+'</c>';parts.push(part);
 }
 await p.display(damageMessageColor+header+' ('+parts.join(' ')+')</c>',128);
 const options=await p.options();if(options.enabled&&await p.target(message.targetId)){
  const emit=raw=>p.floating({objectId:message.targetId,raw,rgb:[1,1,1],font:'fnt_floaty_smal',flags:0});
  if(options.total)await emit(options.color+String(total>>>0)+'</c>');
  else for(const group of groupData)if(group.amount!==-1)await emit(group.color?group.color+String(group.amount>>>0)+'</c>':String(group.amount>>>0));
 }
 if(message.debug!==null)await p.display(message.debug,128);
}
