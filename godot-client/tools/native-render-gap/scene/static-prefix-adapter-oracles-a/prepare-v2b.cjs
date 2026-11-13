'use strict';
// Report serialization only. All V2 actual inputs, exercise/assertions unchanged.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');const root=path.resolve(__dirname,'../../../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex'),pin=relative=>{const file=path.join(root,relative),b=fs.readFileSync(file);return{relative,file,bytes:b.length,sha256:sha(b)};};const stem='tools/native-render-gap/scene/static-prefix-adapter-oracles-a/';
const basePin=pin(stem+'fixture-v2.gd'),base=fs.readFileSync(basePin.file,'utf8');let run=base.slice(base.indexOf('func run()->void:'));assert(run.startsWith('func run()->void:'));assert.equal(run.split('JSON.stringify(report)').length,2);run=run.replace('JSON.stringify(report)','JSON.stringify(report_only(report))');
const helper=`extends "res://tools/native-render-gap/scene/static-prefix-adapter-oracles-a/fixture-v2.gd"
# Serialization ONLY, after all original actual input/assertion/var_to_bytes work.
# A nonfinite Float is represented by its exact original f64 little-endian bits;
# no numeric value is reconstructed from these report strings for any test.
func report_only(value: Variant)->Variant:
\tif value is float and not is_finite(value):
\t\tvar bits:=PackedByteArray();bits.resize(8);bits.encode_double(0,value)
\t\treturn {"nwn_report_nonfinite_float64_le_hex":bits.hex_encode()}
\tif value is Array:
\t\tvar result: Array=[]
\t\tfor child in value:result.append(report_only(child))
\t\treturn result
\tif value is Dictionary:
\t\tvar result: Dictionary={}
\t\tfor key in value:result[key]=report_only(value[key])
\t\treturn result
\treturn value
`;
const file=path.join(root,stem+'fixture-v2b.gd');fs.writeFileSync(file,helper+'\n'+run,{flag:'wx'});
const manifest={version:2,revision:'b-report-only-nonfinite-f64-bits',createdUtc:new Date().toISOString(),status:'SOURCE_ONLY_UNPARSED_UNEXECUTED_UNACCEPTED',nativeStarts:0,compilerStarts:0,casesDesigned:26,positiveCanonicalCases:4,requiredCounters:['native_cursor_calls','native_scanned','native_admit','native_fallback'],pins:['fixture.gd','fixture-v2.gd','fixture-v2b.gd','README-v2b.txt','prepare-v2b.cjs'].map(x=>pin(stem+x)),baseline:pin('systems/native_render/drive_collision_indexed.gd'),canonicalIndex:pin('systems/native_render/drive_spatial_index.gd'),parent:pin('.cache/native-render-gap/scene/static-prefix-adapter-oracles-a/manifest-v2.json'),reportSerialization:'Only final JSON.stringify(report) becomes JSON.stringify(report_only(report)). Recursive Array/Dictionary copy converts ONLY nonfinite scalar Float to exact eight-byte f64 little-endian hex object; finite values and original Variant inputs/bit assertions remain unchanged.',inheritedExerciseUnchanged:basePin,observerRequired:'Fresh observer must extend res://tools/native-render-gap/scene/static-prefix-adapter-oracles-a/fixture-v2b.gd. Merely copying this file while extending V2 does not activate the serializer.',scope:'Fresh report-only source derivative, retaining failed G/V2 logs and original manifest. This is not a numeric/kernel fix or semantic PASS; actual H acceptance remains root-owned.'};const output=path.join(root,'.cache/native-render-gap/scene/static-prefix-adapter-oracles-a/manifest-v2b.json');fs.writeFileSync(output,JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file:output,sha256:sha(fs.readFileSync(output)),fixture:pin(stem+'fixture-v2b.gd'),cases:26,status:manifest.status}));
