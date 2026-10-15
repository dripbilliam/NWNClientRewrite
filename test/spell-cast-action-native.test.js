import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {executeOrdinaryCast} from '../src/spell_cast_action.js';
import {checkSpellComponents,automaticQuicken} from '../src/spell_components.js';
import {checkSpellReleaseFailure,checkCastConcentration} from '../src/spell_release.js';
import {parse2da} from '../src/area.js';
import {createObjectAction,setActionParameter} from '../src/object_actions.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-cast-action-observations.json',import.meta.url)));
test('ordinary native cast action timing and release ordering match original execution',async()=>{
  for(const row of oracle.rows){
    const c=row.case,calls=[],actor={id:99,nativeAttackField748:0,nativeTarget740:0,nativeField81c:c.consumed??0,nativeSpellImpact224:c.impactDone??0,
      nativeSpellTarget214:0,nativeSpellId218:0,nativeSpellSpontaneous228:0,nativeSpellTarget818:0,nativeSpellDomain21c:0,nativeSpellClass22c:0,nativeSpellMetamagic22d:0,nativeSpellFeat23c:0,
      nativeHaste760:c.haste??0,nativeField700:c.combatState??0,combatRound:{started:c.started??0}},target={id:100},node=createObjectAction(15,0),
      spell={id:1,master:c.master??1,metamagic:c.allowedMeta??63,innate:1,components:`${c.somatic===0?'':'s'}${c.verbal===0?'':'v'}`,userType:c.userType??1,conjureTime:c.conjure??1500,castTime:c.castTime??500,conjureAnimation:c.conjureAnim??1,castAnimation:c.castAnim??1,useConcentration:c.useConcentration??0};
    actor.nativeField8d4=c.componentFlags??65535;
    actor.nativeArcaneEffectD78=c.effectFailure??0;actor.nativeArcaneChestD79=c.chestFailure??0;actor.nativeArcaneShieldD7a=c.shieldFailure??0;
    actor.combatMode=c.combatMode??0;
    const rules=Object.keys(c.rulesOverrides??{}).length?{ruleset:parse2da(`2DA V2.0\n\nLabel Value\n${Object.entries(c.rulesOverrides).map(([label,value],i)=>`${i} ${label} ${value}`).join('\n')}`)}:{};
    const flags=(c.instant?0x40000000:0)|(c.cheat?0x80000000:0),args=[1,c.class??0,c.domain??0,c.meta??0,0,100,0,0,0,flags,-1,255];
    args.forEach((v,i)=>setActionParameter(node,i,[6,7,8].includes(i)?2:i===5?3:1,v));node.nativeField9c=c.nodeReady??1;
    const p={preflight:()=>{},dead:()=>{calls.push(['dead']);return c.dead??0;},dying:()=>{calls.push(['dying']);return c.dying??0;},
      setLock:(_o,id)=>calls.push(['lock',id]),spell:()=>c.spellExists===false?null:spell,uses:(_o,...args)=>{calls.push(['uses',...args]);return c.uses??1;},
      components:(_o,s,index,domain,meta)=>checkSpellComponents(actor,s,index,domain,meta,rules,
        {spell:id=>id!==1&&c.masterMissing?null:spell,hasFeat:(_o,id)=>Number(c.feats?.includes(id)??false),classType:()=>10,level:()=>c.level??1,metamagicCost:()=>c.metaCost??0}),
      object:()=>c.targetExists===false?null:target,targetGate:()=>{},activityManager:(_o,n)=>calls.push(['activityManager',n]),
      automaticQuicken:(_o,s,index,domain,meta)=>automaticQuicken(actor,s,index,domain,meta,rules,{spell:id=>id!==1&&c.masterMissing?null:spell,hasFeat:(_o,id)=>Number(c.feats?.includes(id)??false),classType:()=>10,level:()=>c.level??1,metamagicCost:()=>c.metaCost??(meta===8?4:0)}),
      broadcast:(_o,...args)=>calls.push(['broadcast',...args]),startRound:(_o,n)=>{calls.push(['startRound',n]);actor.combatRound.started=1;},
      decrementRound:(_o,...args)=>calls.push(['decrementRound',...args.map(v=>v>>>0)]),pause:(_o,...args)=>calls.push(['pause',...args]),pauseTimer:(_o,...args)=>calls.push(['pauseTimer',...args]),
      opportunity:(_o,...args)=>calls.push(['opportunity',...args]),elapsed:()=>c.elapsed??0,setAnimation:(_o,n)=>calls.push(['animation',n]),
      lineOfSight:()=>{calls.push(['los']);return c.los??1;},consume:(_o,...args)=>{calls.push(['consume',...args]);return c.consume??1;},
      releaseChecks:async(_o,s,index,meta,automatic,options)=>{
        const release={...p,
        effects:()=>c.concentrationEffect?[{type:18}]:[],skill:(_o,...args)=>{calls.push(['skill',...args]);return c.concentrationRank??0;},skillName:()=>0,
        nearestEnemy:(_o,...args)=>{calls.push(['nearestEnemy',...args]);return c.enemy??0x7f000000;},
        skillMessage:(_o,message)=>calls.push(['skillMessage',message]),failureVisual:(_o,id)=>calls.push(['visualCreator',99],['visualInteger',0,id],['visualApply']),
        level:()=>((c.domain?c.domain&255:(c.level??1)===255?1:c.level??1)+(c.metaCost??(meta===8?4:0)))&255,
        arcaneClass:()=>c.arcane??0,school:()=>c.school??0,spellFailure:(_o,n)=>{calls.push(['spellFailure',n]);return c.failureBySchool?.[n]??0;},
        roll:(_count,sides)=>{const draw=calls.filter(v=>v[0]==='roll').length;calls.push(['roll',sides]);const rolls=c.rolls??[100,100];return rolls[Math.min(draw,rolls.length-1)];}};
        return await checkCastConcentration(actor,s,index,options.domain,meta,options.defensive,rules,release,options)&&await checkSpellReleaseFailure(actor,s,index,meta,automatic,rules,release,options);
      },hasFeat:(_o,id)=>Number(c.feats?.includes(id)??false),projectileTime:(_o,n)=>calls.push(['projectileTime',n]),
      impact:(_o,id,point,...args)=>{calls.push(['impact',id,...point,...args]);actor.nativeSpellImpact224=1;},feedback:(_o,n)=>calls.push(['feedback',n]),
      removeRoundSpell:()=>calls.push(['removeRoundSpell']),pendingEquipment:()=>calls.push(['pendingEquipment']),setCombatState:(_o,n)=>calls.push(['combatState',n])};
    const result=await executeOrdinaryCast(actor,node,rules,p),label=JSON.stringify(c);
    assert.equal(result,row.result,label);assert.deepEqual(calls,row.calls,label);
    const fields={'0x214':actor.nativeSpellTarget214,'0x218':actor.nativeSpellId218,'0x224':actor.nativeSpellImpact224,'0x228':actor.nativeSpellSpontaneous228,
      '0x740':actor.nativeTarget740,'0x748':actor.nativeAttackField748,'0x818':actor.nativeSpellTarget818,'0x81c':actor.nativeField81c};
    assert.deepEqual(fields,row.fields,label);assert.equal(node.nativeField9c,row.nodeReady,label);assert.equal(actor.nativeSpellDomain21c,row.domain,label);
    assert.equal(actor.nativeSpellClass22c,row.classIndex,label);assert.equal(actor.nativeSpellMetamagic22d,row.metamagic,label);assert.equal(actor.nativeSpellFeat23c,row.feat,label);
    assert.equal(Number(actor.combatRound.started),row.started,label);
  }
});
