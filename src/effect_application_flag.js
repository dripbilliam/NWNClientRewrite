const retainedVisuals=new Set([...Array.from({length:28},(_,i)=>153+i),182,242,243,244]);
// ApplyEffect14048e3ce..68b/907..934, AFTER the effect handler. Exact
// consumed1 differs from any other result. Type67 and ordinary visuals preserve
// the flag; the listed visuals and retained mechanical effects clear it.
export function finishEffectApplicationFlag(object,effect,consumed,special,p){
 const type=effect.type&65535;
 if(consumed===1){if(type===40&&special===1&&object.nativeField180===1)return p.remove(object,effect.id);return;}
 if(type===30){if(retainedVisuals.has(effect.integers?.[0]|0))object.nativeField180=0;}
 else if(type!==67)object.nativeField180=0;
}
// Creature EventHandler14038e51e..565, event5. Generic ApplyEffect's final
// native argument is the same linked flag written at offset180.
export async function receiveCombatEffect(object,effect,apply){
 if(!effect)return;const linked=(effect.type&65535)===40;if(linked)object.nativeField180=1;
 await apply(effect,0,Number(linked));if(linked)object.nativeField180=0;
}
