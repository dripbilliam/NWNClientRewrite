const f=Math.fround;
// Vector::Normalize14022db30 and normalize140230920 use sqrt(1/squared)
// and leave vectors within the original unit-length tolerance unchanged.
export function normalizeParticleVector(values){
  const [x,y,z]=values.map(f),squared=f(f(f(x*x)+f(y*y))+f(z*z));
  if(squared===1||squared>=0.9999899864196777&&squared<=1.0000100135803223)return[x,y,z];
  if(squared===0)return[1,0,0];
  const scale=f(Math.sqrt(f(1/squared)));return[x,y,z].map(v=>f(v*scale));
}
// Quaternion operator*14022ab00, native runtime order w,x,y,z. MDL disk
// quaternion order is separate. Retain the original SSE operation grouping.
export function multiplyParticleQuaternion(l,r){
  const [a,b,c,d]=l.map(f),[w,x,y,z]=r.map(f);
  return[f(f(f(f(a*w)-f(b*x))-f(c*y))-f(d*z)),
    f(f(f(f(b*w)+f(a*x))+f(c*z))-f(d*y)),
    f(f(f(f(a*y)-f(b*z))+f(c*w))+f(d*x)),
    f(f(f(f(b*y)+f(a*z))-f(c*x))+f(d*w))];
}
export function crossParticleVector(l,r){
  return[f(f(f(l[1])*f(r[2]))-f(f(l[2])*f(r[1]))),f(f(f(l[2])*f(r[0]))-f(f(l[0])*f(r[2]))),f(f(f(l[0])*f(r[1]))-f(f(l[1])*f(r[0])))];
}
// The directions are the quaternion's rotated native Z/Y axes, respectively.
export function particleQuaternionZ(quaternion){
  const [w,x,y,z]=quaternion.map(f),a=f(f(w*y)+f(x*z)),b=f(f(y*z)-f(w*x)),c=f(f(y*y)+f(x*x));
  return[f(a+a),f(b+b),f(1-f(c+c))];
}
export function particleQuaternionY(quaternion){
  const [w,x,y,z]=quaternion.map(f),a=f(f(x*y)-f(w*z)),b=f(f(z*z)+f(x*x)),c=f(f(w*x)+f(z*y));
  return[f(a+a),f(1-f(b+b)),f(c+c)];
}
// AnimateParticles140061461..1400615b5 writes X/Y/Z axes in this order.
export function particleQuaternionBasis(quaternion){
  const [w,x,y,z]=quaternion.map(f),twice=v=>f(v+v);
  return[f(1-twice(f(f(z*z)+f(y*y)))),twice(f(f(x*y)+f(w*z))),twice(f(f(x*z)-f(w*y))),
    ...particleQuaternionY(quaternion),...particleQuaternionZ(quaternion)];
}

export function rotateParticleVector(quaternion,vector){
  const [w,x,y,z]=quaternion.map(f),[a,b,c]=vector.map(f),twice=v=>f(v+v);
  // Quaternion operator*(Vector)14022ae90 has these exact early returns.
  if(w===1||a===0&&b===0&&c===0||x===0&&y===0&&z===0)return[a,b,c];
  const xx=f(x*x),yy=f(y*y),zz=f(z*z),xy=f(x*y),xz=f(x*z),yz=f(y*z),wx=f(w*x),wy=f(w*y),wz=f(w*z);
  return[
    f(f(f(f(1-twice(f(zz+yy)))*a)+f(twice(f(xy-wz))*b))+f(twice(f(wy+xz))*c)),
    f(f(f(f(1-twice(f(zz+xx)))*b)+f(twice(f(wz+xy))*a))+f(twice(f(yz-wx))*c)),
    f(f(f(twice(f(xz-wy))*a)+f(twice(f(yz+wx))*b))+f(f(1-twice(f(yy+xx)))*c))
  ];
}

export function particleRotationArc(from,to){
  from=normalizeParticleVector(from);to=normalizeParticleVector(to);
  const dot=f(f(f(to[0]*from[0])+f(to[1]*from[1]))+f(to[2]*from[2]));
  if(dot<=-1)return[0,1,0,0];
  const scale=f(Math.sqrt(f(f(dot+1)*2))),axis=crossParticleVector(from,to);
  return[f(scale*f(.5)),...axis.map(v=>f(v/scale))];
}
