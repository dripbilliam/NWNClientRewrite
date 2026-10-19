const f=Math.fround;
// Creature PlayAnimation7fc7d0: type6 correction fits one clip to the WORD
// correction duration; null-record turn requests use native animation speed.
export function clientMovementCue(request,clipSeconds,animationSpeed=1){
 const length=f(f(clipSeconds)*1000);if(!Number.isFinite(length)||length<0||!Number.isFinite(animationSpeed))throw new Error('Native movement cue parameters are unavailable');
 if(request.type===6){const duration=request.duration&65535;if(!duration)throw new Error('Native movement correction duration is zero');return{animation:request.animation,duration,speed:length>0?f(length/f(duration)):1,record:null,delay:0};}
 return{animation:request.animation,duration:Math.trunc(animationSpeed===0?length:f(length/Math.abs(f(animationSpeed))))>>>0,speed:f(animationSpeed),record:null,delay:0};
}
