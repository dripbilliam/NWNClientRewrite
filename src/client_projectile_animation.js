const f=Math.fround;
// CNWCAnimBaseProjectile virtual+80,1409ddd00..1409ddd9d. The handle reports
// success even if Gob::PlayAnimation cannot find the named clip. Retain that
// behavior; renderer providers must separately diagnose unavailable assets.
export function playClientProjectileAnimation(model,stage,speed,flags,start,p){
 stage&=65535;speed=f(speed);flags|=0;start=f(start);if(speed===0)speed=1;
 let name;
 if(stage===0)name='default';
 else if(stage===1)name='travel01';
 else if(stage===2){name='impact01';flags|=1;}
 else{name='';speed=1;flags=0;}
 if(typeof p?.playAnimation!=='function')throw new Error('Native projectile model animation provider is unavailable');
 p.playAnimation(model,name,speed,flags,start);return 1;
}
// CNWCProjectile140985510..14098556a, with its projectile animation handle.
export function setClientProjectileStage(state,stage,p){
 if(!state.model)return 0;
 if(playClientProjectileAnimation(state.model,stage,1,0,0,p)!==0){state.stage=stage&65535;return 1;}return 0;
}
