// MdlNodeLightParseField14009db90: controller IDs are scoped by node type.
// In particular128 is verticaldisplacement on lights and alpha on meshes.
export const LIGHT_CHANNELS = {
  104: ['lightColor', 3], 116: ['lightRadius', 1],
  124: ['lightShadowRadius', 1], 128: ['lightVerticalDisplacement', 1],
  168: ['lightMultiplier', 1]
};
// Serialized32-bit controller offsets are relocated by ReadBinaryNode
//14007b909: light controllers>=76 gain28 in the64-bit runtime layout.
export const BINARY_LIGHT_CHANNELS = Object.fromEntries(Object.entries(LIGHT_CHANNELS).map(([type, channel]) => [Number(type) - 28, channel]));
export const LIGHT_PROPERTIES = {
  lightColor: 'color', lightRadius: 'radius', lightShadowRadius: 'shadowradius',
  lightVerticalDisplacement: 'verticaldisplacement', lightMultiplier: 'multiplier'
};
