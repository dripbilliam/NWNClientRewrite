const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native floating text ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native floating text provider ${n} is unavailable`);return p[n](...args);};
// ExecuteCommandFloatingText14051d9d0 STRREF525/string526. Display-to-
// faction is any nonzero INT, sound remains raw. Only actual creature5.
export async function floatingText(ordinal,args,p){
  if(args.length<2)throw new Error('Native floating text VM arguments are unavailable');
  const id=integer(args[1],'target')>>>0,target=call(p,'object',id);if(target?.objectType!==5)return;
  const display=args.length>=3?integer(args[2],'faction display'):1,sound=args.length>=4?integer(args[3],'sound flag'):1;
  let data;
  if(ordinal===525){data={objectIds:[id],integers:Array(10).fill(0)};data.integers[0]=integer(args[0],'STRREF');data.integers[1]=sound;data.integers[9]=93;}
  else if(ordinal===526){data={objectIds:[id],integers:Array(10).fill(0),strings:[String(args[0])]};data.integers[0]=sound;data.integers[9]=94;}
  else return;
  if(display!==0)await call(p,'broadcast',target,data);else{const client=call(p,'client',id);if(client)await call(p,'send',client,11,data);}
}
