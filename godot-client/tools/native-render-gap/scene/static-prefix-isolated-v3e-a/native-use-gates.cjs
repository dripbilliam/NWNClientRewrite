'use strict';
// Explicit role-only checks emitted by the sealed V3e verify_use source.
// Full raw check arrays remain in every observation and comparison receipt.
const assert=require('node:assert/strict');
const common='Actual cursor call required; no baseline-only pass';
const rollbackLabels=['Actual native G rollback_count positive','Actual G unexecuted skip rewind positive','Numeric FAR group actually scanned before rollback','Rewound current-key original prefix actually yielded','Rollback route cannot claim native terminal END',common];
const terminalLabels=['Exactly463 canonical groups scanned natively','Canonical near group admitted exactly once','Canonical463 keeps fallback0','Actual native owned-map terminal END positive','Canonical terminal END does not rewind',common];
const known=new Set([...rollbackLabels,...terminalLabels]);
function semanticChecks(value,role,mode){
 const expected=mode.startsWith('g-rollback-')?rollbackLabels:mode==='canonical-463-terminal'?terminalLabels:[];
 const observed=value.checks.filter(row=>known.has(row.label));
 if(role==='baseline')assert.equal(observed.length,0,'Original baseline cannot claim native use');
 else{assert.deepEqual(observed.map(row=>row.label),expected,'Exact selected native-check labels/order/count differ');assert(observed.every(row=>row.ok===true),'Native-use fixture assertion failed');const use=value.actual_use;
  if(expected.length){for(const key of ['rollback_count','rolled_back_unexecuted_skips','fast_terminal_scans'])assert(Number.isSafeInteger(use[key])&&use[key]>=0,'Actual selected G/H counter absent');}
  if(mode.startsWith('g-rollback-')){assert(use.rollback_count>0&&use.rolled_back_unexecuted_skips>0&&use.native_scanned>0&&use.native_fallback>0&&use.fast_terminal_scans===0,'Actual rollback route not proved');}
  if(mode==='canonical-463-terminal'){assert(use.native_scanned===463&&use.native_admit===1&&use.native_fallback===0&&use.fast_terminal_scans>0&&use.rollback_count===0&&use.rolled_back_unexecuted_skips===0,'Actual463 terminal fast route not proved');}
 }
 return value.checks.filter(row=>!known.has(row.label));
}
function events(value,mode){
 if(!mode.startsWith('g-rollback-'))return;
 const one=name=>{const rows=value.events.map((row,index)=>({row,index})).filter(item=>item.row[0]===name);assert.equal(rows.length,1,'Missing/duplicate rollback positive event '+name);return rows[0].index;};
 const released=one('deferred-last-state-predelete'),query=one('second-query'),returned=one('after-query-return');assert(released<returned);
 if(mode==='g-rollback-far-model-callback'){const callback=one('unsupported-model-is-empty'),cleared=one('after-model-cleared-first-states');assert(callback<cleared&&cleared<released&&released<query,'Model callback/state-reset PREDELETE order differs');}
 else{const cleared=one('after-query-cleared-first-states');assert(query<cleared&&cleared<released,'Pending/empty query-clear PREDELETE order differs');}
}
module.exports={semanticChecks,events,rollbackLabels,terminalLabels};
