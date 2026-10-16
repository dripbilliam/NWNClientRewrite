// Metadata-only sweep of unchanged installed character presets. Remaining-use
// and text providers are captured; live input/effects are tested separately.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {loadCharacterRules} from '../src/character.js';
import {parseGff} from '../src/gff.js';
import {featRadialProviders} from '../src/feat_radial_rules.js';
import {buildFeatAbilityRadial} from '../src/feat_radial.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-feat-radial-v1.json';
const report={limits:'Metadata-only installed preset sweep; unchanged BIC files and active tables. Uses fixed100/text synthetic, no native picking, spell execution or all-feat effect acceptance.',rows:[]};
try{
 const rules=await loadCharacterRules(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`));
 for(const filename of (await fs.readdir(`${install}/data/lcv`)).filter(n=>n.toLowerCase().endsWith('.bic'))){
  const root=parseGff(await fs.readFile(`${install}/data/lcv/${filename}`)).root;
  if(root.IsDM){report.rows.push({filename,skipped:'DM character menu is a separate owner'});continue;}
  const actor={id:99,objectType:5,creatureData:root,combatMode:0},warnings=[];
  const p=featRadialProviders(actor,actor,rules,{remaining:()=>100,warning:message=>warnings.push(message)});
  const ui={text:id=>`label${id}`,featName:id=>`feat${id}`,className:i=>`class${root.ClassList[i].Class}`,classIcon:()=>'',title:'Abilities',moreLabel:'More',classAbilitiesLabel:'Classes'};
  const visit=(menu,depth=0)=>{
   assert.ok(depth<15,'Radial traversal must terminate');assert.ok(menu.entries.length<=8);assert.equal(new Set(menu.entries.map(e=>e.slot)).size,menu.entries.length);
   return menu.entries.map(e=>({slot:e.slot,featId:e.featId??e.binding?.featId,auxiliary:e.auxiliary??e.binding?.auxiliary,...(e.children?{children:visit(e.children(),depth+1)}:{action:e.action,disabled:e.disabled})}));
  };
  report.rows.push({filename,classes:root.ClassList.map(c=>c.Class),menu:visit(buildFeatAbilityRadial(p,ui)),warnings});
 }
}catch(error){report.failure={message:error.message,stack:error.stack};}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({characters:report.rows.length,failure:report.failure}));if(report.failure)process.exitCode=1;
