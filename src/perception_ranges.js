import { intEntry,rulesetFloat } from './combat_stats.js';
import { nativeFloatEntry } from './movement_rate.js';
const f=Math.fround;
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native perception range ${n} is unavailable`);return v|0;};
// ReadStatsFromGff140410504..140410992. Player row12 bypasses the NPC
// PerceptionRange byte. NPC byte11 resolves appearance.PERCEPTIONDIST.
// Failed NPC cells abort native loading; earlier cache writes remain visible.
export function loadPerceptionRanges(actor,rules){
  const root=actor.creatureData??actor.authored??{},player=integer(root.IsPC??0,'PC flag')!==0;
  let index=12;
  if(!player){
    index=integer(root.PerceptionRange??11,'authored range')&255;actor.nativePerceptionRange798=index;
    if(index===12)throw new Error('Native creature loading rejects NPC PerceptionRange12');
    if(index===11){const entry=intEntry(rules.appearance,integer(root.Appearance_Type,'appearance')&65535,'PERCEPTIONDIST');
      if(!entry.found)throw new Error('Native appearance PERCEPTIONDIST is unavailable');index=entry.value;}
  }
  const primary=nativeFloatEntry(rules.ranges,index,'PrimaryRange');
  if(!player&&!primary.found)throw new Error('Native perception PrimaryRange load failed');
  actor.nativeSightRange7b0=primary.value;
  const secondary=nativeFloatEntry(rules.ranges,index,'SecondaryRange');
  if(!player&&!secondary.found)throw new Error('Native perception SecondaryRange load failed');
  actor.nativeHearingRange7b8=secondary.value;
}
// Perception fragment of PostProcess14039b9e6..14039bd52. Combat row10
// is replaced by row13 for NPCs when it would expand their current sight.
// No guessed distances: even ignored GetFLOATEntry results retain outputs.
export function postProcessPerceptionRanges(actor,rules,p){
  let primary=nativeFloatEntry(rules.ranges,10,'PrimaryRange').value,
    secondary=nativeFloatEntry(rules.ranges,10,'SecondaryRange').value;
  if(integer(p.pc(actor),'PC result')===0&&integer(p.possessed(actor),'possession result')===0){
    const current=integer(actor.nativeField700,'combat state')===0?actor.nativeSightRange7b0:actor.nativeCombatSightRange7b4;
    if(!Number.isFinite(current))throw new Error('Native current perception sight range is unavailable');
    if(primary>f(current)){
      primary=nativeFloatEntry(rules.ranges,13,'PrimaryRange').value;
      secondary=nativeFloatEntry(rules.ranges,13,'SecondaryRange').value;
    }
  }
  actor.nativeCombatHearingRange7bc=secondary;actor.nativeCombatSightRange7b4=primary;
  for(const [feat,label,fallback] of [[488,'BLINDSIGHT_RANGE_60_FEET',f(18.288)],[486,'BLINDSIGHT_RANGE_10_FEET',4],[485,'BLINDSIGHT_RANGE_5_FEET',2]]){
    if(integer(p.hasFeat(actor,feat),'blindsight feat')!==0){
      actor.visionFlags=(integer(actor.visionFlags,'vision flags')|32)&255;
      actor.blindSightRange=Math.min(rulesetFloat(rules,label,fallback),primary);break;
    }
  }
}
