import {NativeMessageWriter} from './native_message.js';
import {OBJECT_INVALID} from './game_object_array.js';
import {networkPartyAssociates} from './network_party.js';

// Native7bf0e0 -> complete4531b0 subtype27. The server resolves ownership,
// self/-19 henchman redirection and self/-13 familiar unpossession. No client
// control transfer, associate removal or AI command execution belongs here.
export function associateCommandRequest({targetId,command}){
 if(!Number.isInteger(targetId)||targetId<0||targetId>0xffffffff||!Number.isInteger(command)||command< -2147483648||command>2147483647)throw new Error('Invalid native associate command');
 const w=new NativeMessageWriter(1);w.create(8,0xffffffff,1);w.writeObjectIdClient(targetId);w.writeInt(command,32);w.setPrefix(Uint8Array.of(112,6,27));return Uint8Array.from(w.getWriteMessage().data);
}

// Native9945d0 ->998100 ->805440 ->7c3770 sends one WORD via22/0.
// These are the original UI command identifiers, not local AI instructions.
export const NETWORK_PARTY_COMMANDS=Object.freeze([
 {slot:2,label:'Attack nearest',icon:'IR_ATTACKNEAREST',quickChat:0,labelRef:0x14e1},
 {slot:3,label:'Follow',icon:'IR_FOLLOW',quickChat:22,labelRef:0x2aa},
 {slot:4,label:'Stand ground',icon:'IR_STANDGROUND',quickChat:10,labelRef:0x5c5},
 {slot:5,label:'Guard',icon:'IR_GUARD',quickChat:9,labelRef:0x5c2},
 {slot:6,label:'Heal me',icon:'IR_HEALME',quickChat:4,labelRef:0x5cb}
].map(Object.freeze));
export function quickChatRequest({quickChat}){
 if(!Number.isInteger(quickChat)||quickChat<0||quickChat>65535)throw new Error('Invalid native quick-chat command');
 const w=new NativeMessageWriter(1);w.create(6,0xffffffff,1);w.writeWord(quickChat);w.setPrefix(Uint8Array.of(112,22,0));return Uint8Array.from(w.getWriteMessage().data);
}
export const networkPartyCommandMenu=()=>({title:'Issue command',entries:NETWORK_PARTY_COMMANDS.map(e=>({...e,action:'associate.quickChat'}))});

// Server button39 stores the command INT and associate type WORD separately.
// Client8693b0 packs them into the widget;85c8f0 sign-extends its high SHORT.
// Type1 keeps a specific ID; types2/3 resolve the CURRENT companion/familiar.
export function networkAssociateShortcut(button,actor){
 if(button?.type!==39)return null;
 const targetId=button.associateType===1?button.associateId:button.associateType===2?actor?.companionId??OBJECT_INVALID:button.associateType===3?actor?.familiarId??OBJECT_INVALID:null;
 return targetId===null?null:{targetId,command:(button.intParam<<16)>>16};
}
export function networkAssociateShortcutChoices(world,actor){
 const entries=NETWORK_PARTY_COMMANDS.map(e=>({...e,binding:{type:42,intParam:e.quickChat}}));
 const familiar=world.registry.get(actor.familiarId??OBJECT_INVALID);
 if(familiar?.objectType===5&&!familiar.replicationRemoved)entries.push({label:'Possess Familiar',icon:'IFE_POSSESS',binding:{type:38}});
 const targets=[...networkPartyAssociates(world,actor,1),...[...world.registry.objects.values()].filter(o=>[2,3].includes(o.replicated?.field908))];
 for(const target of targets){
  if(target.objectType!==5||target.replicationRemoved||target.replicated?.master!==actor.id)continue;
  const type=target.replicated.field908,commands=type===2?[-9]:type===3?[-8]:type===1?[-18,-19,-20]:[];
  for(const command of commands){const info=networkAssociateShortcutPresentation({type:39,intParam:command,associateType:1,associateId:target.id},world);entries.push({...info,binding:{type:39,intParam:command,associateType:1,associateId:target.id}});}
 }
 return entries;
}
export function networkAssociateShortcutPresentation(button,world){
 if(button.type===38)return{label:'Possess Familiar',icon:'IFE_POSSESS',labelRef:0x20b};
 if(button.type===42)return NETWORK_PARTY_COMMANDS.find(e=>e.quickChat===(button.intParam&65535))??{label:'Quick chat '+(button.intParam&65535)};
 if(button.type!==39)return null;
 const command=(button.intParam<<16)>>16,info=({[-8]:['Unsummon','IFE_NOFAMILIAR',0x621],[-9]:['Unsummon','IFE_NOFAMILIAR',0x621],[-18]:['Unlock','IR_UNLOCK',0x5bb],[-19]:['Inventory','IR_INVENTORY',0xe93],[-20]:['Disarm trap','IR_HAND_TRAP',0x5ca]})[command];
 const target=world?.registry.get(networkAssociateShortcut(button,world.registry.get(world.localObjectId))?.targetId),name=target?.replicated?.name?.text;
 return{label:(info?.[0]??'Associate command '+command)+(name?' : '+name:''),icon:info?.[1],labelRef:info?.[2]};
}
