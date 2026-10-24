// Binding revisions change when the proven source presenter replaces a model,
// including remove/recreate with the same object ID. Poses never change them.
class ContentTracker {
 constructor(){this.reset(null,[]);}
 reset(scope,rows){this.scope=scope;this.installed=new Map(rows.map(r=>[r.id,r.revision]));this.sequence=0;}
 plan(snapshot,limit=8){
  const desired=new Set(snapshot.desired),ready=new Map(snapshot.ready.map(r=>[r.id,r.revision]));
  return{scope:this.scope,remove:[...this.installed.keys()].filter(id=>!desired.has(id)),upserts:[...ready].filter(([id,r])=>desired.has(id)&&this.installed.get(id)!==r).slice(0,limit).map(([id,revision])=>({id,revision}))};
 }
 valid(plan,snapshot){
  if(plan.scope!==this.scope)return false;
  const desired=new Set(snapshot.desired),ready=new Map(snapshot.ready.map(r=>[r.id,r.revision]));
  return plan.upserts.every(r=>desired.has(r.id)&&ready.get(r.id)===r.revision)&&plan.remove.every(id=>!desired.has(id));
 }
 commit(plan){
  if(plan.scope!==this.scope)throw Error('Retired native content plan');
  for(const id of plan.remove)this.installed.delete(id);
  for(const row of plan.upserts)this.installed.set(row.id,row.revision);
  return ++this.sequence;
 }
}
module.exports={ContentTracker};
