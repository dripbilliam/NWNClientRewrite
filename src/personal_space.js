import { nativeFloatEntry } from './movement_rate.js';

// UpdatePersonalSpace1403a7c50..1403a8032. All GetFLOATEntry return/output
// branches are retained: missing CREPERSPACE copies the returned default0,
// unlike personal(.6), hit-distance(.5), height(1) explicit fallbacks.
// The textual row label never replaces the native physical appearance index.
export function updatePersonalSpace(actor,rules,p={}){
  const path=actor.nativePathInfo,appearance=(actor.creatureData??actor.authored)?.Appearance_Type;
  if(!path||!Number.isInteger(appearance))throw new Error('Native personal-space appearance/path is unavailable');
  const index=appearance&65535,read=column=>nativeFloatEntry(rules.appearance,index,column);
  const personal=read('PERSPACE');
  if(!personal.found)p.warning?.('Native warning: Invalid appearance type, personal space not set correctly');
  path.field4=personal.found?personal.value:Math.fround(.6);path.computeGridTolerance();
  const creature=read('CREPERSPACE');
  if(!creature.found)p.warning?.('Native warning: Invalid appearance type, creature personal space not set correctly');
  path.field8=creature.value;
  const hit=read('HITDIST');
  if(!hit.found)p.warning?.('Native warning: Invalid appearance type, creature hit distance not set correctly');
  path.raw.setFloat32(0x10,hit.found?hit.value:Math.fround(.5),true);
  const height=read('HEIGHT');
  if(!height.found)p.warning?.('Native warning: Invalid appearance type, creature height not set correctly');
  path.fieldC=height.found?height.value:1;
}
