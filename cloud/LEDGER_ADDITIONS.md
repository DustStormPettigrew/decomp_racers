# Ledger additions from cloud sessions

Rows for D:\Code\LR1\REMAKE_LEDGER.md. Claude merges them in when reviewing.

| ID | Status | Action | Legacy behaviour | Old decomp | Ref |
|---|---|---|---|---|---|
| C1 | [ ] | INFO | D3D clipped-triangle batching flushes only on vertex capacity (`count + 14 >= 384`); the clipped index area (0xc50a0-0xc53a0) holds 384 indices, so a batch of clipped quads can write indices past it into the clipped vertex buffer before the flush triggers. Unclipped indices are not bounded either. | Draft also checked index capacity (invented guard). | `match/GolD3DRenderDevice-FUN_1000edf0-FUN_100106d0`, GD 0x10010187-0x10010199 |
| C2 | [ ] | INFO | Clipping only rebuilds the polygon's outside-flag union after the near plane. Vertices created by the far plane (and the side planes) are not added, so a far-clipped vertex that lands outside a side plane is not side-clipped unless an original vertex already was. Same in the D3D and software paths. | Draft OR'ed every new vertex into the union. | same branch, near OR at GD 0x1000f221 / 0x10010c04; far without OR at 0x1000f54e / 0x10010f7e |
| C3 | [ ] | INFO | Bottom-plane clip vertices: the D3D path leaves the new cache entry's y and clip flags unset; the software path sets cache y = z (not w) and stores flags 0. Only the projected vertex is used afterwards, so no visible effect. | Draft set y = w and rebuilt flags. | same branch, GD 0x1000ff61-0x1001008c / 0x10011c34-0x10011c40 |
| C4 | [ ] | INFO | The D3D path drops a polygon as soon as one plane leaves fewer than 3 vertices; the software path keeps clipping and checks `count >= 3` once at the end (signed). | Draft dropped early in both. | same branch, GD 0x1000f2db (D3D, each plane) / 0x10011cfb (software) |
| C5 | [ ] | MATCH | The software clipped path always calls the software renderer submit (0x100417c0 or 0x100417a0) and adds the count to m_unk0xc86f4, even when no triangle was emitted. | Draft returned early when nothing was emitted. | same branch, GD 0x10011e0d-0x10011e41 |
