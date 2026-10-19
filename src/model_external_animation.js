// CAurObject::AnimateExternal14008c080..14008c0bf. It advances the model
// header's counter on BOTH sides of the virtual animation call, re-reading the
// header afterward. This owner does not replace Gob::Animate's lower services.
export function animateExternalModel(model,delta,p){
 if(typeof p?.header!=='function'||typeof p?.animate!=='function')throw new Error('Native external model animation provider is unavailable');
 const before=p.header(model);if(!before){p.animate(model,Math.fround(delta));return;}
 before.counter=(before.counter+1)|0;p.animate(model,Math.fround(delta));
 const after=p.header(model);if(!after)throw new Error('Native external model header vanished during animation');after.counter=(after.counter+1)|0;
}
