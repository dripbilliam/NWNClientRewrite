# NWN-80 bounded request/load audit

This is a source-only checkpoint, not a loading-order correction or a measured performance result.

`AssetService.request` (`systems/native_data/asset_service.gd:89-101`) records eligible prework demand, forks the catalog for worker ownership, and queues the request with a copied option set. The worker (`:126-177`) reads the selected resource once, computes a source digest, and uses that digest for preparation and decoded-cache identity. `decode` and `decode_uncached` (`:479-530`) accept the known digest, so the apparent second digest in those helpers is a fallback for other callers, not a duplicate on this path. `ResourceResidency.index` (`systems/native_data/resource_residency.gd:25-46`) hashes the actual input parts before consulting its cache; that protects same-size edits and archive-table changes and cannot be skipped solely from a name or timestamp.

The static-model worker path (`asset_service.gd:182-187`) can decode the same model a second time when the first static decode reveals an emitter. The second decode selects the actor route to retain original animation channels for that emitter. Replacing the two-stage decision needs a verified predecode emitter test or a decoder contract change and is not a safe one-file edit. Texture names are deduplicated inside the model loop (`:216-218`); no repeated raster read was proved in this bounded pass.

The native render-tree comparison (`tools/nwn75/world-build-client-comparison.md:7-12`) establishes that the original keeps shared Model/Part data and our client has separate asset and scene publication stages. It does not establish the full cold/warm/transition order required by NWN-80 or attribute a first-use stall to these requests.

**Decision:** no production edit from this slice. The next NWN-80 step is a source-pinned cold/warm/transition event trace that pairs each resource request/digest/decode and first publication with its area and generation. Only then can a specific redundant request or ordering mismatch be changed without risking resource precedence or readiness.
