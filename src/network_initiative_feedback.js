import {spellMessageColors} from './client_spell_message.js';
export const initiativeMessageColor=String.fromCharCode(60,99,255,102,1,62);
// SendServerToPlayerCCMessage4cf090 case14/4cfaa4 -> original client
//770c80 case14/777be0. This is a server roll report, never a local roll.
export function readNetworkInitiativeFeedback(r){
 return{kind:'initiative-feedback',sourceId:r.readObjectIdClient(),roll:r.readByte(5),modifier:r.readChar(8)};
}
export async function presentInitiativeFeedback(m,p){
 let name=await p.name(m.sourceId);
 if(name===null)name=await p.tlk(0x209d);
 else if(await p.player())name=((await p.player()).id===m.sourceId?spellMessageColors.self:spellMessageColors.other)+name+'</c>';
 const total=m.roll+m.modifier;
 for(const [id,value]of [name,String(total),String(m.roll),m.modifier<0?'-':'+',String(Math.abs(m.modifier)),String(total)].entries())await p.token(id,value);
 await p.display(initiativeMessageColor+await p.parse(0xcfb6)+'</c>',128);
}
