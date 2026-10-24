import {NativeMessageWriter} from './native_message.js';
import {scriptStringBytes} from './script_string.js';

// Original29/4 ->457170 ->4dbc10 returns a server-owned class availability
// bitmap.29/0 is the manual CNWLevelStats proposal; only ValidateLevelUp418b80
// commits it. No BIC upload, XP change or optimistic local level is involved.
export const levelUpBeginRequest=()=>Uint8Array.of(112,29,4);
export function readNetworkLevelUp(r,minor){
 if(minor===4){const n=r.readByte();return{kind:'level-up-classes',available:Array.from({length:n},()=>Boolean(r.readBool()))};}
 return{kind:minor===3?'level-up-available':'level-up-result',...(minor===3?{}:{accepted:minor===1})};
}
const integer=(v,min,max)=>Number.isInteger(v)&&v>=min&&v<=max;
export function levelUpRequest(proposal,{level,skillCount,pickDomains=false,pickSchool=false}){
 const {classId,ability=6,hitDie,skills,skillPoints,feats,known={},removed={},fieldE34,fieldE48,fieldE30,fieldE38,domains=[],school=0}=proposal;
 if(!integer(level,1,254)||!integer(skillCount,0,255)||!integer(classId,0,254)||!integer(ability,0,6)||!integer(hitDie,1,255)||!integer(skillPoints,0,65535)||!Array.isArray(skills)||skills.length!==skillCount||!skills.every(n=>integer(n,0,127))||!Array.isArray(feats)||feats.length>255||!feats.every(n=>integer(n,0,65535))||!integer(fieldE34,-2147483648,2147483647)||!integer(fieldE30,-2147483648,2147483647)||![fieldE48,fieldE38].every(s=>typeof s==='string'&&scriptStringBytes(s).length<=255))throw Error('Invalid native level-up proposal');
 if((level+1)%4!==0&&ability!==6)throw Error('Ability increase is not due at this level');
 if((level+1)%4===0&&ability===6)throw Error('Select an ability increase');
 if(pickDomains&&(!Array.isArray(domains)||domains.length!==2||!domains.every(n=>integer(n,0,255))))throw Error('Invalid native level-up domains');
 if(pickSchool&&!integer(school,0,255))throw Error('Invalid native level-up school');
 const w=new NativeMessageWriter(1);w.create(256,0xffffffff,1);w.writeByte(classId);if((level+1)%4===0)w.writeByte(ability);w.writeByte(hitDie);
 // Native shift count is masked to31, including custom skill tables >32.
 // Emit every skill sharing a set bit, even when that skill's change is0.
 let mask=0;for(let i=0;i<skills.length;i++)if(skills[i])mask|=1<<(i&31);w.writeDword(mask>>>0);for(let i=0;i<skills.length;i++)if(mask&(1<<(i&31)))w.writeByte(skills[i]);
 w.writeWord(skillPoints);w.writeByte(feats.length);for(const feat of feats)w.writeWord(feat);
 for(let l=0;l<10;l++)for(const list of [known[l]??[],removed[l]??[]]){if(!Array.isArray(list)||list.length>255||!list.every(n=>integer(n,0,0xffffffff)))throw Error('Invalid native level-up spells');w.writeByte(list.length);for(const spell of list)w.writeDword(spell);}
 w.writeInt(fieldE34);w.writeStringBytes(scriptStringBytes(fieldE48));w.writeInt(fieldE30);w.writeStringBytes(scriptStringBytes(fieldE38));if(pickDomains)for(const domain of domains)w.writeByte(domain);if(pickSchool)w.writeByte(school);w.setPrefix(Uint8Array.of(112,29,0));return Uint8Array.from(w.getWriteMessage().data);
}

export function networkLevelUpSnapshot(actor){
 const p=actor?.playerState,s=actor?.replicated?.stats,classes=s?.classes;
 const base=actor.clientAbilityCache?.base??p?.abilities?.base;
 if(!p?.combat?.canLevelUp||!p.levelUp||!classes?.length||!Array.isArray(base)||base.length!==6||!base.every(Number.isInteger))throw Error('Waiting for server level-up details');
 return{actorId:actor.id,classes:structuredClone(classes),race:s.racialType,goodEvil:s.fieldDE4,lawChaos:s.fieldDE6,baseAbilities:[...base],feats:[...(p.feats??[])],spellbooks:structuredClone(p.spellbooks??{}),...structuredClone(p.levelUp)};
}
