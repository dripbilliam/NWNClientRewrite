import {OBJECT_INVALID} from './game_object_array.js';
import {creatureRoot} from './creature_rules.js';
import {intEntry} from './combat_stats.js';
import {castingSpell,talentSpell,spellStringEntry} from './spell_metadata.js';
import {classAllowsConversion} from './spell_conversion.js';

const branch=(slot,label,icon,children)=>({slot,label,icon,children});
const menu=(title,entries)=>({title,entries});
const metamagics=[
  [2,1,11,'Empower','IR_EMPOWER'],[6,2,12,'Extend','IR_EXTEND'],[0,4,25,'Maximize','IR_MAXIMIZE'],
  [4,8,29,'Quicken','IR_QUICKEN'],[7,16,33,'Silent','IR_SILENT'],[5,32,37,'Still','IR_STILL']
];

// Client spell-menu target admission1409a4910. Self is a distinct bit;
// a self creature must not also qualify through the other-creature bit.
export function radialSpellTargetAllowed(spell,actor,target,filter=65535){
  if(!spell)return false;
  const mask=(spell.targetType&filter)&65535;
  if(!target)return Boolean(mask&4);
  if(target.objectType===5)return Boolean(mask&(target.id===actor.id?1:2));
  return Boolean(mask&({6:8,10:16,9:32,7:64}[target.objectType]??0));
}

// Selection1409a4540 ->140804d00 ->1407bf4e0 retains both the canonical
// target and saved native XYZ. Ground has OBJECT_INVALID, never actor.id.
export function radialSpellCastRequest(binding,actor,target,point){
  const position=point?.map(Math.fround)??[0,0,0];
  if(position.length!==3||!position.every(Number.isFinite))throw new Error('Radial cast position is unavailable');
  const f=Math.fround,x=position[0],y=position[1],z=position[2];
  const magnitude=f(Math.sqrt(f(f(f(x*x)+f(y*y))+f(z*z))));
  return {action:'spell.cast',actorId:actor.id,areaId:actor.areaId,spellId:binding.spellId&65535,
    classIndex:binding.classIndex&7,domainLevel:binding.domainLevel&15,metamagic:binding.metamagic&63,
    spontaneous:Number(Boolean(binding.spontaneous)),targetId:target?.id??OBJECT_INVALID,
    position,location:Number(magnitude>=f(0.00001))};
}

