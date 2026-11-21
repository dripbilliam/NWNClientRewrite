'use strict';
// Read-only source/replay bound for the apparent second visual-animation read.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const pins={
 'systems/native_render/live_world.gd':'ec5c12122567a3824650dedbc0b212b3a0e2651d20825493ece161ea6bd4f422',
 'systems/network_motion.gd':'7b943610ba9765c8052e22fccdeaf2ca0e33f27eb86917db8ac44be5ab1d0762',
 'systems/native_render/combat_presentation.gd':'462c7446f8fd817b95db8b548f5f7788baede7f7368658a6890b5d601fda7bbc',
 'systems/combat_animation.gd':'d80611b55704feba5aab282fe4dd4d8b4082228c86ad0c2b889b1587e97f980a',
 'reports/nwn74-forward-census-d.performance.jsonl':'77884899f548d24b237611f08ebb639b25731fe007994ef88ce869babe0fd9c4'
};
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const text=Object.fromEntries(Object.entries(pins).map(([file,pin])=>{const bytes=fs.readFileSync(path.join(root,file));assert.equal(sha(bytes),pin,`Changed source: ${file}`);return [file,bytes.toString()]}));
const live=text['systems/native_render/live_world.gd'];
const apply=live.split('func apply_pose(id: int) -> void:')[1].split('func receive_combat(')[0];
assert(apply.includes('position=Vector3(movement.render.x,movement.render.z,-movement.render.y)'));
assert(!apply.includes('motion.pose('));
const loop=live.split('func _profile_process(delta: float) -> void:')[1];
const first=loop.indexOf('apply_poses()'),middle=loop.indexOf('combat.update(delta,desired)',first),last=loop.indexOf('motion.objects[id].visualAnimation=combat.visual_animation',middle);
assert(first>=0&&middle>first&&last>middle);
assert(apply.includes('movement.visualAnimation=combat.visual_animation(id,code)'));
const presentation=text['systems/native_render/combat_presentation.gd'];
assert(presentation.includes('engine.update(delta)'));
const combat=text['systems/combat_animation.gd'];
assert(combat.includes('for id in states.keys():')&&combat.includes('if play(id, int(cue.animation), float(cue.speed), false):'));
const rows=text['reports/nwn74-forward-census-d.performance.jsonl'].trim().split(/\r?\n/).map(JSON.parse).filter(x=>x.frame_profile?.frames===240).slice(-3);
assert.equal(rows.length,3);
const metrics=rows.map(row=>{const m=row.frame_profile.metrics;return {elapsedMs:row.elapsedMs,motionRows:m.count_motion_rows.mean,poseEvaluations:m.count_pose_evaluations.mean,unchangedTransforms:m.count_pose_unchanged_transforms.mean,motionFinishMeanMs:m.world_motion_finish_ms.mean,combatUpdateMeanMs:m.world_combat_update_ms.mean,poseInputsMeanMs:m.world_pose_inputs_ms.mean}});
assert(metrics.every(x=>x.motionRows===10&&x.poseEvaluations===10&&x.unchangedTransforms===8&&x.motionFinishMeanMs<0.02));
const receipt={issue:'NWN-78',scope:'Current-source second visual read and creature pose conversion gate; saved replay is historical timing bound',pins,metrics,conclusion:'The second visual read follows combat.update, which can play a queued cue and change visual. Creature apply_pose already uses current motion scalars directly, not a temporary NetworkMotion.pose dictionary. The entire finish loop was 0.0085-0.0086 ms mean in the saved scene, so even a hypothetical removal is too small to justify semantic risk.',productionEdited:false,fpsMeasured:false};
const out=path.join(root,'tools/nwn78/current-visual-read-gate.json');assert(!fs.existsSync(out));fs.writeFileSync(out,JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({sourcePinned:true,windows:metrics.length,motionFinishMeansMs:metrics.map(x=>x.motionFinishMeanMs),output:out}));
