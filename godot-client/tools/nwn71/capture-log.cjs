'use strict';
const knownSeparateWarning=[
 'WARNING: The separate rendering thread feature is experimental. Feel free to try it since it will eventually become a stable feature.',
 'However, bear in mind that at the moment it can lead to project crashes or instability.',
 'So, unless you want to test the engine, set the "rendering/driver/threads/thread_model" project setting to \'Safe\'.',
 '   at: Main::setup2 (main\\main.cpp:3522)'
].join('\n');
function classify(text){const normalized=text.replace(/\r\n/g,'\n');let remaining=normalized,count=0;while(remaining.includes(knownSeparateWarning)){remaining=remaining.replace(knownSeparateWarning,'');count++;}return{errors:/SCRIPT ERROR|ERROR:|FATAL:|crash|leaked|still in use/i.test(remaining),knownSeparateWarningCount:count,scope:'Only the exact4line standard separate-render-thread warning is ignored. Other crashes/errors/leaks remain failures.'};}
module.exports={knownSeparateWarning,classify};
