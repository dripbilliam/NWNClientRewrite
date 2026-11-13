// Resolve the current nonprimary display immediately before an owned replay.
// Historical capsule display proofs cannot describe today's monitor ordering.
import {spawn} from 'node:child_process';
import path from 'node:path';

export function selectReplayDisplay(screens, requested) {
 if (!Array.isArray(screens) || screens.length < 1 || screens.length > 32 ||
     screens.some((screen, index) => screen?.index !== index || typeof screen.primary !== 'boolean' ||
       !Number.isSafeInteger(screen.workWidth) || screen.workWidth < 1 ||
       !Number.isSafeInteger(screen.workHeight) || screen.workHeight < 1) ||
     screens.filter(screen => screen.primary).length !== 1) throw Error('Invalid current display topology');
 if (requested !== undefined && (!/^\d+$/.test(String(requested)) || Number(requested) > 31)) throw Error('Invalid current replay display index');
 const secondary = screens.filter(screen => !screen.primary).sort((a, b) =>
   b.workWidth * b.workHeight - a.workWidth * a.workHeight || a.index - b.index);
 const screen = requested === undefined ? secondary[0] : screens[Number(requested)];
 if (!screen || screen.primary) throw Error('Current nonprimary monitor required; replay was not launched');
 return {screen:screen.index, primary:screens.find(screen => screen.primary).index,
   screens:screens.length, policy:requested === undefined ? 'current-largest-nonprimary' : 'explicit-current-nonprimary'};
}

export async function discoverReplayDisplay(project, invoke = spawn) {
 const helper = path.join(project, 'tools/native-window-screen.ps1');
 const command = `. '${helper.replaceAll("'", "''")}'; Get-NativeScreenTopology`;
 return new Promise((resolve, reject) => {
   const child = invoke('pwsh.exe', ['-NoProfile', '-NonInteractive', '-Command', command],
     {windowsHide:true, stdio:['ignore','pipe','pipe']});
   let stdout = '', stderr = '', done = false;
   const finish = (error, value) => {
     if (done) return;
     done = true; clearTimeout(timer);
     if (error) reject(error); else resolve(value);
   };
   const timer = setTimeout(() => { child.kill(); finish(Error('Read-only display discovery timed out')); }, 5000);
   child.stdout.on('data', data => {
     stdout += data;
     if (stdout.length > 8192) { child.kill(); finish(Error('Display discovery output exceeds bound')); }
   });
   child.stderr.on('data', data => { stderr = (stderr + data).slice(-2048); });
   child.once('error', error => finish(error));
   child.once('close', code => {
     if (code !== 0) return finish(Error('Read-only display discovery failed: ' + stderr.trim()));
     try { finish(null, JSON.parse(stdout)); } catch { finish(Error('Display discovery returned invalid JSON')); }
   });
 });
}

export async function resolveReplayDisplay({capsule, headless, requested, project}, discover = discoverReplayDisplay) {
 if (!capsule || headless) return null;
 const topology = await discover(project);
 return {...selectReplayDisplay(topology, requested), discoveredAt:new Date().toISOString()};
}

export function applyReplayDisplay(args, selection) {
 if (!selection) return args;
 // Remove only the engine option. Script arguments after -- retain their values.
 const boundary = args.indexOf('--');
 const engine = args.slice(0, boundary < 0 ? args.length : boundary);
 const tail = boundary < 0 ? [] : args.slice(boundary);
 const selected = [];
 for (let index = 0; index < engine.length; index++) {
   if (engine[index] === '--screen') { index++; continue; }
   if (engine[index].startsWith('--screen=')) continue;
   selected.push(engine[index]);
 }
 return ['--screen', String(selection.screen), ...selected, ...tail];
}

// Production records its own actual steady-window boundaries. Legacy perf140
// fields belong to older private capsules and cannot prove a production run.
export function verifyProductionReplayWindow(native, selection) {
 const errors=[], start=native?.startup_window;
 const begin=native?.performance_window?.view_begin, end=native?.performance_window?.view_end;
 if (!selection || !Number.isInteger(selection.screen) || !Number.isInteger(selection.primary) || selection.screen===selection.primary)
   errors.push('Current nonprimary display selection missing');
 if (!start || start.screen!==selection?.screen || start.primary!==selection?.primary || start.non_activating!==true)
   errors.push('Actual startup window differs from the nonactivating display selection');
 for (const [name, view] of [['begin',begin],['end',end]]) {
   if (!view || view.screen!==selection?.screen || view.primary_screen!==selection?.primary)
     errors.push('Actual steady-window '+name+' display evidence missing or mismatched');
   if (view?.unfocusable!==true || view?.focused!==false || view?.mouse_mode!==0)
     errors.push('Actual steady-window '+name+' focus/cursor evidence missing or mismatched');
 }
 return {status:errors.length?'rejected':'observed',errors,start,begin,end,
   scope:'Actual startup and both steady-window boundaries on the selected nonprimary monitor, unfocused with visible mouse; no continuous OS focus trace'};
}
