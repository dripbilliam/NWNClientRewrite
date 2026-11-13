// Owned local test character only. Installed BIC/archive bytes are read-only;
// the original server validates the uploaded copy and owns all spell outcomes.
import assert from 'node:assert/strict';import fs from 'node:fs/promises';import path from 'node:path';import {createHash} from 'node:crypto';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
import {parseGff} from '../../src/gff.js';import {typedGff,writeGff,gffField as field} from '../../src/gff_writer.js';
import {parse2da} from '../../src/area.js';import {decodeResourceText} from '../../src/resource_archive.js';
import {spellLevelByClass,metamagicLevelCost} from '../../src/spell_book.js';
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
export async function radialSpellCharacter(bytes,caster){
 assert.ok(['wizard','cleric'].includes(caster));const install=path.resolve('../FullDecomp/NwnRootInstall'),resolver=await openServerResourceContext({install}),tables={};
 for(const name of ['classes','spells','ruleset'])tables[name]=parse2da(decodeResourceText(await resolver.getResource(name,2017)));
 const root=typedGff(parseGff(bytes,'BIC ').root),raw=parseGff(bytes,'BIC ').root,cls=root.fields.ClassList.value[0],classId=raw.ClassList[0].Class;
 const candidates=tables.spells.orderedRows.map((row,id)=>({id,row,level:spellLevelByClass(tables,id,classId)})).filter(value=>value.level<7);
 const pick=(label,predicate)=>{const found=candidates.find(value=>String(value.row.Label).toLowerCase().replaceAll('_','')===label&&predicate(value));assert.ok(found,`Original ${caster} fixture needs ${label}`);return found;};
 const family=pick('protectionfromalignment',v=>v.level>0&&Number(v.row.SubRadSpell1)>=0);
 const max=caster==='wizard'?pick('endurance',v=>v.level>0&&(Number(v.row.MetaMagic)&4)!==0):null;
 const metaLevel=max?max.level+metamagicLevelCost(tables,4):null;if(max)assert.ok(metaLevel<9);
 const childIds=Array.from({length:8},(_,index)=>Number(family.row['SubRadSpell'+(index+1)])).filter(id=>Number.isInteger(id)&&id>=0&&tables.spells.orderedRows[id]);assert.ok(childIds.length>=2);
 const children=childIds.filter(id=>(Number(tables.spells.orderedRows[id].TargetType)&1)!==0);assert.ok(children.length);
 const memo=(id,meta=0,ready=1)=>({type:0,fields:{Spell:field(2,id),SpellMetaMagic:field(0,meta),Ready:field(0,ready),DomainSpell:field(0,0)}});
 const known=(id,level)=>{const key='KnownList'+level;cls.fields[key]??=field(15,[]);if(!cls.fields[key].value.some(row=>row.fields.Spell.value===id))cls.fields[key].value.push({type:0,fields:{Spell:field(2,id)}});};
 const add=(id,level,meta=0,ready=1)=>{known(id,level-metamagicLevelCost(tables,meta));const key='MemorizedList'+level;cls.fields[key]??=field(15,[]);cls.fields[key].value.unshift(memo(id,meta,ready));};
 // Use existing first slots, not extra slots outside the original class limit.
 for(let level=0;level<10;level++)if(cls.fields['MemorizedList'+level])cls.fields['MemorizedList'+level].value=[];
 add(100,0);add(family.id,family.level);if(max)add(max.id,metaLevel,4);
 let conversion=null;
 if(caster==='cleric'){
  const cure=pick('curelightwounds',v=>v.level===1&&Number(v.row.SpontaneouslyCast)!==0),resource=pick('bless',v=>v.level===1);
  add(cure.id,1);add(resource.id,1);conversion={spellId:cure.id,resourceId:resource.id,level:1};
 }
 if(max)assert.ok(root.fields.FeatList.value.some(row=>row.fields.Feat.value===25),'Metamagic test must use an originally owned feat');
 const output=writeGff('BIC ',root);
 return{bytes:output,metadata:{caster,classId,originalSha256:hash(bytes),uploadedSha256:hash(output),originalUnchanged:true,family:{parent:family.id,children,level:family.level},metamagic:max?{spellId:max.id,mask:4,level:metaLevel}:null,conversion,scope:'In-memory original sample BIC copy with catalog-derived prepared resources; no feats added, live actor edits or original file writes.'}};
}
if(process.argv.includes('--describe')){
 for(const caster of ['wizard','cleric']){const input=await fs.readFile(path.resolve('../FullDecomp/NwnRootInstall/data/lcv',caster+'.bic'));const value=await radialSpellCharacter(input,caster);console.log(JSON.stringify(value.metadata));}
}
