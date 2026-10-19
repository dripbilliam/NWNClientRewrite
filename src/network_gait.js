const f=Math.fround;
// Client8114d0 no-previous-animation gait branch, including script factor and
// visual scale. Native clip getter returns milliseconds; our parsed clips use
// seconds. Correction/previous-clip blending belongs to a separate owner.
export function clientGaitSpeed({animation,rate,script,factor=1,acceleration=1},{distance,clipSeconds,scale=1,scale2=1}){
 const creep=[78,79].includes(animation&65535);
 rate=creep?f(1600.0001220703125):f(rate);
 const stride=creep?f(.8):f(f(f(scale)*f(scale2))*f(distance)),lengthMs=f(f(clipSeconds)*1000);
 if(!Number.isFinite(rate)||!Number.isFinite(stride)||stride<=0||!Number.isFinite(lengthMs)||lengthMs<=0)throw new Error('Native movement gait parameters are unavailable');
 const strideMs=f(stride*1000),effective=script?f(rate*f(factor)):rate,speed=f(f(effective/1000)/f(strideMs/lengthMs));
 return script?speed:f(speed*f(acceleration));
}
