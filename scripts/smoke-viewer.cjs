// Run with Electron to check the bundled renderer; --interactive leaves it open.
const { app, BrowserWindow, ipcMain } = require('electron');
const { registerRuntimeLog, observeWindow, flushOnClose } = require('../electron/runtime_log.cjs');
const path = require('node:path');
const fs = require('node:fs/promises');

const interactive = process.argv.includes('--interactive');
const previewDoor = process.argv.includes('--preview-door');
const fullScene = process.argv.includes('--full-scene');
const checkScripts = process.argv.includes('--check-scripts');
const checkConversations = process.argv.includes('--check-conversations');
const checkUi = process.argv.includes('--check-ui');
const checkCharacter = process.argv.includes('--check-character');
const checkProgression = process.argv.includes('--check-progression');
const checkDiagnostics = process.argv.includes('--check-diagnostics');
const browserDiagnostics = process.argv.includes('--browser-diagnostics');
const focusCharacter = process.argv.includes('--focus-character');
const play = process.argv.includes('--play');
const characterAfter = process.argv.includes('--character-after');
const loadCharacter = checkConversations || checkCharacter || checkProgression || focusCharacter || characterAfter || process.argv.includes('--character');
const showJournal = process.argv.includes('--show-journal');
const checkRadial = process.argv.includes('--check-radial');
const checkGameplay = checkRadial || process.argv.includes('--check-gameplay');
const checkAnimations = !checkConversations && !checkGameplay && !checkScripts && !checkUi && !loadCharacter && (!interactive || previewDoor || process.argv.includes('--check-animations'));
const [installArgument, moduleArgument, area = 'angmarshouse', screenshot] = process.argv.slice(2).filter(argument => !['--interactive', '--preview-door', '--full-scene', '--check-animations', '--check-gameplay', '--check-radial', '--check-scripts', '--check-conversations', '--check-ui', '--show-journal', '--check-character', '--check-progression', '--check-diagnostics', '--browser-diagnostics', '--character', '--character-after', '--focus-character', '--play'].includes(argument));
if (!installArgument || !moduleArgument) {
  console.error('Usage: electron scripts/smoke-viewer.cjs <install> <module> [area] [screenshot.png] [--interactive] [--preview-door] [--full-scene]');
  app.exit(1);
} else {
  const smokeData = path.join(__dirname, '..', 'backups', `${interactive ? 'viewer-interactive-data' : 'viewer-smoke-data'}-${process.pid}`);
  require('node:fs').mkdirSync(smokeData, { recursive: true });
  app.setPath('userData', smokeData);
  app.setPath('logs', smokeData);
  app.setPath('crashDumps', smokeData);
  app.whenReady().then(async () => {
    const diagnosticLog = registerRuntimeLog(ipcMain, path.join(__dirname, '..', 'runtime-logs'));
    const window = new BrowserWindow({ show: false, width: 1440, height: 960,
      webPreferences: { preload: browserDiagnostics ? undefined : path.join(__dirname, '..', 'electron', 'preload.cjs'), contextIsolation: true, nodeIntegration: false, sandbox: true, backgroundThrottling: false, offscreen: !interactive } });
    flushOnClose(window, observeWindow(window, diagnosticLog));
    window.setMenuBarVisibility(false);
    app.on('window-all-closed', () => app.quit());
    const errors = [];
    const placeholderLogs = [];
    window.webContents.on('console-message', (_event, level, message, line, source) => { if (level >= 3) { errors.push(message); console.error('Renderer:',message,source,line); } });
    window.webContents.on('console-message', (_event, _level, message) => { if (message.startsWith('[Radial placeholder]')) placeholderLogs.push(message); });
    const evaluate = async code => {
      try { return await window.webContents.executeJavaScript(code); }
      catch (error) { throw new Error(`${error.message}\nRenderer expression: ${code}\n${errors.join('\n')}`); }
    };
    const waitFor = async condition => {
      const deadline = Date.now() + 90000;
      while (!await evaluate(condition)) {
        if (Date.now() > deadline) throw new Error('Viewer timed out: ' + await evaluate(`JSON.stringify({status:document.querySelector('#status-text').textContent,feedback:document.querySelector('#door-feedback').textContent,canvas:document.querySelector('canvas').dataset,radial:document.querySelector('.radial-title').textContent})`));
        if (await evaluate('document.querySelector("#status-text").textContent.includes("FAILED")')) throw new Error(errors.join('\n'));
        await new Promise(resolve => setTimeout(resolve, 150));
      }
    };
    try {
      await window.loadFile(path.join(__dirname, '..', 'dist', 'index.html'));
      window.webContents.debugger.attach('1.3');
      const setFiles = async (selector, files) => {
        const { root } = await window.webContents.debugger.sendCommand('DOM.getDocument');
        const { nodeId } = await window.webContents.debugger.sendCommand('DOM.querySelector', { nodeId: root.nodeId, selector });
        await window.webContents.debugger.sendCommand('DOM.setFileInputFiles', { nodeId, files });
      };
      await setFiles('#game-data-folder', [path.resolve(installArgument, 'data')]);
      await waitFor('document.querySelector("#status-text").textContent.startsWith("GAME DATA READY")');
      await setFiles('#hak-data-folder', [path.resolve(installArgument, 'data', 'hk')]);
      await waitFor('document.querySelector("#status-text").textContent.startsWith("HAK DATA READY")');
      const languageFolder = path.resolve(installArgument, 'lang', 'en', 'data');
      if (await fs.stat(languageFolder).then(() => true, () => false)) {
        await setFiles('#language-data-folder', [languageFolder]);
        await waitFor('document.querySelector("#status-text").textContent.startsWith("LANGUAGE DATA READY")');
      }
      if (loadCharacter && !characterAfter) {
        await setFiles('#character-file', [path.resolve(installArgument, 'data/lcv/wizard.bic')]);
        await waitFor(`document.querySelector('#status-text').textContent.startsWith('CHARACTER READY')`);
      }
      // Baseline character/UI tests isolate BIC import. The progression check
      // deliberately leaves real startup enabled and observes its SetXP call.
      if (!checkProgression && (checkConversations || checkCharacter || play)) await evaluate(`document.querySelector('#run-module-startup').checked=false`);
      await setFiles('#area-file', [path.resolve(moduleArgument)]);
      await waitFor('document.querySelector("#status-text").textContent.includes("AREA RENDERED")');
      if (checkProgression) await waitFor(`JSON.parse(document.querySelector('#model-canvas').dataset.characterStats).level===1`);
      if (characterAfter) {
        const previousId = await evaluate(`document.querySelector('#model-canvas').dataset.actorId`);
        await setFiles('#character-file', [path.resolve(installArgument, 'data/lcv/wizard.bic')]);
        await waitFor(`document.querySelector('#status-text').textContent.includes('CHARACTER LOADED')`);
        if(previousId!==await evaluate(`document.querySelector('#model-canvas').dataset.actorId`))throw new Error('Preview upgrade changed actor ID');
        await evaluate(`document.querySelector('.game-panel-footer button').click()`);
      }
      if (checkGameplay || checkScripts || checkAnimations) await evaluate(`{ if(document.body.classList.contains('game-mode')) document.querySelector('#game-mode-button').click(); }`);
      console.log('Entry:', await evaluate('document.querySelector("#view-caption").textContent'));
      // Startup can enqueue a jump after SetXP. Observe that dispatch rather
      // than racing it with a development area switch.
      if (checkProgression) await waitFor(`document.querySelector('#model-canvas').dataset.scriptBusy==='false' && document.querySelector('#model-canvas').dataset.scriptJumps==='0'`);
      const viewArea = checkProgression ? await evaluate(`document.querySelector('#model-canvas').dataset.areaResRef`) : area;
      if (!checkProgression) await evaluate(`{ const select = document.querySelector('#area-select'); select.value = ${JSON.stringify(viewArea)}; select.dispatchEvent(new Event('change')); }`);
      await waitFor('document.querySelector("#status-text").textContent.includes("AREA RENDERED")');
      await waitFor(`document.querySelector('#model-canvas').dataset.areaResRef===${JSON.stringify(viewArea)} && document.querySelector('#model-canvas').dataset.doorStates!==undefined`);
      const report = await evaluate(`({caption: document.querySelector('#view-caption').textContent,
        hudVisible: !document.querySelector('#movement-hud').hidden,
        doorAction: document.querySelector('#door-action').textContent,
        note: document.querySelector('#inspector-note').textContent})`);
      if (!report.hudVisible || !report.caption.startsWith(viewArea.toUpperCase())) throw new Error('Area/HUD check failed');
      if (report.note.includes('Models skipped:')) throw new Error('Model parsing regressed: ' + report.note);
      // Visible-window playback intentionally pauses while document.hidden.
      if (interactive) { window.show(); await waitFor('!document.hidden'); }
      report.animations = await evaluate(`Array.from(document.querySelector('#animation-object').options, option => ({value: option.value, label: option.textContent, clips: Number(option.dataset.clips)}))`);
      if (!report.animations.length) throw new Error('No animation instances registered');
      const checks = [];
      if (checkAnimations) await evaluate(`{ const tools = document.querySelector('#animation-tools-enabled'); tools.checked = true; tools.dispatchEvent(new Event('change')); }`);
      for (const category of checkAnimations ? ['Tile', 'Door', 'Placeable', 'Creature'] : []) {
        const candidates = report.animations.filter(option => option.label.startsWith(category + ' '));
        if (category === 'Creature') candidates.sort((a, b) => b.clips - a.clips);
        const object = candidates[0];
        if (!object) continue;
        await evaluate(`{ const object = document.querySelector('#animation-object'); object.value = ${JSON.stringify(object.value)}; object.dispatchEvent(new Event('change')); }`);
        const originalClip = await evaluate(`document.querySelector('#animation-clip').value`);
        const clip = await evaluate(`{ const options = Array.from(document.querySelector('#animation-clip').options); (options.find(option => ['walk', 'opening1', 'damage', 'default'].includes(option.value)) ?? options.find(option => option.value))?.value; }`);
        if (!clip) throw new Error('No representative clip for ' + object.label);
        await evaluate(`{ const clip = document.querySelector('#animation-clip'); clip.value = ${JSON.stringify(clip)}; clip.dispatchEvent(new Event('change')); }`);
        const before = await evaluate(`Number(document.querySelector('#animation-time').dataset.time)`);
        await new Promise(resolve => setTimeout(resolve, 400));
        const after = await evaluate(`Number(document.querySelector('#animation-time').dataset.time)`);
        if (after === before) throw new Error('Playback did not advance: ' + object.label + '/' + clip);
        await evaluate(`document.querySelector('#animation-play').click()`);
        const paused = await evaluate(`Number(document.querySelector('#animation-time').dataset.time)`);
        await new Promise(resolve => setTimeout(resolve, 200));
        if (paused !== await evaluate(`Number(document.querySelector('#animation-time').dataset.time)`)) throw new Error('Pause did not hold: ' + object.label);
        await evaluate(`document.querySelector('#animation-play').click()`);
        checks.push({ object: object.label, clip, before, after });
        if (category !== 'Creature') await evaluate(`{ const clip = document.querySelector('#animation-clip'); clip.value = ${JSON.stringify(originalClip)}; clip.dispatchEvent(new Event('change')); }`);
      }
      report.animationChecks = checks;
      if (previewDoor) {
        const door = report.animations.find(option => option.label.startsWith('Door '));
        if (!door) throw new Error('Selected area has no animated door');
        await evaluate(`{ const object = document.querySelector('#animation-object'); object.value = ${JSON.stringify(door.value)}; object.dispatchEvent(new Event('change')); const clip = document.querySelector('#animation-clip'); if (!Array.from(clip.options).some(option => option.value === 'opening1')) throw new Error('Door has no opening1 clip'); clip.value = 'opening1'; clip.dispatchEvent(new Event('change')); }`);
        report.preview = { object: door.label, clip: 'opening1' };
      }
      if (!checkAnimations) {
        const door = report.animations.find(option => option.label.startsWith('Door '));
        if (door) await evaluate(`{ const object = document.querySelector('#animation-object'); object.value = ${JSON.stringify(door.value)}; object.dispatchEvent(new Event('change')); }`);
      }
      // Show the last checked creature (or prop/door) in a useful close view.
      await evaluate(`{ const isolate = document.querySelector('#animation-isolate'); isolate.checked = ${checkAnimations && !fullScene}; isolate.dispatchEvent(new Event('change')); }`);
      await evaluate(`document.querySelector('#animation-focus').click()`);
      report.isolated = await evaluate(`document.querySelector('#animation-isolate').checked`);
      if (checkUi) {
        const key = async (key, code, virtualKeyCode) => { for(const type of ['keyDown','keyUp']) await window.webContents.debugger.sendCommand('Input.dispatchKeyEvent',{type,key,code,windowsVirtualKeyCode:virtualKeyCode}); };
        const clickUi = async selector => {
          const point = await evaluate(`{const b=document.querySelector(${JSON.stringify(selector)});if(!b)throw new Error('Missing UI control');const r=b.getBoundingClientRect();({x:r.x+r.width/2,y:r.y+r.height/2});}`);
          await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',clickCount:1,...point});
          await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',clickCount:1,...point});
        };
        await waitFor(`document.querySelector('#game-ui').dataset.journalEntries==='11' && document.querySelector('#game-ui').dataset.cutscene==='false'`);
        await key('j','KeyJ',74);
        // Panel rendering awaits resource I/O; a delivered key event does not
        // mean its controls already exist in the DOM.
        await waitFor(`document.querySelector('[data-tab="completed"]')!==null`);
        await clickUi('[data-tab="completed"]'); await waitFor(`document.querySelectorAll('.game-journal-entry').length===11`);
        await clickUi('.game-journal-entry summary'); await waitFor(`document.querySelector('.game-journal-entry').open`);
        const quest = await evaluate(`({name:document.querySelector('.game-journal-entry summary').textContent,text:document.querySelector('.game-journal-text').textContent.length})`);
        if(quest.text<30)throw new Error('Journal entry text was not resolved');
        const before=await evaluate(`document.querySelector('#model-canvas').dataset.actorPosition`);
        await window.webContents.debugger.sendCommand('Input.dispatchKeyEvent',{type:'keyDown',key:'w',code:'KeyW',windowsVirtualKeyCode:87});
        await new Promise(r=>setTimeout(r,250));
        await key('w','KeyW',87);
        if(before!==await evaluate(`document.querySelector('#model-canvas').dataset.actorPosition`))throw new Error('UI input leaked into movement');
        await clickUi('[data-tab="notes"]'); await evaluate(`{const t=document.querySelector('.game-notes');t.focus();t.value='Round-trip note';t.dispatchEvent(new Event('input'));}`);
        await key('Escape','Escape',27); await key('Escape','Escape',27);
        await key('i','KeyI',73); await waitFor(`document.querySelector('.game-inventory-grid')!==null`); await key('Escape','Escape',27);
        await key('c','KeyC',67); await waitFor(`document.querySelector('.game-stats')!==null`); await key('Escape','Escape',27);
        await key('m','KeyM',77); await waitFor(`document.querySelector('.game-map')!==null`); await key('Escape','Escape',27);
        const panels = [];
        for(const panel of ['spells','options','dialogue','store','barter','party','examine']){
          await evaluate(`{const s=document.querySelector('#ui-resource-select');s.value='';}`);
          if(['spells','options'].includes(panel))await key(panel==='spells'?'b':'o',panel==='spells'?'KeyB':'KeyO',panel==='spells'?66:79);
          else if(panel==='dialogue')await clickUi('.game-top-actions button:nth-child(2)');
          else await evaluate(`{const s=document.querySelector('#ui-panel-select');s.value=${JSON.stringify(panel)};s.dispatchEvent(new Event('change'));}`);
          await waitFor(`document.querySelector('#game-ui').dataset.panel===${JSON.stringify(panel)}`);panels.push(panel);await key('Escape','Escape',27);
        }
        const layouts=await evaluate(`Array.from(document.querySelector('#ui-resource-select').options).map(o=>o.value).filter(Boolean)`);
        for(const name of layouts){
          console.log('UI layout:', name);
          await evaluate(`{const s=document.querySelector('#ui-resource-select');s.value=${JSON.stringify(name)};s.dispatchEvent(new Event('change'));}`);
          await waitFor(`document.querySelector('.game-native-panel[data-native-gui="${name}"] .game-native-footer')!==null`);
          if(screenshot && ['pre_main','cg_main'].includes(name)){
            await evaluate('new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))');
            await fs.writeFile(path.resolve(screenshot+'.'+name+'.png'),(await window.webContents.capturePage()).toPNG());
          }
          await key('Escape','Escape',27);
        }
        await evaluate(`{const s=document.querySelector('#ui-resource-select');s.value='pre_main';s.dispatchEvent(new Event('change'));}`);
        await waitFor(`document.querySelector('.game-native-panel[data-native-gui="pre_main"] .game-native-footer')!==null`);
        await clickUi('.game-native-panel [data-tag="NewButton"]');
        await waitFor(`document.querySelector('.game-native-panel[data-native-gui="pre_newgame"] .game-native-footer')!==null`);
        await clickUi('.game-native-panel [data-tag="PreludeButton"]');
        await waitFor(`document.querySelector('.game-native-panel[data-native-gui="cg_main"] .game-native-footer')!==null`);
        await clickUi('.game-native-panel [data-tag="GenderButton"]');
        await waitFor(`document.querySelector('.game-native-panel[data-native-gui="cg_sex"] .game-native-footer')!==null`);
        await key('Escape','Escape',27); await key('Escape','Escape',27); await key('Escape','Escape',27); await key('Escape','Escape',27);
        await key('j','KeyJ',74);await clickUi('[data-tab="notes"]');
        if(await evaluate(`document.querySelector('.game-notes').value`)!=='Round-trip note')throw new Error('Journal notes lost on panel switch');
        await clickUi('[data-tab="completed"]'); if(!await evaluate(`document.querySelector('.game-journal-entry').open`))await clickUi('.game-journal-entry summary');
        report.ui={journalEntries:11,quest,notesRetained:true,inputCaptured:true,nativeLayouts:layouts.length,nativeLayoutsRendered:layouts.length,menuRoute:['pre_main','pre_newgame','cg_main','cg_sex'],panels};
      }
      if (checkScripts) {
        if(checkUi) await evaluate(`document.querySelector('.game-panel-footer button').click()`);
        const state = () => evaluate(`({...document.querySelector('canvas').dataset})`);
        const initial = await state();
        const click = async (point, button = 'left') => {
          await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mousePressed',...point,button,clickCount:1});
          await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mouseReleased',...point,button,clickCount:1});
        };
        const key = async (key,code,windowsVirtualKeyCode) => {
          await window.webContents.debugger.sendCommand('Input.dispatchKeyEvent',{type:'keyDown',key,code,windowsVirtualKeyCode});
          await window.webContents.debugger.sendCommand('Input.dispatchKeyEvent',{type:'keyUp',key,code,windowsVirtualKeyCode});
        };
        const focusAndPick = async tag => {
          const object = JSON.parse((await state()).objectRecords).find(o=>o.kind==='door' && o.tag===tag);
          if (!object) throw new Error(`Door ${tag} not registered`);
          await evaluate(`{const select=document.querySelector('#animation-object'); select.value=Array.from(select.options).find(o=>o.textContent==='Door · ${tag}').value;select.dispatchEvent(new Event('change'));document.querySelector('#animation-focus').click();}`);
          await new Promise(resolve=>setTimeout(resolve,200));
          const rect=await evaluate(`{const r=document.querySelector('canvas').getBoundingClientRect();({left:r.left,top:r.top,width:r.width,height:r.height});}`);
          for(let y=0.15;y<0.9;y+=0.025) for(let x=0.15;x<0.9;x+=0.025) {
            const point={x:Math.round(rect.left+rect.width*x),y:Math.round(rect.top+rect.height*y)};
            await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mouseMoved',...point});
            if((await state()).hoveredObject===String(object.id)) return {point,object};
          }
          throw new Error(`Cannot pick ${tag}: ${JSON.stringify(await state())}`);
        };
        if (area !== 'angmarshouse') throw new Error('--check-scripts requires angmarshouse');
        await waitFor(`document.querySelector('canvas').dataset.journalEntries==='11'`);
        const source = await focusAndPick('Angmar_Brogan');
        await click(source.point);
        await waitFor(`JSON.parse(document.querySelector('canvas').dataset.doorStates).some(d=>d.id===${source.object.id}&&d.state!==0&&!d.moving)&&document.querySelector('canvas').dataset.actionPhase==='idle'`);
        const opened = JSON.parse((await state()).doorStates).find(d=>d.id===source.object.id).state;
        await key('e','KeyE',69);
        await waitFor(`document.querySelector('canvas').dataset.areaResRef==='brogansarm'&&document.querySelector('#status-text').textContent.includes('AREA RENDERED')`);
        await waitFor(`JSON.parse(document.querySelector('canvas').dataset.objectRecords).some(o=>o.kind==='door'&&o.tag==='Brogan_Angmar')`);
        if ((await state()).actorId!==initial.actorId) throw new Error('Player ID changed during traversal');
        const destination = {object:JSON.parse((await state()).objectRecords).find(o=>o.kind==='door'&&o.tag==='Brogan_Angmar')};
        if(JSON.parse((await state()).doorStates).find(d=>d.id===destination.object.id).state!==opened) throw new Error('Linked door state was not mirrored');
        // The destination is authored locked. A normal return uses the already
        // open transition, rather than closing it then inventing an unlock.
        await key('e','KeyE',69);
        await waitFor(`document.querySelector('canvas').dataset.areaResRef==='angmarshouse'&&document.querySelector('#status-text').textContent.includes('AREA RENDERED')`);
        const returned=await state();
        if(returned.actorId!==initial.actorId || returned.journalEntries!=='11') throw new Error('Player state did not survive return');
        if(JSON.parse(returned.doorStates).find(d=>d.id===source.object.id).state!==opened) throw new Error('Door ID/state did not survive return');
        report.scripts={ route:['angmarshouse','brogansarm','angmarshouse'], actorId:Number(initial.actorId), doorIds:[source.object.id,destination.object.id], journalEntries:11, opened, startupDiagnostic:returned.scriptError };
        console.log('Script round trip:',JSON.stringify(report.scripts));
        if(interactive) { await focusAndPick('Angmar_Brogan'); await key('f','KeyF',70); }
      }
      if (checkGameplay) {
        const diagnostic = () => evaluate(`({ ...document.querySelector('canvas').dataset, feedback: document.querySelector('#door-feedback').textContent })`);
        const resting = await diagnostic();
        if (JSON.parse(resting.doorStates).some(door => door.moving)) throw new Error('Doors move without an action');
        const rect = await evaluate(`{ const r = document.querySelector('canvas').getBoundingClientRect(); ({left:r.left,top:r.top,width:r.width,height:r.height}); }`);
        let hit = null;
        // Probe actual pointer input and picking; no direct mutation of world state.
        for (let y = 0.15; y < 0.9 && !hit; y += 0.05) for (let x = 0.15; x < 0.9 && !hit; x += 0.05) {
          const point = {x:Math.round(rect.left+rect.width*x),y:Math.round(rect.top+rect.height*y)};
          await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mouseMoved',...point});
          const state = await diagnostic();
          if (JSON.parse(state.objectRecords).some(o=>o.kind==='door' && String(o.id)===state.hoveredObject)) hit = {...point,id:state.hoveredObject};
        }
        if (!hit) throw new Error('No visible door picked by pointer');
        const before = JSON.parse(resting.doorStates).find(door => door.id === Number(hit.id));
        await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mousePressed',x:hit.x,y:hit.y,button:'left',clickCount:1});
        await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mouseReleased',x:hit.x,y:hit.y,button:'left',clickCount:1});
        await waitFor(`document.querySelector('canvas').dataset.selectedObject === ${JSON.stringify(hit.id)}`);
        await waitFor(`document.querySelector('canvas').dataset.actionPhase === 'idle'`);
        const after = await diagnostic(), door = JSON.parse(after.doorStates).find(door => door.id === Number(hit.id));
        if (door.state === before.state || door.moving) throw new Error('Door action failed: '+after.feedback);
        report.gameplay = { target:hit.id, before:before.state, after:door.state, feedback:after.feedback, actorPosition:JSON.parse(after.actorPosition) };
        if (checkRadial) {
          const pointer = async (x,y) => {
            await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mouseMoved',x:Math.round(x),y:Math.round(y)});
            return (await diagnostic()).hoveredObject;
          };
          const click = async (point,button = 'left') => {
            await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mousePressed',...point,button,clickCount:1});
            await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mouseReleased',...point,button,clickCount:1});
          };
          const clickEntry = async slot => {
            const point = await evaluate(`{ const r=document.querySelector('.radial-entry[data-slot="${slot}"]').getBoundingClientRect(); ({x:Math.round(r.left+r.width/2),y:Math.round(r.top+r.height/2)}); }`);
            await click(point);
          };
          let openHit = null;
          for(let y=0.1;y<0.95&&!openHit;y+=0.025) for(let x=0.1;x<0.95&&!openHit;x+=0.025) {
            const point={x:Math.round(rect.left+rect.width*x),y:Math.round(rect.top+rect.height*y)};
            if (await pointer(point.x,point.y)===hit.id) openHit=point;
          }
          if (!openHit) throw new Error('Cannot pick the opened door for its radial menu');
          await click(openHit,'right');
          await waitFor(`!document.querySelector('.radial-overlay').hidden`);
          if (await evaluate(`document.querySelector('.radial-menu').dataset.target`) !== hit.id) throw new Error('Radial opened on the wrong target');
          if (await evaluate(`document.querySelector('.radial-entry[data-slot="2"]').getAttribute('aria-label')`) !== 'Close') throw new Error('Linked door radial lacks Close');
          await new Promise(resolve=>setTimeout(resolve,250));
          report.radial = { target:hit.id, icons:await evaluate(`document.querySelectorAll('.radial-entry img').length`) };
          await clickEntry(2);
          await waitFor(`JSON.parse(document.querySelector('canvas').dataset.doorStates).some(d=>d.id===${Number(hit.id)}&&d.state===0&&!d.moving)`);
          report.radial.closed = true;
          // Native Close bypasses linked traversal; verify a nested placeholder too.
          let closedHit = null;
          for(let y=0.1;y<0.95&&!closedHit;y+=0.025) for(let x=0.1;x<0.95&&!closedHit;x+=0.025) {
            const point={x:Math.round(rect.left+rect.width*x),y:Math.round(rect.top+rect.height*y)};
            if (await pointer(point.x,point.y)===hit.id) closedHit=point;
          }
          if (!closedHit) throw new Error('Cannot pick closed door after radial Close');
          await click(closedHit,'right'); await waitFor(`!document.querySelector('.radial-overlay').hidden`);
          await clickEntry(1); await waitFor(`document.querySelector('.radial-menu').dataset.depth==='1'`);
          await clickEntry(0); await waitFor(`document.querySelector('#door-feedback').textContent.includes('spellcasting is not implemented')`);
          report.radial.placeholder = JSON.parse((await diagnostic()).lastRadialAction);
          const key = async (key,code,windowsVirtualKeyCode) => {
            await window.webContents.debugger.sendCommand('Input.dispatchKeyEvent',{type:'keyDown',key,code,windowsVirtualKeyCode});
            await window.webContents.debugger.sendCommand('Input.dispatchKeyEvent',{type:'keyUp',key,code,windowsVirtualKeyCode});
          };
          // Exercise held-button selection, not just click-latched buttons.
          await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mousePressed',...closedHit,button:'right',clickCount:1});
          const openPoint = await evaluate(`{const r=document.querySelector('.radial-entry[data-slot="2"]').getBoundingClientRect();({x:Math.round(r.left+r.width/2),y:Math.round(r.top+r.height/2)});}`);
          await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mouseMoved',...openPoint,button:'right',buttons:2});
          await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mouseReleased',...openPoint,button:'right',clickCount:1});
          await waitFor(`document.querySelector('.radial-overlay').hidden && JSON.parse(document.querySelector('canvas').dataset.doorStates).some(d=>d.id===${Number(hit.id)}&&d.state!==0&&!d.moving)`);
          report.radial.heldRelease = true;
          // Opening side and actor position can change after a second use.
          // Repick now; a prior screen point can hit the player or swung leaf.
          let reopenedHit = null;
          for(let y=0.1;y<0.95&&!reopenedHit;y+=0.025) for(let x=0.1;x<0.95&&!reopenedHit;x+=0.025) {
            const point={x:Math.round(rect.left+rect.width*x),y:Math.round(rect.top+rect.height*y)};
            if (await pointer(point.x,point.y)!==hit.id) continue;
            await click(point,'right');
            if (await evaluate(`document.querySelector('.radial-menu').dataset.target`)===hit.id) reopenedHit=point;
            else await key('Escape','Escape',27);
          }
          if (!reopenedHit) throw new Error('Cannot right-pick reopened door');
          await waitFor(`!document.querySelector('.radial-overlay').hidden`);
          if (await evaluate(`document.querySelector('.radial-entry[data-slot="2"]').getAttribute('aria-label')`)!=='Close') throw new Error('Reopened door lacks Close');
          await clickEntry(2);
          await waitFor(`JSON.parse(document.querySelector('canvas').dataset.doorStates).some(d=>d.id===${Number(hit.id)}&&d.state===0&&!d.moving)`);
          // Modal input prevents movement; Back restores a lazy submenu's parent.
          await click(closedHit,'right'); await clickEntry(1);
          await waitFor(`document.querySelector('.radial-menu').dataset.depth==='1'`);
          const position = (await diagnostic()).actorPosition;
          await key('w','KeyW',87); await new Promise(resolve=>setTimeout(resolve,100));
          if ((await diagnostic()).actorPosition!==position) throw new Error('Movement leaked through modal radial input');
          await key('Backspace','Backspace',8); await waitFor(`document.querySelector('.radial-menu').dataset.depth==='0'`);
          await key('Escape','Escape',27); await waitFor(`document.querySelector('.radial-overlay').hidden`);
          report.radial.modalAndBack = true;
          const findKind = async kind => {
            for(let y=0.15;y<0.9;y+=0.04) for(let x=0.15;x<0.9;x+=0.04) {
              const point={x:Math.round(rect.left+rect.width*x),y:Math.round(rect.top+rect.height*y)};
              const id=await pointer(point.x,point.y);
              if (JSON.parse((await diagnostic()).objectRecords).some(o=>o.kind===kind && String(o.id)===id)) return point;
            }
            throw new Error('Cannot pick focused '+kind);
          };
          report.radial.families = [];
          for (const category of ['Placeable','Creature']) {
            const object=report.animations.find(option=>option.label.startsWith(category+' '));
            if (!object) continue;
            await evaluate(`{const select=document.querySelector('#animation-object');select.value=${JSON.stringify(object.value)};select.dispatchEvent(new Event('change'));document.querySelector('#animation-focus').click();}`);
            await new Promise(resolve=>setTimeout(resolve,150));
            const point=await findKind(category.toLowerCase());
            await click(point,'right'); await waitFor(`!document.querySelector('.radial-overlay').hidden`);
            report.radial.families.push({kind:category,entries:await evaluate(`document.querySelectorAll('.radial-entry').length`)});
            await clickEntry(0); await waitFor(`document.querySelector('#game-ui').dataset.panel==='examine'`);
            await key('Escape','Escape',27);
          }
          // HUD access also works when the preview actor is behind scenery.
          await key('f','KeyF',70); await new Promise(resolve=>setTimeout(resolve,150));
          const playerPoint = await evaluate(`{const r=document.querySelector('#player-actions').getBoundingClientRect();({x:Math.round(r.left+r.width/2),y:Math.round(r.top+r.height/2)});}`);
          await click(playerPoint,'right');
          await waitFor(`!document.querySelector('.radial-overlay').hidden`);
          if (await evaluate(`document.querySelector('.radial-menu').dataset.target`) !== (await diagnostic()).actorId) throw new Error('Cannot open player radial');
          await clickEntry(7); await waitFor(`document.querySelector('.radial-menu').dataset.depth==='1'`);
          await clickEntry(7); await waitFor(`document.querySelector('.radial-menu').dataset.depth==='2'`);
          await clickEntry(7);
          await waitFor(`document.querySelector('.radial-menu').dataset.depth==='3'`);
          await clickEntry(3); await waitFor(`document.querySelector('#door-feedback').textContent.includes('emote animation selection is not implemented')`);
          report.radial.families.push({kind:'Player',emoteDepth:3});
          let ground = null;
          for(let y=0.7;y<0.9&&!ground;y+=0.04) for(let x=0.2;x<0.8&&!ground;x+=0.04) {
            const point={x:Math.round(rect.left+rect.width*x),y:Math.round(rect.top+rect.height*y)};
            if (!await pointer(point.x,point.y)) ground=point;
          }
          if (!ground) throw new Error('No scenery point for ground radial');
          await click(ground,'right'); await waitFor(`document.querySelector('.radial-title').textContent==='Ground'`);
          await clickEntry(2); await waitFor(`document.querySelector('#door-feedback').textContent.includes('ground movement requests is not implemented')`);
          report.radial.ground = JSON.parse((await diagnostic()).lastRadialAction);
          if (!placeholderLogs.length) throw new Error('Placeholder did not emit a console log');
          report.radial.consolePlaceholders = placeholderLogs.length;
          // Leave a real door menu for the captured image.
          const doorOption=report.animations.find(option=>option.label.startsWith('Door '));
          await evaluate(`{const select=document.querySelector('#animation-object');select.value=${JSON.stringify(doorOption.value)};select.dispatchEvent(new Event('change'));document.querySelector('#animation-focus').click();}`);
          await new Promise(resolve=>setTimeout(resolve,150));
          closedHit=await findKind('door');
          await click(closedHit,'right'); await waitFor(`!document.querySelector('.radial-overlay').hidden`);
          report.radial.menu = await evaluate(`Array.from(document.querySelectorAll('.radial-entry'),b=>({slot:b.dataset.slot,label:b.getAttribute('aria-label'),disabled:b.disabled}))`);
        }
      }
      delete report.animations;
      if (checkProgression) {
        await waitFor(`document.querySelector('.game-health').textContent==='5/5' && document.querySelector('#game-ui').dataset.cutscene==='true'`);
        const pc = await evaluate(`JSON.parse(document.querySelector('#model-canvas').dataset.characterStats)`);
        const spells = await evaluate(`JSON.parse(document.querySelector('#model-canvas').dataset.characterSpellCounts)`);
        const health = await evaluate(`document.querySelector('.game-health').textContent`);
        if (pc.level !== 1 || pc.classes[0].id !== 10 || pc.xp !== 0 || pc.maxHP !== 5 || pc.feats.length !== 12 || health !== '5/5') throw new Error('Native startup progression did not reach the HUD: '+JSON.stringify({level:pc.level,classes:pc.classes,xp:pc.xp,maxHP:pc.maxHP,feats:pc.feats.length,health}));
        if (pc.combat?.baseAttackBonus !== 0 || JSON.stringify(pc.combat.baseSaves) !== JSON.stringify({fortitude:0,reflex:0,will:2})) throw new Error('Combat providers did not follow native startup level rollback');
        if (pc.combat.armorClass !== 17 || pc.combat.attackBonuses.melee !== 0 || pc.combat.attackBonuses.ranged !== 3 ||
            JSON.stringify(pc.combat.saves) !== JSON.stringify({fortitude:1,reflex:3,will:2})) throw new Error('Final combat providers did not follow native startup level rollback');
        if (spells[0].known !== 15 || spells[0].memorized !== 5) throw new Error('Live spellbook state was not reduced');
        if (!await evaluate(`document.querySelector('#run-module-startup').checked&&document.querySelector('#game-ui').dataset.cutscene==='true'`)) throw new Error('Startup/cutscene state was bypassed');
        report.progression = { stats: pc, spells, health, cutsceneStillLocked: true, openingComplete: false };
      }
      // The authored cutscene blocks character panels. Its live stats/HUD are
      // checked above; panel interaction is covered by the baseline fixture.
      if (!checkProgression && (checkCharacter || loadCharacter && interactive)) {
        await waitFor(`document.querySelector('#model-canvas').dataset.characterModel==='true'`);
        const pc = await evaluate(`JSON.parse(document.querySelector('#model-canvas').dataset.characterStats)`);
        if(pc.level!==(checkProgression ? 1 : 15) || pc.classes[0].id!==10 || pc.maxHP!==(checkProgression ? 5 : 77))throw new Error('BIC/progression stats not reflected in renderer');
        const expectedCombat = checkProgression ? {attack:0,saves:{fortitude:0,reflex:0,will:2}} : {attack:7,saves:{fortitude:5,reflex:5,will:9}};
        if (pc.combat?.baseAttackBonus !== expectedCombat.attack || JSON.stringify(pc.combat.baseSaves) !== JSON.stringify(expectedCombat.saves)) throw new Error('Bundled combat providers differ from the installed wizard rules');
        const expectedFinal = checkProgression ? { armor:17, melee:0, ranged:3, fortitude:1, reflex:3, will:2 }
          : { armor:17, melee:7, ranged:10, fortitude:6, reflex:8, will:9 };
        if (pc.combat.armorClass !== expectedFinal.armor || pc.combat.attackBonuses.melee !== expectedFinal.melee || pc.combat.attackBonuses.ranged !== expectedFinal.ranged ||
            Object.keys(pc.combat.saves).some(name => pc.combat.saves[name] !== expectedFinal[name])) throw new Error('Bundled final stat providers differ from the verified wizard fixture');
        const panel = async name => { await evaluate(`{const s=document.querySelector('#ui-panel-select');s.value=${JSON.stringify(name)};s.dispatchEvent(new Event('change'));}`); };
        await panel('character'); await waitFor(`document.querySelector('[data-stat="xp"]')!==null`);
        if (!await evaluate(`document.querySelector('.game-panel-body').textContent.includes('Spectorial Melimion')`))throw new Error('Character identity missing');
        const combatRows = await evaluate(`Object.fromEntries(Array.from(document.querySelectorAll('.game-stats dt')).filter(dt=>['Base attack bonus','Base Fortitude','Base Reflex','Base Will'].includes(dt.textContent)).map(dt=>[dt.textContent,dt.nextElementSibling.textContent]))`);
        if (JSON.stringify(combatRows) !== JSON.stringify({'Base attack bonus':String(expectedCombat.attack),'Base Fortitude':String(expectedCombat.saves.fortitude),'Base Reflex':String(expectedCombat.saves.reflex),'Base Will':String(expectedCombat.saves.will)})) throw new Error('Character panel combat values are unavailable or mislabeled');
        const finalRows = await evaluate(`Object.fromEntries(Array.from(document.querySelectorAll('.game-stats dt')).filter(dt=>['Armor class','Melee attack bonus','Offhand attack bonus','Ranged attack bonus','Fortitude','Reflex','Will'].includes(dt.textContent)).map(dt=>[dt.textContent,dt.nextElementSibling.textContent]))`);
        if (JSON.stringify(finalRows) !== JSON.stringify({'Armor class':String(expectedFinal.armor),'Melee attack bonus':String(expectedFinal.melee),'Offhand attack bonus':String(expectedFinal.melee),
            'Ranged attack bonus':String(expectedFinal.ranged),'Fortitude':String(expectedFinal.fortitude),'Reflex':String(expectedFinal.reflex),'Will':String(expectedFinal.will)})) throw new Error('Final combat panel rows are unavailable or mislabeled');
        await evaluate(`document.querySelectorAll('.game-panel-tabs button')[2].click()`); await waitFor(`document.querySelectorAll('.game-feat').length===${checkProgression ? 12 : 20}`);
        await evaluate(`document.querySelector('.game-panel-tabs button').click()`);
        await evaluate(`document.querySelector('.game-panel-footer button').click()`);
        await panel('inventory'); await waitFor(`document.querySelector('.game-inventory-grid')!==null`);
        const items=await evaluate(`Array.from(document.querySelectorAll('.game-item-slot[data-object-id]')).filter(b=>b.dataset.objectId).map(b=>({id:Number(b.dataset.objectId),name:b.textContent}))`);
        if(items.length!==5 || items.some(i=>!i.name))throw new Error('Carried BIC items missing');
        await evaluate(`document.querySelector('.game-panel-tabs button').click()`); await waitFor(`document.querySelector('.game-equipment')!==null`);
        if(await evaluate(`document.querySelectorAll('.game-equipment [data-object-id]').length`)!==3)throw new Error('BIC equipment missing');
        await evaluate(`document.querySelector('.game-panel-footer button').click()`);
        await panel('spells'); await waitFor(`document.querySelectorAll('[data-spell-id]').length>0`);
        const known=await evaluate(`document.querySelectorAll('[data-spell-id]').length`);
        await evaluate(`document.querySelectorAll('.game-panel-tabs button')[1].click()`);
        const memorized=await evaluate(`document.querySelectorAll('[data-spell-id]').length`);
        if(known!==(checkProgression ? 15 : 43) || memorized!==(checkProgression ? 5 : 34))throw new Error('Live spellbook counts differ: '+known+'/'+memorized);
        await evaluate(`document.querySelector('.game-panel-footer button').click()`);
        await panel('character');
        await waitFor(`Array.from(document.querySelectorAll('.game-stats dt')).some(dt=>dt.textContent==='Armor class')`);
        await evaluate(`Array.from(document.querySelectorAll('.game-stats dt')).find(dt=>dt.textContent==='Armor class').scrollIntoView({block:'start'})`);
        report.character={stats:pc,carriedItems:items,known,memorized,model:true,combatRows,finalRows};
        if(!await evaluate(`document.body.classList.contains('game-mode')`))await evaluate(`document.querySelector('#game-mode-button').click()`);
      }
      if(showJournal && !checkUi){
        await waitFor(`document.querySelector('#game-ui').dataset.journalEntries==='11'`);
        await evaluate(`{const s=document.querySelector('#ui-panel-select');s.value='journal';s.dispatchEvent(new Event('change'));document.querySelector('[data-tab="completed"]').click();}`);
        await waitFor(`document.querySelectorAll('.game-journal-entry').length===11`);
        await evaluate(`document.querySelector('.game-journal-entry').open=true`);
      }
      if (checkConversations) {
        if (area !== 'brogansarm') throw new Error('--check-conversations requires brogansarm');
        await evaluate(`{document.querySelector('.game-panel-footer button')?.click();document.querySelector('#release-test-cutscene').click();}`);
        await waitFor(`document.querySelector('#game-ui').dataset.cutscene==='false'`);
        const actorId = await evaluate(`document.querySelector('canvas').dataset.actorId`);
        const xp = () => evaluate(`JSON.parse(document.querySelector('canvas').dataset.characterStats).xp`);
        const startXP = await xp();
        const click = async (point, button = 'left') => {
          for (const type of ['mousePressed', 'mouseReleased']) await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent', { type, ...point, button, clickCount: 1 });
        };
        const clickUi = async selector => click(await evaluate(`{const r=document.querySelector(${JSON.stringify(selector)}).getBoundingClientRect();({x:r.left+r.width/2,y:r.top+r.height/2});}`));
        const focusAndPick = async (kind, tag) => {
          const object = await evaluate(`JSON.parse(document.querySelector('canvas').dataset.objectRecords).find(o=>o.kind===${JSON.stringify(kind)}&&o.tag===${JSON.stringify(tag)})`);
          if (!object) throw new Error('Missing interaction object ' + tag);
          const label = `${kind[0].toUpperCase()+kind.slice(1)} · ${tag}`;
          await evaluate(`{const select=document.querySelector('#animation-object');const option=Array.from(select.options).find(o=>o.textContent===${JSON.stringify(label)});if(!option)throw new Error('Missing focus target');select.value=option.value;select.dispatchEvent(new Event('change'));document.querySelector('#animation-focus').click();}`);
          await new Promise(r => setTimeout(r, 300));
          const rect = await evaluate(`{const r=document.querySelector('canvas').getBoundingClientRect();({left:r.left,top:r.top,width:r.width,height:r.height});}`);
          for (let orbit=0; orbit<4; orbit++) {
            for (let y=.3; y<.75; y+=.05) for (let x=.3; x<.75; x+=.05) {
              const point = {x:Math.round(rect.left+rect.width*x),y:Math.round(rect.top+rect.height*y)};
              await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent', {type:'mouseMoved',...point});
              if(await evaluate(`document.querySelector('canvas').dataset.hoveredObject===${JSON.stringify(String(object.id))}`))return {object,point};
            }
            // Keep scenery picking honest: orbit the camera to an unobstructed side.
            const x=rect.left+rect.width*.4,y=rect.top+rect.height*.35;
            await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mousePressed',button:'left',buttons:1,clickCount:1,x,y});
            await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mouseMoved',button:'left',buttons:1,x:x+rect.height*.25,y});
            await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent',{type:'mouseReleased',button:'left',buttons:0,clickCount:1,x:x+rect.height*.25,y});
            await new Promise(r=>setTimeout(r,300));
          }
          throw new Error('Cannot pick ' + tag);
        };
        let hit = await focusAndPick('creature', 'Angmar');
        console.log('Dialogue click target:', hit.object.id);
        await click(hit.point);
        await waitFor(`document.querySelector('#game-ui').dataset.conversationOwner==='${hit.object.id}'&&document.querySelector('#game-ui').dataset.conversationEntry==='0'&&document.querySelectorAll('.game-dialogue-reply:not(:disabled)').length===4`);
        const replies = await evaluate(`Array.from(document.querySelectorAll('.game-dialogue-reply'),b=>({ordinal:Number(b.dataset.replyOrdinal),text:b.textContent}))`);
        if(JSON.stringify(replies.map(r=>r.ordinal))!=='[2,4,6,8]')throw new Error('Authored intelligence conditions were not reflected in UI');
        await clickUi('[data-reply-ordinal="6"]');
        await waitFor(`document.querySelector('#game-ui').dataset.conversationEntry==='1'&&JSON.parse(document.querySelector('canvas').dataset.characterStats).xp===${startXP+15}`);
        await waitFor(`document.querySelector('canvas').dataset.audioError!==undefined || JSON.parse(document.querySelector('canvas').dataset.audio||'{}').played>=1`);
        const audio = await evaluate(`({state:JSON.parse(document.querySelector('canvas').dataset.audio||'{}'),error:document.querySelector('canvas').dataset.audioError})`);
        if(audio.error)throw new Error(audio.error);
        if(audio.state.context!=='running'||audio.state.last.resRef!=='gui_spell_mem')throw new Error('Reward sound was not decoded and played');
        report.audio=audio.state;
        const beforeMovement = await evaluate(`document.querySelector('canvas').dataset.actorPosition`);
        await window.webContents.debugger.sendCommand('Input.dispatchKeyEvent',{type:'keyDown',key:'w',code:'KeyW',windowsVirtualKeyCode:87});
        await new Promise(r=>setTimeout(r,300));
        await window.webContents.debugger.sendCommand('Input.dispatchKeyEvent',{type:'keyUp',key:'w',code:'KeyW',windowsVirtualKeyCode:87});
        if(await evaluate(`document.querySelector('canvas').dataset.actorPosition`)!==beforeMovement)throw new Error('Dialogue input leaked into movement');
        if(screenshot)await fs.writeFile(path.resolve(screenshot+'.angmar.png'),(await window.webContents.capturePage()).toPNG());
        await clickUi('.game-panel-footer button');
        await waitFor(`document.querySelector('.game-dialogue-text')===null`);
        hit = await focusAndPick('creature', 'Angmar'); await click(hit.point, 'right');
        await waitFor(`!document.querySelector('.radial-overlay').hidden`);
        await clickUi('.radial-entry[data-slot="7"]');
        await waitFor(`document.querySelector('#game-ui').dataset.conversationEntry==='0'&&document.querySelectorAll('.game-dialogue-reply:not(:disabled)').length===4`);
        for(const type of ['keyDown','keyUp'])await window.webContents.debugger.sendCommand('Input.dispatchKeyEvent',{type,key:'3',code:'Digit3',windowsVirtualKeyCode:51});
        await waitFor(`document.querySelector('#game-ui').dataset.conversationEntry==='1'`);
        if(await xp()!==startXP+15)throw new Error('Repeated conversation awarded XP twice');
        await clickUi('.game-panel-footer button'); await waitFor(`document.querySelector('.game-dialogue-text')===null`);
        console.log('Dialogue click and radial passed');
        await evaluate(`{const select=document.querySelector('#area-select');select.value='guildexhibitbrog';select.dispatchEvent(new Event('change'));}`);
        await waitFor(`document.querySelector('canvas').dataset.areaResRef==='guildexhibitbrog'&&document.querySelector('#status-text').textContent.includes('AREA RENDERED')`);
        hit = await focusAndPick('placeable', 'TearsMessage'); const questXP = await xp(); await click(hit.point);
        await waitFor(`document.querySelector('#game-ui').dataset.conversationOwner==='${hit.object.id}'&&document.querySelectorAll('.game-dialogue-reply:not(:disabled)').length===2`);
        await clickUi('[data-reply-ordinal="0"]');
        await waitFor(`document.querySelector('#game-ui').dataset.conversationEntry==='4'&&JSON.parse(document.querySelector('canvas').dataset.characterStats).xp===${questXP+50}`);
        await clickUi('.game-panel-footer button'); await waitFor(`document.querySelector('.game-dialogue-text')===null`);
        await evaluate(`{const select=document.querySelector('#ui-panel-select');select.value='journal';select.dispatchEvent(new Event('change'));}`);
        await waitFor(`document.querySelectorAll('.game-journal-entry').length>0`);
        const quest = await evaluate(`{const entry=Array.from(document.querySelectorAll('.game-journal-entry')).find(e=>e.textContent.includes('Tears'));if(!entry)throw new Error('Quest missing from journal');entry.open=true;entry.textContent;}`);
        if(quest.length<80)throw new Error('Quest text was not resolved');
        if(screenshot)await fs.writeFile(path.resolve(screenshot+'.journal.png'),(await window.webContents.capturePage()).toPNG());
        if(await evaluate(`document.querySelector('canvas').dataset.actorId`)!==actorId)throw new Error('Interaction changed actor ID');
        report.conversations = { actorId:Number(actorId), replies, clickAndRadial:true, keyboardReply:true, inputCaptured:true, angmarXP:15, repeatedXP:0, questXP:50, journalTextResolved:true };
        if(interactive){
          await clickUi('.game-panel-footer button');
          await evaluate(`{const select=document.querySelector('#area-select');select.value='brogansarm';select.dispatchEvent(new Event('change'));}`);
          await waitFor(`document.querySelector('canvas').dataset.areaResRef==='brogansarm'&&document.querySelector('#status-text').textContent.includes('AREA RENDERED')`);
          hit=await focusAndPick('creature','Angmar');await click(hit.point);
          await waitFor(`document.querySelector('#game-ui').dataset.conversationEntry==='0'&&document.querySelectorAll('.game-dialogue-reply:not(:disabled)').length===4`);
        }
        report.currentScene=await evaluate(`document.querySelector('canvas').dataset.areaResRef`);
      }
      if (play) {
        await evaluate(`{document.querySelector('.game-panel-footer button')?.click();document.querySelector('#release-test-cutscene').click();}`);
        await window.webContents.debugger.sendCommand('Input.dispatchKeyEvent', { type: 'keyDown', key: 'f', code: 'KeyF', windowsVirtualKeyCode: 70 });
        await window.webContents.debugger.sendCommand('Input.dispatchKeyEvent', { type: 'keyUp', key: 'f', code: 'KeyF', windowsVirtualKeyCode: 70 });
        await waitFor(`document.querySelector('#game-ui').dataset.cutscene==='false'`);
        await new Promise(resolve => setTimeout(resolve, 500));
        report.testing = await evaluate(`({cutscene:document.querySelector('#game-ui').dataset.cutscene, actorPosition:document.querySelector('#model-canvas').dataset.actorPosition})`);
      }
      if (focusCharacter) {
        await evaluate(`{document.querySelector('.game-panel-footer button')?.click();const select=document.querySelector('#animation-object');select.value=Array.from(select.options).find(o=>o.textContent.startsWith('Player · ')).value;select.dispatchEvent(new Event('change'));document.querySelector('#animation-focus').click();}`);
        const center = await evaluate(`{const r=document.querySelector('canvas').getBoundingClientRect();({x:r.left+r.width/2,y:r.top+r.height/2});}`);
        await window.webContents.debugger.sendCommand('Input.dispatchMouseEvent', { type: 'mouseWheel', ...center, deltaX: 0, deltaY: -900 });
        await new Promise(resolve => setTimeout(resolve, 600));
      }
      if (errors.length) throw new Error(errors.join('\n'));
      if (checkDiagnostics) {
        await evaluate('window.flushRuntimeDiagnostics()');
        const browserRecords = () => evaluate(`new Promise((resolve,reject)=>{ const open=indexedDB.open('nwn-runtime-diagnostics',1); open.onerror=()=>reject(open.error); open.onsuccess=()=>{const db=open.result;const request=db.transaction('records','readonly').objectStore('records').getAll();request.onsuccess=()=>{db.close();resolve(request.result)};request.onerror=()=>reject(request.error)}})`);
        const records = browserDiagnostics ? await browserRecords() : (await fs.readFile(diagnosticLog.path, 'utf8')).trim().split('\n').map(line => JSON.parse(line));
        const calls = records.filter(record => record.code === 'engine.unimplemented');
        if (checkProgression && !calls.some(record => record.context.engineCall === 'CopyObject' && record.context.script && Number.isInteger(record.context.objectId) && record.context.module)) throw new Error('Missing unsupported engine call context in persisted log');
        if (!records.some(record => record.code === 'load.area-completed') || !records.some(record => record.code === 'resource.lookup-failed')) throw new Error('Missing scene/resource records');
        const saving = await evaluate('({ count: Number(document.querySelector("#diagnostic-status").dataset.count), pending: Number(document.querySelector("#diagnostic-status").dataset.pending), error: document.querySelector("#diagnostic-status").dataset.storageError })');
        if (saving.error || saving.pending || saving.count !== records.length) throw new Error('Renderer journal differs from durable file: '+JSON.stringify(saving));
        report.diagnostics = { path: diagnosticLog.path, count: records.length, unimplementedCalls: calls.map(record => record.context.engineCall) };
        const exportPath = path.join(smokeData, 'exported-diagnostics.jsonl');
        const downloaded = new Promise((resolve, reject) => {
          const timer = setTimeout(() => reject(new Error('Diagnostic export timed out')), 10000);
          window.webContents.session.once('will-download', (_event, item) => {
            item.setSavePath(exportPath); item.once('done', (_event, state) => { clearTimeout(timer); state === 'completed' ? resolve() : reject(new Error('Diagnostic export '+state)); });
          });
        });
        await evaluate(`document.querySelector('#diagnostic-export').click()`); await downloaded;
        const exported = (await fs.readFile(exportPath, 'utf8')).trim().split('\n').map(JSON.parse);
        if (exported.length !== records.length) throw new Error('Export does not contain the full journal');
        report.diagnostics.exported = exported.length;
        if (browserDiagnostics) {
          window.webContents.reload(); await new Promise(resolve => window.webContents.once('did-finish-load', resolve));
          await waitFor(`document.querySelector('#diagnostic-status').dataset.path.startsWith('Browser database') && document.querySelector('#diagnostic-status').dataset.pending==='0'`);
          await evaluate('window.flushRuntimeDiagnostics()');
          const stored = await browserRecords();
          if (stored.filter(record => record.session === records[0].session).length !== records.length) throw new Error('Browser reload lost previous session records');
          report.diagnostics.path = 'Browser IndexedDB'; report.diagnostics.retainedAfterReload = stored.length;
          if (await evaluate('document.querySelector("#diagnostic-history-export").hidden')) throw new Error('Saved browser log export is unavailable');
        }
        await evaluate(`{document.querySelector('.runtime-diagnostics').open=true;if(document.body.classList.contains('game-mode'))document.querySelector('#game-mode-button').click();}`);
      }
      if (screenshot) {
        await evaluate('new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))');
        await fs.mkdir(path.dirname(path.resolve(screenshot)), { recursive: true });
        await fs.writeFile(path.resolve(screenshot), (await window.webContents.capturePage()).toPNG());
      }
      if (!interactive) {
        await waitFor(`!document.querySelector('#status-text').textContent.startsWith('READING AREA')`);
        await evaluate('window.flushRuntimeDiagnostics()');
        if (checkDiagnostics && !browserDiagnostics) {
          const finalRecords = (await fs.readFile(diagnosticLog.path, 'utf8')).trim().split('\n').map(JSON.parse);
          const saving = await evaluate('({ count: Number(document.querySelector("#diagnostic-status").dataset.count), pending: Number(document.querySelector("#diagnostic-status").dataset.pending), error: document.querySelector("#diagnostic-status").dataset.storageError })');
          if (saving.error || saving.pending || saving.count !== finalRecords.length) throw new Error('Final journal was not fully persisted: '+JSON.stringify(saving));
          report.diagnostics.finalPersisted = finalRecords.length;
        }
      }
      console.log(JSON.stringify(report));
      if (interactive) {
        window.webContents.debugger.detach();
        window.show();
        window.focus();
        console.log('INTERACTIVE VIEWER READY');
      } else { app.exit(0); }
    } catch (error) {
      console.error(error.stack);
      if (screenshot) await fs.writeFile(path.resolve(screenshot + '.failed.png'), (await window.webContents.capturePage()).toPNG());
      app.exit(1);
    }
  });
}
