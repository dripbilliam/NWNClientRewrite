import {isolatedHeadless} from './isolated-headless.mjs';
const mutations=process.argv.includes('--mutation-probe');
function validateEngineLog({proof,engineLog,stderr}){
 const expected=['dictionary_set','array_set','array_append','dictionary_index'];
 const rows=proof?.mutation_probe?.errors??[];
 const counts=Object.fromEntries(expected.map(tag=>[tag,rows.filter(v=>v.tag===tag).length]));
 const known=rows.length===5&&counts.dictionary_set===1&&counts.array_set===1&&counts.array_append===1&&counts.dictionary_index===2&&rows.every(v=>{
  if(!expected.includes(v.tag)||![0,2].includes(v.type))return false;
  if(v.type===0&&v.file==='core/variant/dictionary.cpp'&&v.function==='set'&&v.rationale==='Dictionary is in read-only state.')return ['dictionary_set','dictionary_index'].includes(v.tag);
  if(v.type===0&&v.file==='core/variant/array.cpp'&&v.rationale==='Array is in read-only state.')return v.tag==='array_set'&&v.function==='set'||v.tag==='array_append'&&v.function==='push_back';
  return v.tag==='dictionary_index'&&v.type===2&&v.function==='probe_index'&&v.file.endsWith('native_perf140_loading_readonly_loan_test.gd')&&v.code==="Invalid assignment on read-only value (on base: 'Dictionary').";
 });
 const headings=(engineLog.match(/^(?:SCRIPT ERROR|ERROR):/gm)??[]).length;
 const extra=/Parse Error|WARNING:|ObjectDB.*leak|resources still in use/m.test(engineLog+'\n'+stderr);
 return {success:proof?.mutation_probe?.expected_rejections===4&&proof?.mutation_probe?.expected_engine_diagnostics===5&&known&&headings===5&&!extra,expectedReadonlyRejections:4,expectedEngineDiagnostics:5,observedEngineErrorHeadings:headings,unexpectedDiagnostic:extra,scope:'Only exact native/script diagnostics for four tagged attempted readonly mutations are allowed; ordinary gate uses strict clean logs.'};
}
await isolatedHeadless({
 label:process.argv[2],pattern:/^readonly-loan-[a-z0-9-]+$/,
 script:'native_perf140_loading_readonly_loan_test.gd',
 directory:mutations?'checks-mutations':'checks',
 argumentsForVariant:variant=>['--expect-loan='+(variant==='candidate'),'--prepared-cache-write=disabled','--mutation-probe='+mutations],
 validateEngineLog:mutations?validateEngineLog:null
});
