# Lighting uniform cache investigation — disabled

2026-10-21. Performance goal remains active. All server connections in this
investigation use the private authored loopback5123 server; GPU fixtures block
HTTP. No Arelith connections.

The installed Three.js renderer uploads structured numeric lights when
switching programs, and shadow-matrix arrays on material changes. GL uniforms
belong to programs. `RendererLightUniforms` tests retaining numeric values
within a single supported main-camera pass while keeping all sampler setters
ordinary: samplers allocate and bind texture units on each material upload.
This is evidence from the current Three.js source, not a finding about the
original executable's rendering implementation.

The first candidate wrapped numeric-light flags plus matrices. Native v23
regressed to29.65/32.05/31.43FPS, p9537.8/36.1/35.3ms. Its profile attributes
about1.3 aggregate self CPU seconds per20-second sample to `prepare`, and the
accessor flags increased `markUniformsLightsNeedsUpdate` cost. The cache was
active, with roughly2000–4000 skipped uploads per sampled frame. Correct
activation alone was not a performance success.

The revised candidate caches only numeric shadow matrices and remembers
material texture schemas. It leaves the light-update flag stores ordinary.
Native v24 improves over v23 but still regresses versus the prior production
v22:33.13/35.47/37.06FPS, p9534.4/32.5/30.6ms, versus33.87/38.98/40.82FPS
and33.3/29.3/27.9ms. **Production explicitly constructs it `enabled:false`.**
The earlier main-draw palette batch prototype also stays disabled.

The final shadow-matrix prototype's offline WebGL oracle passes32 final
images and484 recorded shadow-atlas readbacks exactly, along with draw and
triangle counts. It exercises64 point lights/15 point shadows, directional,
spot and hemisphere lighting, a later directional-shadow substitution,
native installed `inc_target`/`inc_uniforms`, unlit particle material/sampler,
camera rotation/orthographic camera, changes of light count/layers/color,
material replacement, transparent draws, target uniforms and context loss.
Unknown draw/texture callbacks, override material and unsupported cameras use
the ordinary path. Uniform descriptors and material records retire on reset,
context loss, replacement and disposal; the native reports also end with zero
uniform material owners. No GPU resources are allocated by this owner.

The first fixture had an unbounded hidden-window rAF wait and was deliberately
cancelled after live-process checks showed it idle. This was a harness failure,
not a performance measurement. The corrected fixture uses task yields and
bounded context/deadline waits with a progress file. Final `light-uniforms-v1`
report/run-v4 and screenshot pass; the screenshot was inspected. The five
focused cache tests also cover program/pass separation, false flags, nested
rendering, exceptions and cleanup. Sampler descriptors are never changed.

Source maps for rejected full numeric v23 (`index-M1Sj0ors.js`) and revised
v24 (`index-edVDM1Wx.js`) are preserved as `light-uniforms-rejected-source-v1`
and `light-uniforms-matrices-source-v1`. Prior production v22 map is preserved
as `light-uniforms-baseline-source-v1`. CPU profiles require their matching map.
This work is rejection evidence, not an adopted FPS gain or goal completion.
