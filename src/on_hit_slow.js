import {applyOnHitDuration} from './on_hit_duration.js';
// Compatibility entry for the independently verified original Slow owner.
export function applyOnHitSlow(actor,target,rounds,p){return applyOnHitDuration('Slow',actor,target,rounds,p);}
