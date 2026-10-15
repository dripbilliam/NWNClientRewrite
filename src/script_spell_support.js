const f=Math.fround;
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native spell script ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native spell script provider ${n} is unavailable`);return p[n](...args);};
// ExecuteCommandTimeConversions14054a260. Hours use the active world
// timer's minutes-per-hour BYTE; conversion order rounds at each FLOAT step.
export function spellTimeConversion(ordinal,value,minutesPerHour){
  ordinal=integer(ordinal,'time command');value=f(integer(value,'time count'));
  if(ordinal===121)return f(value*f(6));
  if(ordinal===122)return f(f(integer(minutesPerHour,'minutes per hour')&255)*f(value*f(60)));
  if(ordinal===123)return f(value*f(60));
  return 0;
}
// ExecuteCommandSavingThrow14053d2b0. All authored classic save helpers
// compile four arguments. The original two-argument path reads uninitialized
// category storage, which stays explicit rather than guessing a default zero.
export async function scriptSavingThrow(ordinal,args,self,p){
  if(args.length===3)throw new Error('Native saving-throw wrapper fourth VM argument is unavailable');
  if(args.length<2)throw new Error('Native saving-throw wrapper required arguments are unavailable');
  const actor=call(p,'object',integer(args[0],'save target')>>>0);if(actor?.objectType!==5)return 0;
  const category=args.length>2?integer(args[2],'save category'):integer(p.categoryScratch,'uninitialized save category');
  const versus=args.length>2?integer(args[3],'save versus')>>>0:integer(self,'script self')>>>0;
  const save=({108:1,109:2,110:3})[ordinal]??(args[0]&255);
  return(integer(await call(p,'save',actor,save&255,integer(args[1],'save DC')&65535,category&255,versus,1,0,0),'save result')&255);
}
