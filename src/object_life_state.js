const required=(p,name)=>{if(typeof p?.[name]!=='function')throw new Error(`Native life-state provider ${name} is unavailable`);return p[name];};
// Common GetCurrentHitPoints140495130 and GetMaxHitPoints140420350.
// Both return low WORDs; GetCurrent exact flag1 excludes temporary HP.
export function commonObjectHitPoints(object,maximum=false,excludeTemporary=0){
 const read=name=>{if(!Number.isInteger(object[name]))throw new Error(`Native object HP ${name} is unavailable`);return object[name]&65535;};
 const value=maximum?read('nativeMaxHPE4'):read('nativeBaseHPE0')+(excludeTemporary===1?0:read('nativeTemporaryHPE8'));
 return value<<16>>16;
}
const hp=(o,p)=>{const value=required(p,'hitPoints')(o,0);if(!Number.isInteger(value))throw new Error('Native life-state HP provider is unavailable');return value<<16>>16;};
const protectedCreature=(o,p)=>{
  if(!Number.isInteger(o.nativeField89c))throw new Error('Native creature PC field89c is unavailable');
  return (o.nativeField89c|0)!==0||required(p,'possessedFamiliar')(o)!==0;
};
// GetDead1404953b0 and GetIsPCDying140495620. The creature object INT89c
// is distinct from semantic player/client status and stats INTb0. HP queries
// are signed SHORT; dying deliberately asks for HP twice on the low-HP path.
export function nativeObjectDead(object,p){
  const creature=required(p,'creature')(object);
  const threshold=creature&&protectedCreature(creature,p)?-10:0;
  return hp(creature??object,p)<=threshold;
}
export function nativeObjectDying(object,p){
  const creature=required(p,'creature')(object);
  return Boolean(creature&&protectedCreature(creature,p)&&hp(object,p)<1&&hp(object,p)>-10);
}
