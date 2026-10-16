import fs from 'node:fs/promises';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall';
const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)}),actor=s.player;
const choices=[];
for(const [index,state]of actor.nativeTalentClasses.entries())for(const [level,slots]of state.memorized.entries())for(const entry of slots){
 if(!entry?.ready)continue;const spell=s.spellBook.castingSpell(entry.id);
 if(spell?.targetType&8)choices.push({spellId:spell.id,impactScript:spell.impactScript,index,level,metamagic:entry.metamagic,targetType:spell.targetType});
}
console.log(JSON.stringify({choices,items:actor.inventory.map(id=>s.registry.get(id)).map(i=>({id:i.id,base:i.baseItem,slot:i.equipmentSlot,tag:i.tag,possessor:i.possessorId,properties:i.passiveProperties.map(p=>({type:p.type,subtype:p.subtype,value:p.costValue}))}))},null,2));
