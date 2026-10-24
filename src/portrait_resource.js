const suffixes=['','t','s','m','l','h'];
// Original84c2f0/84c1b0: size0 is the unmodified ref. Sized portraits
// consider only1..5, in nearest-size order, including the ±4 endpoints.
export function portraitCandidates(base,size){
 if(!Number.isInteger(size)||size<0||size>5)throw new RangeError('Invalid portrait size');
 if(!base)return[];
 if(size===0)return[base];
 return[0,1,-1,2,-2,3,-3,4,-4].map(offset=>size+offset).filter(index=>index>=1&&index<=5).map(index=>base+suffixes[index]);
}
