// Derived numeric inputs only; original BICs/resources remain in the install.
import fs from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {rulesetInt} from '../src/combat_stats.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-hp-native-inputs-v1.json',rows=[];
const resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),names=(await fs.readdir(`${install}/data/lcv`)).filter(n=>/\.bic$/i.test(n)).sort();
for(const name of names){
 const bytes=await fs.readFile(`${install}/data/lcv/${name}`),s=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:bytes}),o=s.player,root=o.creatureData;
 const defaults={FEAT_TOUGHNESS_HP_BONUS:1,FEAT_DEATHLESS_VIGOR_HP_BONUS:3,FEAT_EPIC_DEATHLESS_VIGOR_HP_BONUS:5,...Object.fromEntries(Array.from({length:10},(_,i)=>[`FEAT_EPIC_TOUGHNESS_HP_BONUS_${i+1}`,(i+1)*20]))};
 rows.push({name,source:`${install}/data/lcv/${name}`,sha256:createHash('sha256').update(bytes).digest('hex'),pc:o.nativeStatsIsPCb0,possessed:Number(Boolean(o.isPossessedFamiliar)),level:root.ClassList.reduce((n,c)=>n+(c.ClassLevel&255),0)&255,pale:root.ClassList.find(c=>(c.Class&255)===34)?.ClassLevel??0,dice:(root.LvlStatList??[]).map(l=>l.LvlStatHitDie&255),constitution:o.nativeConModifierD3d,stored:root.HitPoints,saved:root.MaxHitPoints,computed:s.hitPoints(o.id,true),feats:root.FeatList.map(f=>f.Feat&65535).filter(f=>f===40||f===891||f>=754&&f<=763),rules:Object.fromEntries(Object.entries(defaults).map(([key,fallback])=>[key,rulesetInt(s.characterRules,key,fallback)]))});
}
await fs.writeFile(output,JSON.stringify({rows,limits:'Derived HP inputs from installed BICs and active Prelude rules; no assets copied. Original native HP routine will independently consume these inputs; saved maximum is an observation, not authority.'},null,2)+'\n');console.log(JSON.stringify({characters:rows.length,discrepancies:rows.filter(r=>r.saved!==r.computed).map(r=>({name:r.name,saved:r.saved,computed:r.computed}))}));
