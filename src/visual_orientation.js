// Complete CAurBehaviorAttachNoOrientation::Update140054ed0..140054f3d.
// Capture the object's current orientation on EACH update, run the base, then
// restore it on success using the live object field. It is not a constructor
// snapshot or an identity reset. Base attachment owns handles/events/lifetime.
export function updateVisualNoOrientation(behavior,delta,p){
 const quaternion=p.orientation(behavior.object18);
 const result=p.baseUpdate(behavior,delta);
 if(result)p.setOrientation(behavior.object18,quaternion);
 return result;
}
