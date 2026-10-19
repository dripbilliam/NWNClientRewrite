const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native decrement spell uses ${name} is unavailable`);return value|0;};
const byte=(value,name)=>integer(value,name)&255;
const call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native decrement spell uses provider ${name} is unavailable`);return p[name](...args);};

// Complete ExecuteCommandDecrementSpellUses1405155c0..515992. Parent pointer
// and selected spell ID can diverge after remapping. Do not turn this into
// generic cast consumption: no unlimited flag, class order matters, and an
// attempted UnReadySpell ends the command even when that lower returns0.
export async function scriptDecrementSpellUses(p){
 let read=call(p,'pop','object');if(!read.ok)return -639;const objectId=integer(read.value,'object ID')>>>0;
 read=call(p,'pop','int');if(!read.ok)return -639;let id=integer(read.value,'spell ID')>>>0,spell=call(p,'spell',id);
 if(!spell)return 0;
 const original=id,master=integer(spell.master,'master')>>>0;
 if(master!==id){spell=call(p,'spell',master);if(!spell)spell=call(p,'spell',original);else id=integer(spell.master,'parent master')>>>0;}
 const actor=call(p,'creature',objectId);if(!actor)return 0;
 const stats=call(p,'stats',actor);let index=0;
 if(byte(call(p,'classCount',stats),'class count')!==0){
  do{
   const type=byte(call(p,'classType',stats,index),'class type');
   if(integer(call(p,'classFlag',type,'SpellCaster'),'class spellcaster flag')===1){
    if(integer(call(p,'classFlag',type,'MemorizesSpells'),'class memorizes flag')===0){
     if(byte(call(p,'uses',stats,id,index,0,0),'uses left')!==0){
      const level=byte(call(p,'level',spell,type),'spell level');call(p,'decrementDay',stats,index,level);return 0;
     }
    }else{
     let ready=call(p,'ready',call(p,'stats',actor),index,id);
     if(byte(ready.count,'ready count')!==0){
      const level=byte(ready.level,'ready level'),slot=byte(ready.slot,'ready slot'),selected=integer(call(p,'slotId',stats,index,level,slot),'selected spell')>>>0;
      if(selected!==0xffffffff){
       const record=call(p,'details',call(p,'classInfo',stats,index),level,slot);
       if(record&&(integer(record.id,'record spell')>>>0)===id&&integer(record.ready,'record readiness')===1){
        await call(p,'unready',stats,id,index,integer(record.domain,'record domain')!==0?level:0,byte(record.metamagic,'record metamagic'));return 0;
       }
      }
     }else if(integer(spell.spontaneouslyCast,'spontaneous conversion')!==0){
      let current=call(p,'stats',actor),cursor=0,level=byte(call(p,'level',spell,type),'conversion level');
      if(byte(call(p,'slotCount',current,index,level),'conversion slot count')!==0){
       do{
        current=call(p,'stats',actor);level=byte(call(p,'level',spell,type),'conversion level');
        const candidate=integer(call(p,'slotId',current,index,level,cursor&255),'conversion spell')>>>0;
        ready=call(p,'ready',call(p,'stats',actor),index,candidate);
        if(byte(ready.count,'conversion ready count')!==0){
         const selectedLevel=byte(ready.level,'conversion ready level'),selectedSlot=byte(ready.slot,'conversion ready slot');
         // Original515850 compares literal1, not OBJECT_INVALID/-1.
         if((integer(call(p,'slotId',stats,index,selectedLevel,selectedSlot),'conversion selected spell')>>>0)!==1){
          const record=call(p,'details',call(p,'classInfo',stats,index),selectedLevel,selectedSlot);
          if(record&&(integer(record.id,'conversion record spell')>>>0)===candidate&&integer(record.ready,'conversion record readiness')===1){
           await call(p,'unready',stats,candidate,index,byte(record.domain,'conversion record domain'),byte(record.metamagic,'conversion record metamagic'));return 0;
          }
         }
        }
        current=call(p,'stats',actor);cursor=(cursor+1)|0;level=byte(call(p,'level',spell,type),'conversion level');
       }while(cursor<byte(call(p,'slotCount',current,index,level),'conversion slot count'));
      }
     }
    }
   }
   index=(index+1)&255;
  }while(index<byte(call(p,'classCount',stats),'class count'));
 }
 if(integer(call(p,'abilityReady',stats,id),'ability membership')!==0){const level=byte(call(p,'abilityLevel',stats,id),'ability caster level');call(p,'setAbilityReady',stats,id,0,level);}
 return 0;
}
