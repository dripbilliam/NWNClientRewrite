import {OBJECT_INVALID} from './game_object_array.js';

const required=(p,name)=>{if(typeof p?.[name]!=='function')throw new Error(`Native cast-request provider ${name} is unavailable`);return p[name];};
const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native cast-request ${name} is unavailable`);return value|0;};
const call=(p,name,...args)=>required(p,name)(...args);

// ExecuteCommandCastSpell140511540, all four command branches. Lower
// AddCastSpellActions remains a distinct owner. No effect or duration is
// inferred here. Class is a class TYPE at this boundary, an index below it.
export async function commandCastSpell({ordinal=48,argc=9,self,spellId,targetId=OBJECT_INVALID,position=[0,0,0],
  metamagic=255,cheat=0,domainLevel=0,path=0,instant=0,classType=-1,spontaneous=0,executionContext=1},p){
  ordinal=integer(ordinal,'command');argc=integer(argc,'argument count');spellId=integer(spellId,'spell ID');
  const forced=ordinal===501||ordinal===502,location=ordinal!==48&&ordinal!==501;
  if(location)targetId=OBJECT_INVALID;
  // Optional args are read in groups by the original owner, rather than
  // each argument having an independent count check.
  if(ordinal===48){if(argc<7)instant=0;if(argc<8){classType=-1;spontaneous=0;}}
  else if(ordinal===234){if(argc<6)instant=0;if(argc<7){classType=-1;spontaneous=0;domainLevel=0;}}
  else{instant=0;classType=-1;spontaneous=0;domainLevel=0;}
  if(forced){domainLevel=0;metamagic=0;cheat=1;}
  if(spellId<0||spellId>integer(p.spellCount,'spell count'))return 0;
  path=integer(path,'projectile path');if(path<0||path>4)return 0;path=path===4?5:path;
  const actor=call(p,'object',self);
  if(executionContext!==1||!actor||!location&&!call(p,'object',targetId))return 0;
  const creature=call(p,'creature',actor),placeable=call(p,'placeable',actor);
  position=location?position.map(Math.fround):[0,0,0];
  if(creature){
    if(forced){await call(p,'addCreatureCast',creature,[spellId>>>0,0,0,0,0,...position,targetId>>>0,Number(location),0,1,path,instant>>>0,0,0xffffffff,255]);return 0;}
    if(integer(creature.nativeFieldEc,'commandability')===0)return 0;
    let index=255,casterLevel=255;
    classType=integer(classType,'class type');metamagic=integer(metamagic,'metamagic');
    const classes=call(p,'classes',creature);
    if(classType<0){
      if(cheat!==0)metamagic=0;
      else{
        let chosen=false,level=255,slot=0;
        for(let i=0;i<(classes.length&255);i++){
          const id=classes[i]&255;if(!call(p,'casterClass',id))continue;
          if(call(p,'memorizes',id)){
            const ready=call(p,'readyCount',creature,i&255,spellId>>>0);
            if((ready.count&255)===0||(ready.level&255)===255)continue;
            level=ready.level&255;slot=ready.slot&255;
          }else{
            if(metamagic===255)metamagic=0;
            if((call(p,'uses',creature,spellId>>>0,i&255,0,0)&255)===0)continue;
            const spell=call(p,'spell',spellId>>>0);if(!spell)continue;
            level=call(p,'level',spellId>>>0,id)&255;
            if(level===255){const master=call(p,'spell',spell.master>>>0);if(master)level=call(p,'level',spell.master>>>0,id)&255;if(level===255)level=spell.innate&255;}
            if(level===255)continue;
          }
          index=i&255;chosen=index!==8;break;
        }
        if(!chosen){
          if(call(p,'abilityReady',creature,spellId>>>0)!==1)return 0;
          casterLevel=call(p,'abilityCasterLevel',creature,spellId>>>0)&255;if(casterLevel===255)return 0;index=254;
        }
        if(metamagic===255)metamagic=call(p,'slotMetamagic',creature,index,level,slot)&255;
      }
    }else if(classType===255){
      index=254;if(call(p,'abilityReady',creature,spellId>>>0)===0)return 0;
      casterLevel=call(p,'abilityCasterLevel',creature,spellId>>>0)&255;
    }else{
      if(metamagic===255)return 0;
      index=classes.slice(0,classes.length&255).findIndex(id=>(id&255)===classType);
      if(index<0||index===8)return 0;index&=255;
    }
    await call(p,'addCreatureCast',creature,[spellId>>>0,index,domainLevel>>>0,metamagic>>>0,spontaneous>>>0,...position,
      targetId>>>0,Number(location),0,0,path,instant>>>0,0,0xffffffff,casterLevel]);
  }else if(placeable){
    if(!forced&&integer(placeable.nativeFieldEc,'commandability')===0)return 0;
    await call(p,'addPlaceableCast',placeable,[spellId>>>0,metamagic>>>0,...position,targetId>>>0,Number(forced),path]);
  }
  return 0;
}

// ExecuteCommandGetSpellLevelByClass1405306a0/GetSpellUsesLeft140530b10.
// Invalid input pushes a preliminary result AND then continues. Return all
// native outputs so the VM adapter can preserve its extra stack cell.
export function commandSpellLevel(classType,spellId,p){
  classType=integer(classType,'class type');spellId=integer(spellId,'spell ID');const out=[];
  if(classType<0||spellId<0)out.push(-1);
  let result=-1;const spell=call(p,'spell',spellId>>>0);
  if(spell){result=call(p,'level',spellId>>>0,classType&255)&255;
    if(result===255&&call(p,'spell',spell.master>>>0))result=call(p,'level',spell.master>>>0,classType&255)&255;
    if(result===255)result=-1;}
  out.push(result);return out;
}
export function commandSpellUses(objectId,classType,spellId,metamagic,domainLevel,p){
  classType=integer(classType,'class type');spellId=integer(spellId,'spell ID');metamagic=integer(metamagic,'metamagic');domainLevel=integer(domainLevel,'domain level');
  const out=[];if(spellId<0||metamagic<0||domainLevel<0)out.push(0);
  let result=0;const creature=call(p,'creatureById',objectId>>>0);
  if(creature){const classes=call(p,'classes',creature);for(let i=0;i<(classes.length&255);i++)if((classes[i]&255)===classType){result=call(p,'uses',creature,spellId>>>0,i&255,domainLevel&255,metamagic&255)&255;break;}}
  out.push(result);return out;
}
