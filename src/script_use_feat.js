import {OBJECT_INVALID} from './game_object_array.js';
const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native ActionUseFeat ${name} is unavailable`);return value|0;};
const directAuxiliary=id=>{
 if(id===5)return true;const index=(id-304)>>>0;
 return index<=38&&((0x7f80000003n>>BigInt(index))&1n)!==0n;
};

// Complete ExecuteCommandActionUseFeat14050ee70. VM typed pops and location
// lifetime belong to the VM boundary; generic actions are not enqueued here.
// The existing-target branch copies the SCRIPT ACTOR's position, not target's.
export async function scriptUseFeat(args,self,p){
 if(args.length<2)throw new Error('Native ActionUseFeat required VM arguments are unavailable');
 const id=integer(args[0],'feat ID'),targetId=integer(args[1],'target ID')>>>0;
 let auxiliary=0,location=null;
 if(args.length>2){
  if(args.length<4)throw new Error('Native ActionUseFeat requires its fourth VM location argument');
  auxiliary=integer(args[2],'auxiliary ID');location=args[3];
  if(!directAuxiliary(id)){const spell=p.spell(auxiliary);if(spell)auxiliary=spell.featId>>16;}
 }
 const actor=p.object(integer(self,'self ID')>>>0);if(!actor||!p.asCreature(actor))return 0;
 if(!p.area(p.asCreature(actor)))return 0;
 const use=async(target,areaId,point,creature)=>{await p.use(creature,id&65535,auxiliary&65535,target,areaId>>>0,point);return 0;};
 if(p.object(targetId)){
  const object=p.asObject(actor),point=object?p.position(object):[0,0,0],creature=p.asCreature(actor),area=p.area(p.asCreature(actor));
  if(!area)throw new Error('Native ActionUseFeat actor area became unavailable during dispatch');
  return use(targetId,area.id,point,creature);
 }
 if(location&&p.areaById(integer(location.areaId,'location area ID')>>>0)){
  if(!Array.isArray(location.position)||location.position.length!==3||!location.position.every(v=>typeof v==='number'))throw new Error('Native ActionUseFeat location point storage is unavailable');
  return use(OBJECT_INVALID,location.areaId,location.position.map(Math.fround),p.asCreature(actor));
 }
 const creature=p.asCreature(actor),area=p.area(p.asCreature(actor));
 if(!area)throw new Error('Native ActionUseFeat actor area became unavailable during dispatch');
 return use(targetId,area.id,null,creature);
}
