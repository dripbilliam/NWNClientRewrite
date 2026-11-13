import {isolatedHeadless} from './isolated-headless.mjs';
await isolatedHeadless({label:process.argv[2],pattern:/^material-pose-[a-z0-9-]+$/,script:'native_perf140_loading_material_pose_test.gd',argumentsForVariant:variant=>['--expect-guard='+(variant==='candidate')]});
