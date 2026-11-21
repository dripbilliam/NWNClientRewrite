import {isolatedHeadless} from './isolated-headless.mjs';
await isolatedHeadless({label:process.argv[2],pattern:/^raster-selection-[a-z0-9-]+$/,script:'native_perf140_loading_raster_selection_test.gd',argumentsForVariant:variant=>['--expect-single-pass='+(variant==='candidate')]});
