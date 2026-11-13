import {createHash} from 'node:crypto';
import {isDeepStrictEqual} from 'node:util';
import {parseGff} from '../../src/gff.js';
import {typedGff,writeGff} from '../../src/gff_writer.js';

// Test-only workload definitions. Availability and all choices still come from
// the original server and actual source panes; no class is enabled here.
const CASES=Object.freeze({
 'wizard-multiclass':{file:'wizard.bic',initialClass:10,classes:[10,4],ability:3,groupFeat:72,requiredStages:['class','attributes','skills','feats','spells','summary']},
 'sorcerer-caster':{file:'sorcerer.bic',initialClass:9,classes:[9,9],ability:5,groupFeat:null,requiredStages:['class','attributes','skills','spells','summary']},
 'cleric-new-class':{file:'fighter.bic',initialClass:4,classes:[2,2],ability:4,groupFeat:null,requiredStages:['class','attributes','skills','domains','summary']},
});
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
export function levelSourceCase(name){
 if(!Object.hasOwn(CASES,name))throw Error('Explicit source level-up workload required');
 return structuredClone({name,...CASES[name]});
}
export function xpOnlyLevelSourceCharacter(bytes,exptable,name){
 const recipe=levelSourceCase(name),original=Uint8Array.from(bytes),parsed=parseGff(original,'BIC '),root=parsed.root;
 if(!Array.isArray(root.ClassList)||root.ClassList.length!==1||root.ClassList[0].Class!==recipe.initialClass||root.ClassList[0].ClassLevel!==15)throw Error('Expected the exact installed level15 workload class');
 const before=typedGff(root),targetLevel=15+recipe.classes.length,cell=exptable?.orderedRows?.[targetLevel-1]?.XP;
 if(typeof cell!=='number'&&typeof cell!=='string'||typeof cell==='string'&&!/^\d+$/.test(cell))throw Error('Active base XP threshold is unavailable');
 const experience=Number(cell);
 if(!Number.isInteger(experience)||experience<=root.Experience||experience>0x7fffffff)throw Error('Active XP threshold cannot supply the requested advancements');
 root.Experience=experience;const typed=typedGff(root);
 if(!isDeepStrictEqual({...before.fields,Experience:null},{...typed.fields,Experience:null})||before.type!==typed.type||before.fields.Experience.type!==typed.fields.Experience.type)throw Error('XP fixture changed unrelated typed character data');
 const output=writeGff('BIC ',typed),again=typedGff(parseGff(output,'BIC ').root);
 if(!isDeepStrictEqual(typed,again)||!Buffer.from(bytes).equals(Buffer.from(original)))throw Error('Typed XP-only fixture did not round-trip or altered its input');
 return {bytes:output,metadata:{case:recipe.name,installedFile:recipe.file,originalSha256:sha(original),uploadedSha256:sha(output),onlyFieldChanged:'Experience',initialLevel:15,targetLevel,experience,classes:recipe.classes,ability:recipe.ability,groupFeat:recipe.groupFeat,originalInputUnchanged:true,baseResourcePolicyRequired:true}};
}
