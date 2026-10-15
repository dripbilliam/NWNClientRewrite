// ExecuteCommandSetCameraMode14053ea60 sends the integer's low byte only
// to GetClientObjectByObjectId. Packet family16/subtype2 carries that byte.
// Installed nwscript camera modes: chase0, top-down1, stiff-chase2.
export function requestCameraMode(objectId, mode, providers) {
  const client = providers.client(objectId);
  if (!client) return;
  const byte = mode & 255;
  // Unknown camera modes are ignored by the local receiving adapter.
  if (byte > 2) return;
  client.cameraMode = byte;
  providers.apply(client.object, byte);
}
