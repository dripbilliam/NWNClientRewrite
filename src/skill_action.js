import {OBJECT_INVALID} from './game_object_array.js';
import {addObjectAction,actionParameter} from './object_actions.js';
const required=(p,n)=>{if(typeof p?.[n]!=='function')throw new Error(`Native skill action provider ${n} is unavailable`);return p[n];};
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native skill action ${n} is unavailable`);return v|0;};
const byte=(v,n)=>integer(v,n)&255;
const f=Math.fround;
const bits=v=>{const view=new DataView(new ArrayBuffer(4));view.setFloat32(0,v,true);return view.getInt32(0,true);};
const timer=o=>{if(!(o.nativeSkillTimers878 instanceof Uint32Array)||o.nativeSkillTimers878.length<=13)throw new Error('Native pickpocket timer storage is unavailable');return o.nativeSkillTimers878[13];};
const queue=(o,id,group,params,front)=>addObjectAction(o.objectActionState,id,group,params,front);
const retry=(o,target,approach,group)=>queue(o,54,group,[{type:3,value:target},{type:1,value:approach}],true);

// UseSkill1403aa390 generic request guards and pickpocket case1403aa54a.
// Native switch returns1 without an action for passive/default skill IDs.
// Other active skills need their own action owners; do not fake success.
export async function usePickpocketSkill(o,skill,mode,target,point,area,item,force,p){
  skill=byte(skill,'skill ID');mode=byte(mode,'mode');target=integer(target,'target ID')>>>0;
  if(byte(o.nativeField771,'creature state')===5){await required(p,'feedback')(o,7);return 0;}
  if(await required(p,'canUseSkill')(o,skill)===0){await p.feedback(o,0);return 0;}
  const targetObject=required(p,'object')(target),creature=targetObject?.objectType===5?targetObject:null;
  if(creature&&await required(p,'hostileSkill')(skill)===1&&await required(p,'reaction')(o,target)===1){await p.feedback(o,187);return 0;}
  if(!targetObject&&point.every(v=>v===0))return 1;
  if(![0,2,4,5,8,9,13,14,18,22].includes(skill))return 1;
  if(skill!==13)throw new Error(`Native admitted skill ${skill} action owner is unavailable`);
  const remaining=timer(o);if(remaining!==0){await p.feedback(o,1,{integers:[Math.max(1,Math.floor(remaining/1000))]});return 0;}
  await required(p,'actionManager')(o,2);
  if(await p.canUseSkill(o,13)===0)return 1;
  if(creature&&await required(p,'isDM')(creature)===0&&target!==o.id&&creature.masterId===OBJECT_INVALID&&creature.areaId===o.areaId&&integer(o.nativeFieldEc,'commandable')!==0)
    queue(o,54,65535,[{type:3,value:target},{type:1,value:1}],false);
  return 1;
}

// AIActionPickPocket1403c50c0. First detection pass queues animation37 then
// a retry; the actual skill check/transfer follows that owned stage. All RNG
// draws, per-actor830/834 state and physical item candidates stay separate.
export async function executePickpocket(o,node,p){
  const reset=()=>{o.nativePickpocketStage830=0;o.nativePickpocketDetected834=0;};
  if(await required(p,'dead')(o)===1&&await required(p,'dying')(o)===1){reset();return 3;}
  await required(p,'activityManager')(o,2);
  const target=integer(actionParameter(node,0),'target ID')>>>0,approach=integer(actionParameter(node,1),'approach flag'),victim=required(p,'creature')(target);
  if(!victim){reset();return 3;}
  const remaining=timer(o);if(remaining){await required(p,'feedback')(o,1,{integers:[Math.max(1,Math.floor(remaining/1000))]});return 3;}
  const inRange=await required(p,'inUseRange')(o,target,0,0);
  if(inRange===0&&approach!==0){
    const out={point:[0,0,0],range:0};await required(p,'useRange')(o,target,out);
    retry(o,target,0,node.groupId);queue(o,19,node.groupId,[{type:3,value:target}],true);
    queue(o,17,node.groupId,[{type:3,value:target},{type:1,value:1},{type:2,value:bits(out.range)},{type:2,value:bits(f(out.range+f(.1)))},{type:1,value:1}],true);
    await required(p,'moveFront')(o,node.groupId,out.point,o.areaId,target,1,out.range);return 2;
  }
  if(byte(victim.nativeField771,'victim state')===15){await p.feedback(o,57);return 3;}
  const rank=(integer(await required(p,'rank')(o,13,victim,0),'pickpocket rank')<<24)>>24;
  let spot=(integer(await p.rank(victim,17,o,0),'spot rank')<<24)>>24;
  if(await required(p,'reaction')(victim,o.id)===2)spot=(spot+required(p,'rule')('SKILL_PICKPOCKET_HOSTILE_SPOT_BONUS',10))|0;
  if(integer(o.nativePickpocketStage830,'stage')===0){
    let detected=false;
    if((integer(victim.nativeField8d4,'victim state WORD')&65535)!==0){const seen=required(p,'dice')(1,20);detected=((p.dice(1,20)+rank)|0)<((seen+spot)|0);}
    o.nativePickpocketStage830=1;
    if(detected){
      o.nativePickpocketDetected834=1;retry(o,target,approach,node.groupId);
      queue(o,6,node.groupId,[{type:1,value:37},{type:2,value:bits(1)},{type:2,value:bits(2)},{type:1,value:1}],true);
      await p.feedback(victim,46,{objects:[o.id]});await required(p,'reputations')(target,o.id,1);
      if(await required(p,'associate')(victim,3,1)!==OBJECT_INVALID){const familiar=await p.associate(victim,3,1);if(await required(p,'client')(familiar))await required(p,'unpossess')(victim);}
      await p.feedback(o,150);await required(p,'clearActivities')(o,31);return 2;
    }
  }
  const word=integer(victim.nativeField8d4,'victim state WORD')&65535;
  const dc=Math.max(1,word===0?p.rule('PICKPOCKET_CREATURE_DEAD',0):await p.reaction(victim,o.id)===2?p.rule('PICKPOCKET_HOSTILE_CREATURE_DC',30):p.rule('PICKPOCKET_NEUTRAL_CREATURE_DC',20));
  const rolled=p.dice(1,20),total=(rolled+rank)|0;await required(p,'broadcastSkill')(o,{objects:[o.id],integers:[282,rolled,rank,dc,0,Number(total>=dc)]});
  let stolen=null;
  if(total>=dc){
    const gold=integer(victim.nativeGold898,'victim gold'),goldAmount=Math.min(total,gold);
    const preferGold=p.dice(1,100)<50&&gold!==0;
    const candidates=[];let last=null;
    if(!preferGold||goldAmount===0){
      const repo=required(p,'repository')(victim);
      if(repo)for(const id of repo.ids()){
        last=required(p,'item')(id);if(!last)continue;
        const base=required(p,'baseInfo')(last);if(!base)throw new Error('Native pickpocket candidate base storage is unavailable');
        if(base.container===1){
          const bag=p.repository(last);if(!bag)continue;
          if(bag.length===0){if(integer(last.pickpocketable,'pickpocketable')!==0&&integer(last.cursed,'cursed')===0)candidates.push(last);}
          else for(const childId of bag.ids()){last=p.item(childId);if(last&&integer(last.pickpocketable,'pickpocketable')!==0&&integer(last.cursed,'cursed')===0)candidates.push(last);}
        }else if(integer(last.pickpocketable,'pickpocketable')!==0&&integer(last.cursed,'cursed')===0)candidates.push(last);
      }
    }
    if(candidates.length){
      const selected=candidates[required(p,'random')()%candidates.length],previous=integer(selected.stolen,'stolen flag');selected.stolen=1;
      const ref={item:selected};const result=await required(p,'acquire')(o,ref,target,OBJECT_INVALID,255,255,0,0);stolen=ref.item;
      if(!stolen)throw new Error('Native pickpocket reads a null post-acquisition item');
      if(result===0){stolen.stolen=previous;await p.feedback(o,12);}
      else{
        // Original reads identification from the LAST scanned candidate (RBX
        // at1403c64c9/6559), independently of the chosen/transferred pointer.
        if(!last)throw new Error('Native pickpocket feedback reads an unavailable last candidate');
        const identified=integer(last.identified,'last candidate identification');
        await p.feedback(o,4,{objects:[target,stolen.id],integers:[identified]});
        if(integer(o.nativePickpocketDetected834,'detected flag')!==0)await p.feedback(victim,47,{objects:[o.id,stolen.id],integers:[identified]});
      }
    }else if(preferGold&&goldAmount!==0||!preferGold&&goldAmount!==0){
      await required(p,'removeGold')(victim,goldAmount,0);await required(p,'addGold')(o,goldAmount,0);
      await p.feedback(o,5,{integers:[goldAmount],objects:[target]});if(o.nativePickpocketDetected834!==0)await p.feedback(victim,48,{objects:[o.id]});
    }else await p.feedback(o,57);
  }
  if(integer(o.nativePickpocketDetected834,'detected flag')===1)await required(p,'event')(o.id,target,27,[stolen?.id??OBJECT_INVALID],[0]);
  reset();o.nativeSkillTimers878[13]=integer(p.rule('SKILL_PICKPOCKET_COOLDOWN',6000),'cooldown')>>>0;
  return 2;
}
