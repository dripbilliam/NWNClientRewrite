const f=Math.fround;
// Vector normalize140230920..1402309f5 in native XYZ order. Keeping the
// native basis preserves the fallback's +0 components and raw signed zeros.
export function normalizeNativeVector(vector){
 const [x,y,z]=vector.map(f),squared=f(f(f(x*x)+f(y*y))+f(z*z));
 if(squared===1||squared>=f(.99999)&&squared<=f(1.00001))return[x,y,z];
 if(squared===0)return[1,0,0];
 const scale=f(Math.sqrt(f(1/squared)));return[f(x*scale),f(y*scale),f(z*scale)];
}
