// Only renderer-owned immutable rigid geometry uses this pool. Materials,
// animation-owned/deformed vertices and gameplay objects keep separate owners.
export class RendererModelGeometry{
 constructor(){this.records=new WeakMap();this.leases=new WeakMap();this.stats={created:0,reused:0,retired:0,active:0,owners:0};}
 create(source,build,instantiate){
  let record=this.records.get(source);if(record){this.stats.reused++;}else{const geometry=build();if(!geometry)return null;record={source,geometry,owners:0};this.records.set(source,record);this.stats.created++;this.stats.active++;}
  record.owners++;this.stats.owners++;
  try{const object=instantiate(record.geometry);this.leases.set(object,{record,released:false});return object;}catch(error){this.releaseRecord(record);throw error;}
 }
 releaseRecord(record){if(--record.owners===0){this.records.delete(record.source);record.geometry.dispose();this.stats.retired++;this.stats.active--;}this.stats.owners--;}
 release(object){
  const lease=this.leases.get(object);if(!lease)return false;
  if(!lease.released){lease.released=true;this.releaseRecord(lease.record);}
  // A producer replacing its leased geometry owns the replacement separately.
  return object.geometry===lease.record.geometry;
 }
 snapshot(){return{...this.stats};}
}
