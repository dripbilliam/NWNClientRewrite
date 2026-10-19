import {OBJECT_INVALID} from './game_object_array.js';

// Creature update781e80, attack branch7831c0..783392; constructor7fb0e0.
// Wire words are projected into the client's separate80-byte action layout.
// The server does not transmit reactionDelay; the client selector owns it.
export function networkAttackAnimationRecords(sourceId,attacks){
 if(!Array.isArray(attacks)||attacks.length>3)throw new Error('Native attack animation group is invalid');
 if(!attacks.length)return[{type:0,sourceId:OBJECT_INVALID,duration:0,damage:0,result:0,targetId:OBJECT_INVALID,reactionDelay:0,reaction:0,reactionDuration:0,attackType:0,ranged:0,killingBlow:0,weaponAttackType:0}];
 return attacks.map(a=>({type:1,sourceId:sourceId>>>0,duration:a.field2&65535,damage:a.damage&65535,result:a.result&255,targetId:a.target>>>0,
  reactionDelay:0,reaction:a.fieldA&65535,reactionDuration:a.fieldC&65535,attackType:a.field7A&65535,ranged:a.field5C|0,killingBlow:a.field68|0,weaponAttackType:a.field56&255}));
}
