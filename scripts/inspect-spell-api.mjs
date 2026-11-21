import {openLocalModule} from './local-module.mjs';
import {parseScriptApi} from '../src/ncs.js';
import {RESOURCE_TYPE,decodeResourceText} from '../src/resource_archive.js';
import {loadCharacterRules} from '../src/character.js';
import {castingSpell,spellStringEntry} from '../src/spell_metadata.js';
if(process.argv[2]==='--constants'){
 const root='../FullDecomp/NwnRootInstall',r=await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),text=decodeResourceText(await r.getResource('nwscript',RESOURCE_TYPE.NSS)),pattern=new RegExp(process.argv[3]??'.');
 console.log(text.split(/\r?\n/).filter(line=>/^\s*(?:int|float|string)\s+[A-Z][A-Z_0-9]*\s*=/.test(line)&&pattern.test(line)).join('\n'));process.exit(0);
}
if(process.argv[2]==='--classes'){
 const root='../FullDecomp/NwnRootInstall',r=await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),rules=await loadCharacterRules(r);
 console.log(JSON.stringify({columns:rules.classes.columns,rows:rules.classes.orderedRows.slice(0,11).map((row,id)=>({id,values:Object.fromEntries(Object.entries(row).filter(([name])=>/label|spont|convert/i.test(name)))}))},null,2));process.exit(0);
}
if(process.argv[2]==='--spells'){
 const root='../FullDecomp/NwnRootInstall',r=await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),rules=await loadCharacterRules(r),pattern=new RegExp(process.argv[3]??'.','i');
 console.log(JSON.stringify(rules.spells.orderedRows.flatMap((_row,id)=>{const label=spellStringEntry(rules.spells,id,'Label');return pattern.test(label)?[{id,label,...castingSpell(rules,id)}]:[];}),null,2));process.exit(0);
}
const root='../FullDecomp/NwnRootInstall',r=await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),api=parseScriptApi(decodeResourceText(await r.getResource('nwscript',RESOURCE_TYPE.NSS))),wanted=new RegExp(process.argv[2]??'CastSpell|TouchAttack|Memoriz|Rest');
console.log(JSON.stringify(api.flatMap((entry,id)=>wanted.test(entry.name)?[{id,...entry}]:[]),null,2));