// CClientSpellMenu1409a10e0 / class1409a38e0 / metamagic1409a24b0 /
// levels1409a2370 / pool traversal1409a2b10 / children1409a3a30.
// This ordinary, controlled-creature view reads the authoritative live pools.
// DM/override/epic owners remain explicit actions instead of invented casts.
export function buildSpellRadial(actor,target,rules,book,p,{alwaysSubradial=false,filter=65535}={}){
  const classes=creatureRoot(actor).ClassList;
  if(!Array.isArray(classes)||!Array.isArray(actor.nativeTalentClasses))throw new Error('Radial spell class storage is unavailable');
  const classFlag=(index,key)=>intEntry(rules.classes,classes[index].Class&255,key).value!==0;
  const name=(table,id)=>p.name(table,id);
  const metaEntries=metamagics.filter(([, ,feat])=>p.hasFeat(actor,feat));
  const describe=id=>({label:name('spells',id),icon:spellStringEntry(rules.spells,id,'IconResRef')||'IR_CAST'});
  const eligible=id=>radialSpellTargetAllowed(castingSpell(rules,id),actor,target,filter);
  const leaf=(id,binding,uses,converted,level)=>{
    const details=describe(id);
    return {...details,action:'spell.cast',system:'spellcasting',binding:{...binding,spellId:id,spontaneous:Number(converted)},
      disabled:!eligible(id)||(converted?!p.readyForConversion(actor,binding.classIndex,level):uses===0),uses};
  };
  const candidates=(index,selectedMeta,firstLevel)=>{
    const state=actor.nativeTalentClasses[index];if(!state)throw new Error('Radial spell class pool is unavailable');
    const out=[],seen=new Set(),memorizes=classFlag(index,'MemorizesSpells'),restricted=classFlag(index,'SpellbookRestricted');
    for(let level=firstLevel;level<=(firstLevel===7?9:firstLevel);level++){
      let pool;
      if(memorizes){
        pool=state.memorized[level].slice(0,state.memorized[level].length&255)
          .filter(row=>row&&(selectedMeta===0||(row.metamagic&255)===selectedMeta))
          .map(row=>({id:row.id,metamagic:row.metamagic&255,domainLevel:row.domain!==0?(level-book.metamagicCost(row.metamagic))&255:0}));
      }else{
        if((p.spellGain(actor,index,level)&255)===0)continue;
        const base=level-book.metamagicCost(selectedMeta);if(base<0)continue;
        const ids=restricted?state.known[base].slice(0,state.known[base].length&65535):Array.from({length:rules.spells.orderedRows.length},(_,id)=>id);
        pool=ids.filter(id=>restricted||book.level(id,classes[index].Class&255)===base).map(id=>({id,metamagic:selectedMeta,domainLevel:0}));
      }
      for(const row of pool){
        const spell=castingSpell(rules,row.id);if(!spell||selectedMeta!==0&&(spell.metamagic&selectedMeta)===0||seen.has(row.id))continue;
        seen.add(row.id);
        const binding={spellId:row.id,classIndex:index,metamagic:row.metamagic,domainLevel:row.domainLevel};
        const uses=book.uses(actor,row.id,index,row.domainLevel,row.metamagic)&255;
        const definition=talentSpell(rules,row.id);
        if(definition.children.length){
          const childEntries=()=>definition.children.map((id,slot)=>{
            if(!castingSpell(rules,id))return null;
            const converted=uses===0&&classAllowsConversion(actor,index,rules)&&spell.spontaneouslyCast!==0;
            return {...leaf(id,binding,uses,converted,level),slot};
          }).filter(Boolean);
          // Native parent requires its own target mask; children each retain
          // their own masks and the parent's resource/domain/meta context.
          out.push({...describe(row.id),children:()=>menu(name('spells',row.id),childEntries()),disabled:!eligible(row.id)||uses===0,uses});
        }else{
          const converted=uses===0&&classAllowsConversion(actor,index,rules)&&spell.spontaneouslyCast!==0;
          out.push(leaf(row.id,binding,uses,converted,level));
        }
      }
    }
    return out;
  };
  const page=(title,values,icon)=>menu(title,[...values.slice(0,7).map((value,slot)=>({...value,slot})),
    ...(values.length>7?[branch(7,'More…',icon,()=>page(title,values.slice(7),icon))]:[])]);
  const levels=(index,meta)=>menu(name('classes',classes[index].Class),Array.from({length:8},(_,level)=>{
    const label=level===0?'Cantrips':level===7?'Levels 7–9':`Level ${level}`,icon=level===0?'IR_CANTRIPS':level===7?'IR_LEVEL789':`IR_LEVEL${level}`;
    return branch(level,label,icon,()=>page(label,candidates(index,meta,level),icon));
  }));
  const metaMenu=index=>menu('Metamagic',metaEntries.map(([slot,mask,,label,icon])=>branch(slot,label,icon,()=>levels(index,mask))));
  const casterIndices=classes.map((_,index)=>index).filter(index=>classFlag(index,'SpellCaster'));
  const classMenu=meta=>menu(meta?'Metamagic':'Cast spell',casterIndices.map(index=>branch(index,name('classes',classes[index].Class),
    spellStringEntry(rules.classes,classes[index].Class,'Icon'),()=>meta?metaMenu(index):levels(index,0))));
  const entries=[];
  if(classes.length>=4||alwaysSubradial){
    entries.push(branch(4,'Cast spell','IR_CAST',()=>classMenu(false)));
    if(metaEntries.length)entries.push(branch(0,'Metamagic','IR_METAMAGIC',()=>classMenu(true)));
  }else for(const index of casterIndices){
    const icon=spellStringEntry(rules.classes,classes[index].Class,'Icon');
    entries.push(branch(5-index,name('classes',classes[index].Class),icon,()=>levels(index,0)));
    if(metaEntries.length)entries.push(branch([7,0,1][index],'Metamagic',icon,()=>metaMenu(index)));
  }
  if(casterIndices.length&&p.hasFeat(actor,1001))entries.push({slot:2,label:'Epic spells',icon:'IR_EPICSPELL',action:'spell.epic',system:'epic spell feat casting'});
  if(casterIndices.length)entries.push(branch(6,'Spellcasting options','IR_SPELL_ABS',()=>menu('Spellcasting options',[
    {slot:0,label:'Counterspell',icon:'IR_CNTRSPELL',action:'spell.counterspell',system:'counterspell selection and resolution',disabled:!target||target.id===actor.id||target.objectType!==5},
    {slot:1,label:'Defensive casting',icon:'ir_defcast',action:'spell.defensiveCasting',system:'defensive casting input'}
  ])));
  return menu('Spell',entries);
}
