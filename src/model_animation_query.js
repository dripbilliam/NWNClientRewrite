// Gob::GetAnimation0510b0 returns the first physical case-insensitive match's
// time, even when its run is marked done; -1 means no active matching run.
export function modelAnimationTime(runs,name){
 const key=String(name).split('\0')[0].toLowerCase(),run=runs.find(r=>r.clip0.name.toLowerCase()===key);return run?Math.fround(run.time14):-1;
}
