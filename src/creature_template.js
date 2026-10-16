import {nativeItemTag} from './item_stack_compare.js';

// Full creature template wrapper397dd0..398162. Resource/root/stat read,
// ComputeFeatBonuses, scripts/items/spells/variables, postprocess and each
// spell-use update are lower providers. Their return values are ignored except
// ReadStats, whose NONZERO return indicates failure.
export async function loadCreatureTemplateData(object,reference,newTag,p){
 const name=reference.split('\0')[0],resource=await p.resource(2027,'UTC ',name);
 if((resource.loaded|0)===0){await p.release(resource,1);await p.warning(`Creature template ${name} doesn't exist.\n`);return 0;}
 const root=await p.root(resource);
 if((await p.readStats(object,resource,root,0,0,0,1))!==0){await p.release(resource,1);return 0;}
 await p.featBonuses(object,0);await p.setTemplate(object,name);
 await p.scripts(object,resource,root);await p.items(object,resource,root,1,1);await p.spells(object,resource,root,0);await p.variables(object,resource,root);
 if(newTag!==null&&nativeItemTag(newTag).length!==0)await p.assignTag(object,await p.asTag(newTag));
 await p.postProcess(object);for(let level=0;level<10;level++)await p.updateSpellUses(object,level);
 await p.release(resource,1);return 1;
}
