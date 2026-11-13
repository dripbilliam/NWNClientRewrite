import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const [oldPath,newPath,label]=process.argv.slice(2);
if(!oldPath||!newPath||!label||!/^[a-z0-9-]+$/.test(label))throw Error('Usage: compare_rip_epochs.mjs OLD-ANNOTATION NEW-ANNOTATION FRESH-LABEL');
const output=path.join(project,'.cache/native-render-gap/particles',label);
if(fs.existsSync(output))throw Error('Retain previous comparison');
const hash=data=>crypto.createHash('sha256').update(data).digest('hex');
const oldBytes=fs.readFileSync(oldPath),newBytes=fs.readFileSync(newPath),before=JSON.parse(oldBytes),after=JSON.parse(newBytes);
const metrics=[
 ['resident field lookup',/field_value_at@resident/],
 ['private folded string hash (ambiguous aliases)',/_Find_last@V\?\$basic_string/],
 ['resident Var copy',/\?\?0Var@resident/],
 ['presentation frame',/\?frame@Owner@particle_presentation/],
 ['hot parameter binding',/\?read@Field@hot_parameters/],
 ['compact stream vertex write',/\?write@ParticleStreams/],
 ['compact geometry build',/\?build@compact_particle/],
 ['GDScript interpreter',/^GDScriptFunction::call\(/],
 ['Variant key comparison',/^Variant::hash_compare\(/],
 ['Dictionary has',/^Dictionary::has\(/],
 ['Dictionary getptr',/^Dictionary::getptr\(/],
 ['Dictionary copy',/^Dictionary::Dictionary\(Dictionary const&\)/],
 ['Variant reference',/^Variant::reference\(/],
 ['StringName copy',/^StringName::StringName\(StringName const&\)/],
 ['direct eligibility',/^\(anonymous namespace\)::direct_eligibility\(/],
 ['direct transform',/^\(anonymous namespace\)::direct_transform\(/],
 ['Node3D visibility',/^Node3D::is_visible_in_tree\(/],
 ['typed light input poll',/^NwnBuiltinLightInputRegistry::poll\(/]
];
const collect=(summary,expression)=>summary.functions.filter(row=>row.names.some(name=>expression.test(name))).reduce((sum,row)=>sum+row.count,0);
const rows=metrics.map(([metric,expression])=>{
 const oldCount=collect(before.middle,expression),newCount=collect(after.middle,expression);
 return {metric,oldCount,newCount,oldFraction:oldCount/before.middle.validSamples,newFraction:newCount/after.middle.validSamples,differencePercentagePoints:100*(newCount/after.middle.validSamples-oldCount/before.middle.validSamples)};
});
const result={version:1,before:{file:path.resolve(oldPath),sha256:hash(oldBytes),middleSamples:before.middle.validSamples},after:{file:path.resolve(newPath),sha256:hash(newBytes),middleSamples:after.middle.validSamples},rows,limitations:['Exact leaf RIP fractions only; these are not inclusive subsystem costs.','The newer bundle can execute more frames per second, so raw per-time sample fractions are not per-frame costs. Pair with independent main-thread frame timing before projecting savings.','Private string-hash aliases remain ambiguous and must not all be assigned to parameters, global key cache, or controller clips.','Configurations differ in several accepted features; only independent paired tests establish individual feature gains.']};
fs.mkdirSync(output,{recursive:true});fs.writeFileSync(path.join(output,'comparison.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({output,oldSamples:before.middle.validSamples,newSamples:after.middle.validSamples,rows},null,2));
