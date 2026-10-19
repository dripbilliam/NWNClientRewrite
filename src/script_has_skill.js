// GetHasSkill140525700..1405257d3. This asks native skill eligibility,
// not whether the current effective skill rank is positive.
export async function scriptHasSkill(skill,id,p){
 const found=await p.lookup(id>>>0);if(!Number.isInteger(found?.status))throw new Error('Native object-array lookup status is unavailable');if((found.status&255)!==0)return 0;
 if(!await p.asCreature(found.object))return 0;
 const creature=await p.asCreature(found.object);if(!creature)throw new Error('Native second creature cast is unavailable');
 const eligibility=await p.canUseSkill(creature,skill&255);if(!Number.isInteger(eligibility))throw new Error('Native skill eligibility result is unavailable');return Number((eligibility|0)===1);
}
