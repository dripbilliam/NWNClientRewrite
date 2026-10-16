import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {executeOrdinaryCast} from '../src/spell_cast_action.js';
import {checkSpellComponents,automaticQuicken} from '../src/spell_components.js';
import {checkSpellReleaseFailure,checkCastConcentration} from '../src/spell_release.js';
import {parse2da} from '../src/area.js';
import {createObjectAction,setActionParameter} from '../src/object_actions.js';
import {consumeConvertedSpell} from '../src/spell_conversion.js';
import {cancelCounterspellReactions} from '../src/spell_counterspell.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-cast-action-observations.json',import.meta.url)));
test('ordinary native cast action timing and release ordering match original execution',async()=>{
  for(const row of oracle.rows){
    const c=row.case,calls=[],actor={id:99,nativeAttackField748:0,nativeTarget740:0,nativeField81c:c.consumed??0,nativeSpellImpact224:c.impactDone??0,
      nativeSpellTarget214:0,nativeSpellId218:0,nativeSpellSpontaneous228:0,nativeSpellTarget818:0,nativeSpellDomain21c:0,nativeSpellClass22c:0,nativeSpellMetamagic22d:0,nativeSpellFeat23c:0,
      nativeHaste760:c.haste??0,nativeField700:c.combatState??0,combatRound:{started:c.started??0}},target={id:100},node=createObjectAction(15,0),
      spell={id:1,master:c.master??1,metamagic:c.allowedMeta??63,innate:1,spontaneouslyCast:c.convertible??0,components:`${c.somatic===0?'':'s'}${c.verbal===0?'':'v'}`,userType:c.userType??1,conjureTime:c.conjure??1500,castTime:c.castTime??500,conjureAnimation:c.conjureAnim??1,castAnimation:c.castAnim??1,useConcentration:c.useConcentration??0};
    actor.nativeField8d4=c.componentFlags??65535;
    actor.nativeArcaneEffectD78=c.effectFailure??0;actor.nativeArcaneChestD79=c.chestFailure??0;actor.nativeArcaneShieldD7a=c.shieldFailure??0;
    actor.combatMode=c.combatMode??0;
    actor.nativeCounterspellers310=[...(c.counters??[]),...Array(10).fill(0x7f000000)].slice(0,10);
    actor.nativeCounterCount338=c.counterCount??(c.counters??[]).filter(id=>id!==0x7f000000).length;
    const counters=new Map([101,102,103].map(id=>[id,{id,nativeCounterSpell7fc:9,nativeCounterClass800:1,nativeCounterMeta801:16,nativeCounterDomain802:3,
      nativeSpellId218:0,nativeSpellTarget214:0,nativeSpellImpact224:0,nativeField81c:0,combatRound:{started:0}}]));
    const record=(o,entry)=>calls.push(counters.has(o.id)?['counter',o.id,...entry]:entry);
    const rules=Object.keys(c.rulesOverrides??{}).length?{ruleset:parse2da(`2DA V2.0\n\nLabel Value\n${Object.entries(c.rulesOverrides).map(([label,value],i)=>`${i} ${label} ${value}`).join('\n')}`)}:{};
    const flags=(c.instant?0x40000000:0)|(c.cheat?0x80000000:0),args=[1,c.class??0,c.domain??0,c.meta??0,c.spontaneous??0,100,0,0,0,flags,c.feat??-1,255];
    args.forEach((v,i)=>setActionParameter(node,i,[6,7,8].includes(i)?2:i===5?3:1,v));node.nativeField9c=c.nodeReady??1;
    const p={preflight:()=>{},dead:()=>{calls.push(['dead']);return c.dead??0;},dying:()=>{calls.push(['dying']);return c.dying??0;},
      setLock:(o,id)=>record(o,['lock',id]),spell:()=>c.spellExists===false?null:spell,uses:(_o,...args)=>{calls.push(['uses',...args]);return c.uses??1;},
      levelReady:()=>c.ready??1,
      remainingFeatUses:(_o,id)=>{calls.push(['featUses',id]);return c.featUses??1;},decrementFeatUses:(_o,id)=>calls.push(['decrementFeat',id]),equipped:(_o,slot)=>{calls.push(['equipped',slot]);return c.weapon===undefined||c.weapon===null?null:{baseItem:c.weapon};},
      consumeConverted:(...args)=>consumeConvertedSpell(...args,{spell:()=>spell,level:()=>c.level??1,metamagicCost:()=>c.metaCost??0,slots:()=>c.slots??[],consume:(_o,...args)=>{calls.push(['consume',...args]);return c.consume??1;}}),
      components:(_o,s,index,domain,meta)=>checkSpellComponents(actor,s,index,domain,meta,rules,
        {spell:id=>id!==1&&c.masterMissing?null:spell,hasFeat:(_o,id)=>Number(c.feats?.includes(id)??false),classType:()=>10,level:()=>c.level??1,metamagicCost:()=>c.metaCost??0}),
      object:()=>c.targetExists===false?null:target,targetGate:()=>{},activityManager:(_o,n)=>calls.push(['activityManager',n]),
      creature:id=>c.counterMissing?.includes(id)?null:counters.get(id)??null,
      automaticQuicken:(_o,s,index,domain,meta)=>automaticQuicken(actor,s,index,domain,meta,rules,{spell:id=>id!==1&&c.masterMissing?null:spell,hasFeat:(_o,id)=>Number(c.feats?.includes(id)??false),classType:()=>10,level:()=>c.level??1,metamagicCost:()=>c.metaCost??(meta===8?4:0)}),
      broadcast:(_o,...args)=>calls.push(['broadcast',...args]),startRound:(o,n)=>{record(o,['startRound',n]);o.combatRound.started=1;},
      decrementRound:(o,...args)=>record(o,['decrementRound',...args.map(v=>v>>>0)]),pause:(o,...args)=>record(o,['pause',...args]),pauseTimer:(o,...args)=>record(o,['pauseTimer',...args]),
      opportunity:(_o,...args)=>calls.push(['opportunity',...args]),elapsed:()=>c.elapsed??0,setAnimation:(o,n)=>record(o,['animation',n]),
      lineOfSight:()=>{calls.push(['los']);return c.los??1;},consume:(o,...args)=>{record(o,['consume',...args]);return counters.has(o.id)?c.counterConsume?.[o.id]??1:c.consume??1;},
      releaseChecks:async(_o,s,index,meta,automatic,options)=>{
        const release={...p,
        effects:()=>c.concentrationEffect?[{type:18}]:[],skill:(_o,...args)=>{calls.push(['skill',...args]);return c.concentrationRank??0;},skillName:()=>0,
        nearestEnemy:(_o,...args)=>{calls.push(['nearestEnemy',...args]);return c.enemy??0x7f000000;},
        skillMessage:(_o,message)=>calls.push(['skillMessage',message]),failureVisual:(_o,id)=>calls.push(['visualCreator',99],['visualInteger',0,id],['visualApply']),
        level:()=>((c.domain?c.domain&255:(c.level??1)===255?1:c.level??1)+(c.metaCost??(meta===8?4:0)))&255,
        arcaneClass:()=>c.arcane??0,school:()=>c.school??0,spellFailure:(_o,n)=>{calls.push(['spellFailure',n]);return c.failureBySchool?.[n]??0;},
        roll:(_count,sides)=>{const draw=calls.filter(v=>v[0]==='roll').length;calls.push(['roll',sides]);const rolls=c.rolls??[100,100];return rolls[Math.min(draw,rolls.length-1)];}};
        return await checkCastConcentration(actor,s,index,options.domain,meta,options.defensive,rules,release,options)&&await checkSpellReleaseFailure(actor,s,index,meta,automatic,rules,release,options);
      },hasFeat:(_o,id)=>Number(c.feats?.includes(id)??false),projectileTime:(o,n)=>record(o,['projectileTime',n]),
      counterSpellPending:o=>{record(o,['spellPending']);return c.counterPending??1;},removeCounterSpellAction:o=>record(o,['removeSpellAction']),
      fakeImpact:(o,id,point,targetId,path)=>calls.push(['fakeImpact',o.id,targetId,[0,0,0],[2,0,0],0,path?7:6,id,0,path]),
      impact:(_o,id,point,...args)=>{calls.push(['impact',id,...point,...args]);actor.nativeSpellImpact224=1;},feedback:(o,n)=>record(o,['feedback',n]),
      removeRoundSpell:()=>calls.push(['removeRoundSpell']),pendingEquipment:()=>calls.push(['pendingEquipment']),setCombatState:(_o,n)=>calls.push(['combatState',n])};
    p.counterFailure=(o,code)=>cancelCounterspellReactions(o,code,p);
    const result=await executeOrdinaryCast(actor,node,rules,p),label=JSON.stringify(c);
    assert.equal(result,row.result,label);assert.deepEqual(calls,row.calls,label);
    const fields={'0x214':actor.nativeSpellTarget214,'0x218':actor.nativeSpellId218,'0x224':actor.nativeSpellImpact224,'0x228':actor.nativeSpellSpontaneous228,
      '0x740':actor.nativeTarget740,'0x748':actor.nativeAttackField748,'0x818':actor.nativeSpellTarget818,'0x81c':actor.nativeField81c};
    assert.deepEqual(fields,row.fields,label);assert.equal(node.nativeField9c,row.nodeReady,label);assert.equal(actor.nativeSpellDomain21c,row.domain,label);
    assert.equal(actor.nativeSpellClass22c,row.classIndex,label);assert.equal(actor.nativeSpellMetamagic22d,row.metamagic,label);assert.equal(actor.nativeSpellFeat23c,row.feat,label);
    assert.equal(Number(actor.combatRound.started),row.started,label);
    if(c.counters){assert.equal(actor.nativeCounterCount338,row.counterCount,label);assert.deepEqual(actor.nativeCounterspellers310,row.counterIds,label);
      assert.deepEqual(Object.fromEntries([...counters].map(([id,o])=>[String(id),{id:o.nativeSpellId218,target:o.nativeSpellTarget214,impact:o.nativeSpellImpact224,consumed:o.nativeField81c,started:Number(o.combatRound.started)}])),row.counterState,label);}
  }
});
