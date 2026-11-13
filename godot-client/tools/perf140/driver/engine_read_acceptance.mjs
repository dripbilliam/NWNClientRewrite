// Cold route-selection evidence only. This is not a particle correctness,
// visual, lifetime or performance oracle. Actual-engine fixtures are separate.
export function engineReadReportAcceptance(requested, nativeReport) {
 // The shutdown entry writes engine_read_modes_dump into this specific field.
 // perf140_cold_particles is a different particle census, not this readback.
 return engineReadAcceptance(requested,nativeReport?.perf140_particle_modes?.engine_reads);
}
export function engineReadAcceptance(requested, snapshot) {
 const result={requested,actual:snapshot?.actual_mode??null,available:snapshot?.available??null,verified:false,legacyOrdinary:false,failures:[]};
 if(!snapshot){
  result.legacyOrdinary=requested==='ordinary';
  result.verified=result.legacyOrdinary;
  if(!result.verified)result.failures.push('Explicit fused mode has no native cold witness');
  return result;
 }
 const fail=reason=>result.failures.push(reason),counts=snapshot.counts;
 const names=['eligible_calls','eligible_handled','validate_calls','validate_handled','transform_calls','transform_handled','unsupported','inactive','missing','wrong_type','extra_miss_validation_attempts','bad_responses'];
 if(snapshot.requested_mode!==requested||snapshot.actual_mode!==requested)fail('Requested and actual native routes differ');
 if(snapshot.cumulative!==true||!counts||names.some(key=>!Number.isSafeInteger(counts[key])||counts[key]<0))fail('Native cumulative operation counts are unavailable or invalid');
 if(snapshot.retained_node_rows!==0||snapshot.retained_callbacks!==0)fail('Unexpected retained scene owner/callback rows');
 if(result.failures.length)return result;
 if(counts.bad_responses!==0)fail('Native ABI response error was recorded');
 if(requested==='ordinary'){
  if(names.some(key=>counts[key]!==0))fail('Ordinary control performed fused operations');
 }else{
  if(snapshot.available!==true||snapshot.abi_revision!==1||!Number.isSafeInteger(snapshot.features)||(snapshot.features&31)!==31)fail('Required native read API is unavailable');
  if(counts.eligible_calls===0||counts.eligible_calls!==counts.eligible_handled)fail('Eligibility route was absent or used fallback');
  if(counts.unsupported!==0||counts.inactive!==0)fail('Fused operations used context/inactive fallback');
  if(requested==='eligibility'){
   if(counts.validate_calls!==0||counts.transform_calls!==0||counts.extra_miss_validation_attempts!==0)fail('Eligibility-only route performed fused pose reads');
  }else if(requested==='full'){
   if(counts.validate_calls===0||counts.validate_calls!==counts.validate_handled)fail('Live pose ID/type route was absent or used fallback');
   if(counts.transform_calls===0||counts.transform_calls!==counts.transform_handled||counts.extra_miss_validation_attempts!==counts.transform_calls)fail('Miss-only transform route was absent, inconsistent or used fallback');
  }else fail('Unknown requested read mode');
 }
 result.verified=result.failures.length===0;
 return result;
}
