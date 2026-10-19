import * as THREE from 'three';
import { LIGHT_PROPERTIES } from './mdl_light.js';

const number = (properties, key, fallback) => {
  const value = Number(properties[key]);
  return properties[key] !== undefined && Number.isFinite(value) ? value : fallback;
};

// SetLightGL140080c10 supplies9/(2*r*r) to inc_lighting's LEGACY quadratic
// attenuation, not an intensity divisor. Gamma-corrected shader settings and
// native light selection/shadow passes remain separate renderer owners.
export function modelLightAttenuation(radius, distance) {
  return radius > 0 ? 1 / (1 + 9 / (2 * radius * radius) * distance * distance) : 0;
}

export function installModelLightShaders() {
  const point = 'light.color *= getDistanceAttenuation( lightDistance, pointLight.distance, pointLight.decay );';
  const direction = 'getPointLightInfo( pointLight, geometryPosition, directLight );';
  if (THREE.ShaderChunk.lights_pars_begin.includes('nwnQuadraticAttenuation')) return;
  if (!THREE.ShaderChunk.lights_pars_begin.includes(point) || !THREE.ShaderChunk.lights_fragment_begin.includes(direction)) throw new Error('Native model light shader adapter is incompatible with the renderer');
  THREE.ShaderChunk.lights_pars_begin = THREE.ShaderChunk.lights_pars_begin.replace(point,
    `float nwnQuadraticAttenuation = -pointLight.decay;
    light.color *= pointLight.decay < 0.0 ? 1.0 / (1.0 + nwnQuadraticAttenuation * lightDistance * lightDistance) : getDistanceAttenuation( lightDistance, pointLight.distance, pointLight.decay );`);
  // Native ambient-only lights still have position and attenuation. Bypass
  // Lambert's cosine for these local lights instead of adding global ambient.
  THREE.ShaderChunk.lights_fragment_begin = THREE.ShaderChunk.lights_fragment_begin.replace(direction,
    `${direction}\nif (pointLight.decay < 0.0 && pointLight.distance < 0.0) directLight.direction = geometryNormal;`);
}

export function updateModelLight(light) {
  const p = light.userData.mdlLight;
  const radius = Math.max(0, number(p, 'radius', 0)), multiplier = Math.max(0, number(p, 'multiplier', 1));
  light.color.setRGB(...p.color, THREE.SRGBColorSpace);
  // Three's diffuse BRDF divides byPI; the original legacy shader does not.
  light.intensity = radius > 0 ? multiplier * Math.PI : 0;
  light.distance = Number(p.ambientonly) > 0 ? -Math.max(radius, Number.EPSILON) : radius;
  light.decay = radius > 0 ? -9 / (2 * radius * radius) : -1;
}

export function createModelLight(node, configureShadow = null) {
  const p = node.properties ?? {}, color = Array.isArray(p.color) && p.color.length === 3 ? p.color.map(Number) : [1,1,1];
  const light = new THREE.PointLight();
  light.name = `${node.name} light`;
  light.userData.mdlLight = { ...p, color: [...color] };
  light.userData.mdlLightEnabled = true;
  light.castShadow = !(Number(p.ambientonly) > 0) && Number(p.shadow) > 0;
  light.userData.mdlLightShadowRequested=light.castShadow;
  if (light.castShadow) configureShadow?.(light);
  updateModelLight(light);
  return light;
}

export function applyModelLightChannel(light, channel, value) {
  const property = LIGHT_PROPERTIES[channel];
  if (!property || !light.userData.mdlLight) return false;
  light.userData.mdlLight[property] = value.length === 1 ? value[0] : [...value];
  return true;
}

// AurEnableShadowing/AurDisableShadowing ->SetShadows1400d3630 changes lights
// whose native node has affectdynamic or isdynamic set, recursively.
export function setModelLightShadows(root, enabled, configureShadow = null) {
  root.traverse(light => {
    const p = light.userData.mdlLight;
    if (p && (Number(p.affectdynamic) || Number(p.isdynamic))) {
      light.castShadow = !(Number(p.ambientonly) > 0) && Boolean(enabled);
      light.userData.mdlLightShadowRequested=light.castShadow;
      if (light.castShadow) configureShadow?.(light);
    }
  });
}

// Gob::SetLightPriority140094da0 collects the physical model's lights and
// writes INT+90. Retain priority independently of authored animated properties;
// the renderer's native light-selection policy remains a separate obligation.
export function setModelLightPriority(root,priority){
  root.traverse(light=>{if(light.isLight&&light.userData.mdlLight)light.userData.mdlLightPriority90=priority|0;});
}
