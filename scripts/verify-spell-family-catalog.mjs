import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {openServerResourceContext} from '../electron/server_resource_context.mjs';
import {decodeResourceText} from '../src/resource_archive.js';
import {parse2da} from '../src/area.js';
import {isSpellFamily,spellFamilyChildren,spellShortcutChoice,spellChoiceBindings} from '../src/spell_family.js';

// Read-only stock catalog coverage. Override-specific behavior is tested in
// spell-family.test.js and the Chromium fixture with four alignment variants.
const resources=await openServerResourceContext({install:'../FullDecomp/NwnRootInstall'});
const spells=parse2da(decodeResourceText(await resources.getResource('spells',2017))),rules={spells},families=[];
for(let id=0;id<spells.orderedRows.length;id++){
 if(!isSpellFamily(rules,id))continue;
 const source={type:2,intParam:id,classIndex:2,metamagic:2,domainLevel:1};
 const choice=await spellShortcutChoice(rules,source,async child=>({label:String(child)}));
 assert.equal(choice.binding,undefined);
 const bindings=[...spellChoiceBindings([choice])];assert.ok(bindings.length>0,`Family ${id} has no leaves`);
 for(const binding of bindings){assert.equal(isSpellFamily(rules,binding.intParam),false);assert.deepEqual(binding,{...source,intParam:binding.intParam});}
 const children=spellFamilyChildren(rules,id);
 for(const child of children)if(!isSpellFamily(rules,child))assert.ok(bindings.some(b=>b.intParam===child));
 families.push({id,children,leaves:bindings.map(b=>b.intParam)});
}
assert.ok(families.length>0);
const report={success:true,source:'Read-only installed stock spells.2da; no server connection or content download',families,joins:0,uploads:0};
await fs.writeFile(new URL('../backups/animations/creation-experience-spell-family-catalog-v1.json',import.meta.url),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({success:true,families:families.length,leaves:families.reduce((n,f)=>n+f.leaves.length,0),joins:0,uploads:0}));
