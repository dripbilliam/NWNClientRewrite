import {ShaderChunk} from 'three';
// Keep sampler indexing constant in shadowed lights. The remaining lights use
// an ordinary GLSL loop instead of expanding up to128 copies of the lighting
// function into every material. Light order, inputs and shading math are kept.
export function compactPointLightLoops(source){
 const pattern=/#pragma unroll_loop_start\s+for \( int i = 0; i < NUM_POINT_LIGHTS; i \+\+ \) \{([\s\S]*?)\}\s+#pragma unroll_loop_end/;
 const match=source.match(pattern);if(!match)throw Error('Point lighting loop is incompatible with the renderer');
 const body=match[1],shadow=/#if defined\( USE_SHADOWMAP \) && \( UNROLLED_LOOP_INDEX < NUM_POINT_LIGHT_SHADOWS \)[\s\S]*?#endif/;
 if(!shadow.test(body))throw Error('Point shadow loop is incompatible with the renderer');
 const plain=body.replace(shadow,'').replaceAll('[ i ]','[ nwnPointIndex ]');
 return source.replace(pattern,`#if defined( USE_SHADOWMAP ) && NUM_POINT_LIGHT_SHADOWS > 0
 #pragma unroll_loop_start
 for ( int i = 0; i < NUM_POINT_LIGHT_SHADOWS; i ++ ) {${body}}
 #pragma unroll_loop_end
 #endif
 #ifdef USE_SHADOWMAP
 for ( int nwnPointIndex = NUM_POINT_LIGHT_SHADOWS; nwnPointIndex < NUM_POINT_LIGHTS; nwnPointIndex ++ ) {
 #else
 for ( int nwnPointIndex = 0; nwnPointIndex < NUM_POINT_LIGHTS; nwnPointIndex ++ ) {
 #endif
 ${plain}}
 `);
}
export function installCompactLightLoops(){if(!ShaderChunk.lights_fragment_begin.includes('nwnPointIndex'))ShaderChunk.lights_fragment_begin=compactPointLightLoops(ShaderChunk.lights_fragment_begin);}
