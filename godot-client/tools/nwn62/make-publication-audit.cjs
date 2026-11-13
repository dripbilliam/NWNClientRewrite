"use strict";
// Source-only: emit a reviewed overlay, never mutate an input capsule or launch.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");
const sourceRoot = path.resolve(process.argv[2] || ".");
const output = path.resolve(process.argv[3] || ".cache/nwn62/publication-audit-a");
assert(!fs.existsSync(output), `Refusing to overwrite ${output}`);
const sha = value => crypto.createHash("sha256").update(value).digest("hex");
const manifest = {scope:"PRIVATE numeric ledger diagnostic overlay only; input untouched; no engine launch, budget, quota or loading-mark change", sourceRoot, files:[]};
function exact(source, before, after) {
  assert.equal(source.split(before).length-1, 1, `Expected one anchor: ${before}`);
  return source.replace(before, after);
}
function write(relative, source, result) {
  const file = path.join(output, relative);fs.mkdirSync(path.dirname(file), {recursive:true});fs.writeFileSync(file,result);
  manifest.files.push({path:relative,beforeSHA256:source===null?null:sha(source),afterSHA256:sha(result)});
}
const poolPath="systems/native_render/resource_pool.gd";
let source=fs.readFileSync(path.join(sourceRoot,poolPath),"utf8");let result=source;
result=exact(result,"var native_draw_captures: Array=[]", "const PublicationAudit=preload(\"res://tools/nwn62/publication_ledger_audit.gd\")\nvar publication_audit=PublicationAudit.new()\nvar native_draw_captures: Array=[]");
result=exact(result,"if publication_frame!=frame:\n", "if publication_frame!=frame:\n\t\tpublication_audit.finish_frame(self)\n");
result=exact(result,"func can_publish(priority: bool=false) -> bool:","func can_publish(priority: bool=false,phase: String=\"unlabeled\") -> bool:");
const publishReturn="\treturn (priority and priority_publications==0) or publications==0 and construction_steps==0 and completion_units==0 or elapsed<publication_budget_limit_us() and publications<maximum_publications_per_frame";
result=exact(result,publishReturn,publishReturn.replace("\treturn ","\tvar allowed: bool=")+"\n\tif not allowed:publication_audit.deny(phase,elapsed,publication_budget_limit_us(),publications>=maximum_publications_per_frame,\"publish\")\n\treturn allowed");
const consumeReturn="\treturn completion_units+_completion_depth<maximum_completion_units_per_frame and ((priority and priority_publications==0 and not _completion_priority) or _completion_depth==0 and completion_units==0 and publications==0 and construction_steps==0 or elapsed<publication_budget_limit_us())";
result=exact(result,consumeReturn,consumeReturn.replace("\treturn ","\tvar allowed: bool=")+"\n\tif not allowed:publication_audit.deny(\"asset\",elapsed,publication_budget_limit_us(),completion_units+_completion_depth>=maximum_completion_units_per_frame,\"completion\")\n\treturn allowed");
result=exact(result,"func construction_finished(began: int) -> void:\n\t_publication_frame()\n\tif _completion_depth==0:publication_us+=Time.get_ticks_usec()-began\n\tconstruction_steps+=1", "func construction_finished(began: int,phase: String=\"unlabeled\") -> void:\n\t_publication_frame()\n\tvar elapsed:=Time.get_ticks_usec()-began\n\tif _completion_depth==0:publication_us+=elapsed\n\tconstruction_steps+=1\n\tpublication_audit.record(phase,elapsed,\"construction\")");
result=exact(result,"func publication_finished(began: int,priority: bool=false) -> void:","func publication_finished(began: int,priority: bool=false,phase: String=\"unlabeled\") -> void:");
result=exact(result,"\tif _completion_depth==0:publication_us+=Time.get_ticks_usec()-began\n\tpublications+=1", "\tvar elapsed:=Time.get_ticks_usec()-began\n\tif _completion_depth==0:publication_us+=elapsed\n\tpublications+=1\n\tpublication_audit.record(phase,elapsed,\"publication\")");
result=exact(result,"\t\tvar elapsed:=Time.get_ticks_usec()-_completion_began;publication_us+=elapsed;completion_us+=elapsed;_completion_began=0", "\t\tvar elapsed:=Time.get_ticks_usec()-_completion_began;publication_us+=elapsed;completion_us+=elapsed;_completion_began=0\n\t\tpublication_audit.record(\"asset\",elapsed,\"completion\")");
result=exact(result,"\t\tvar progress: Dictionary=pending.template.staged_build_step(maximum_units,budget_us)", "\t\tvar audit_phase:=str(pending.template._build_progress.get(\"phase\",\"done\"))\n\t\tvar audit_began:=Time.get_ticks_usec()\n\t\tvar progress: Dictionary=pending.template.staged_build_step(maximum_units,budget_us)\n\t\tpublication_audit.record(audit_phase,Time.get_ticks_usec()-audit_began,\"template-phase-at-start\")");
result=exact(result,"\treturn state\n", "\tstate.publication_budget.audit=publication_audit.snapshot(self)\n\treturn state\n");
result=result.replaceAll("Template.identity(","_publication_audit_identity(");
result+="\nfunc _publication_audit_identity(bundle: Dictionary,pool) -> String:\n\tvar began:=Time.get_ticks_usec()\n\tvar key:=Template.identity(bundle,pool)\n\tpublication_audit.record(\"template\",Time.get_ticks_usec()-began,\"identity\")\n\treturn key\n";
write(poolPath,source,result);
const callsites=[
  ["systems/native_render/object_stream.gd","objects"],
  ["systems/native_render/area_stream.gd","terrain"],
  ["systems/native_render/creature_stream.gd","actors"],
  ["systems/native_render/live_world.gd","adoption"],
];
for(const [relative,label] of callsites){
  source=fs.readFileSync(path.join(sourceRoot,relative),"utf8");result=source;
  // Replace whole actual calls while balancing nested expressions. Pool API
  // capability checks and the surrounding timing/return flow stay unchanged.
  let count=0;
  function tagCalls(text, owner, name, extra) {
    const token=owner+"."+name+"(";let at=0,out="",hits=0;
    while(true){const start=text.indexOf(token,at);if(start<0){out+=text.slice(at);break;}
      let end=start+token.length,depth=1;
      while(end<text.length&&depth){if(text[end]==="(")depth++;else if(text[end]===")")depth--;end++;}
      assert.equal(depth,0);const args=text.slice(start+token.length,end-1);
      out+=text.slice(at,start)+token+extra(args)+")";at=end;hits++;
    }
    count+=hits;return out;
  }
  result=tagCalls(result,"pool","can_publish",args=>(args.trim()?args:"false")+`,\"${label}\"`);
  result=tagCalls(result,"pool","construction_finished",args=>args+`,\"${label}\"`);
  result=tagCalls(result,"budget_owner","construction_finished",args=>args+`,\"${label}\"`);
  result=tagCalls(result,"pool","publication_finished",args=>args+(args.includes(",")?"":",false")+`,\"${label}\"`);
  result=tagCalls(result,"budget_owner","publication_finished",args=>args+(args.includes(",")?"":",false")+`,\"${label}\"`);
  assert(count>0,`No audit callsites in ${relative}`);
  write(relative,source,result);manifest.files.at(-1).taggedCalls=count;
}
const helper="tools/nwn62/publication_ledger_audit.gd";
write(helper,null,fs.readFileSync(path.join(__dirname,"publication_ledger_audit.gd"),"utf8"));
const manifestPath=path.join(output,"manifest.json");fs.writeFileSync(manifestPath,JSON.stringify(manifest,null,2)+"\n");
console.log(JSON.stringify({output,manifestSHA256:sha(fs.readFileSync(manifestPath)),files:manifest.files.length},null,2));
