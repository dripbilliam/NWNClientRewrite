import {isolatedHeadless} from './isolated-headless.mjs';
await isolatedHeadless({
 label:process.argv[2],pattern:/^first-placement-[a-z0-9-]+$/,
 script:'native_perf140_loading_first_placement_test.gd',
 environment:{NWN_PARTICLE_KERNEL:'gd'},
 argumentsForVariant:variant=>['--expect-first='+(variant==='candidate'),'--particle-kernel=gd','--particle-owner=reference']
});
