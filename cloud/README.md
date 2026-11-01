# Cloud session: LEGO Racers matching work

You are a Claude Code cloud session working for Dust (DustStormPettigrew) on the LEGO Racers decompilation (`isledecomp/racers`, fork `DustStormPettigrew/decomp_racers`). Codex is working on Dust's PC at the same time. You push branches. Dust opens PRs, and a separate Claude conversation reviews and groups your branches first. Work through the queue in §4 continuously. Commit and push the report after every branch, so progress survives if the session stops.

## 1. Setup (once per container, about 10 minutes)

The session needs this repo, with push access, plus the folder holding the original 1999 `LEGORacers.exe` and `GolDP.dll`. Dust supplies those, for example as a private repo attached to the session.

```bash
git fetch origin cloud-setup && git checkout cloud-setup          # this folder lives on this branch
git remote add upstream https://github.com/isledecomp/racers 2>/dev/null; git fetch upstream
ORIGINALS=/path/to/originals bash cloud/setup.sh                  # wine + MSVC 6.0 + CMake, full build, baseline scores
source ~/racers-env.sh                                            # in every new shell
git checkout --detach upstream/master && git worktree add ~/cloud-notes cloud-setup   # reports/ledger live here; work branches in the main checkout
```

`setup.sh` checks the originals' SHA-256 and writes `reccmp-user.yml` and the build config. It also saves baselines to `$RACERS_BUILD/baseline-LR.json` and `baseline-GD.json`. The build directory is `$RACERS_BUILD/build` (default `~/rbuild/build`). If upstream/master moves, rebuild on it and refresh the baselines before measuring.

Tools (copied to `~/racers-tools/`, because match branches do not contain `cloud/`):

| Tool | Use |
|---|---|
| `build.sh [legoracers\|goldp]` | Incremental double build of both targets, or one. Prints errors and warnings. About 10 s for one changed file. |
| `score.sh LEGORACERS\|GOLDP 0xADDR` | reccmp verbose diff of one function. |
| `score.sh compare LEGORACERS\|GOLDP <baseline.json>` | Every function whose score changed against a saved baseline. Must show only your targets going UP and nothing DOWN, in both targets. |
| `disasm.py LR\|GD 0xSTART 0xEND` | Disassemble the original binary, with float constants annotated. |
| `cicheck.sh` | CI-equivalent checks on the current branch: clang-format 22, decomplint for both modules, address padding, ncc, and a modern-compiler parse. |

## 2. Rules

- **CLAUDE.md is authoritative.** `cloud/HANDOFF.md` is the Codex handoff. Its §4b "Bag of tricks", §6 hard rules and §7 acceptance criteria apply to you too. Ignore its `D:\` paths and Windows build steps; `setup.sh` replaces them.
- **Branches:** one per file or class, one commit per function, created from a fresh `upstream/master`: `git checkout -b match/<Class>-<FuncA>-<FuncB> upstream/master`. Run `git ls-remote origin "refs/heads/match/<name>"` first; if the name exists, append `-Pass2` (or `-Pass3`). **Never force-push. Never open PRs.**
- **Commits:** author `Dust Storm <duststormpettigrew@live.com>`. Message title `Improve Class::Function`, or `Match ...` only for a verified raw 100%. End the message with the attribution trailer your session gives you.
- **Don't touch:**
  - the Do-not-touch list in HANDOFF.md §4;
  - `LEGORacers/src/audio/audiohelpers.cpp` and `LEGORacers/src/save/savegame.cpp`;
  - **Codex's Round 12 files:** golfont, cutscenevisual, powerupprojectile, menuframe, timeracemanager, carbuildscreenbase, racermodelscreenbase, gold3dtexture, golbmpfile, cutsceneparticle, multiplayerpickscreen, turboaction, grapplinghookaction, partanimationresource, ghosthazard, golworlddatabase, drivecontroller, racemodesetupscreen, golcamera, soundbuffer, menusceneview, menuscenescreen, optionsscreenbase, newracerscreen, golmodelentity, curseaction, magnetaction. The Round 11 files are covered by the unmerged-branch rule below;
  - any file an unmerged `origin/match/*` branch touches. Check with `git diff --name-only upstream/master...origin/match/X`.
- **Acceptance for each function kept:** its score goes up; `score.sh compare` shows zero regressions in both targets; `cicheck.sh` is clean; and a raw 100% claim shows no diff lines. If a function doesn't improve within about 10 trials, drop its commit and record the best attempt in the report.
- **Behaviour changes** (units, conditions, order of side effects, indices, sizes) and retained original quirks: verify each one in the disassembly with `disasm.py`. Then add a row to `cloud/LEDGER_ADDITIONS.md` with ID `C<n>`, MATCH/DECIDE/INFO, the legacy behaviour in plain terms, what the old decomp did, and the branch plus addresses. When you read a stack slot, count pushes. A misread slot once made the sky texture's V coordinate a constant 0 when the original computes ringAngle/π.
- **Known CI catches:**
  - high-bit enum `case` labels need `case static_cast<LegoU32>(c_x):`;
  - a float that becomes a `// GLOBAL:` must lose its `reccmp/lego-racers-floats.csv` row, and be declared as a plain file-scope `const`.

## 3. Work loop (per function)

1. Run `score.sh TARGET 0xADDR` and `disasm.py` over the whole range. Write down the original stack frame before editing.
2. Edit, run `build.sh legoracers` (or `goldp`; common/ code needs both), then `score.sh`. Keep the best version.
3. Run `score.sh compare` for both targets against the baselines, then `cicheck.sh`, then commit.
4. After the last function in the file, push the branch. Then, in `~/cloud-notes`, update `cloud/reports/CloudRound1.md` (branch, commit, function, before → after, trials, behaviour notes) and `cloud/LEDGER_ADDITIONS.md`, and commit and push `cloud-setup`.

## 4. Queue: Cloud Round 1 (scores at upstream 78b6819)

### Start here: the last two real stubs (largest remaining unmatched code)

`GolDP/src/render/gold3drenderdevice.cpp` has two `// STUB:` functions that already have full draft bodies (foxtacles, June). With their annotation temporarily set to `// FUNCTION:`, they score:

| Branch | Function | Address | Size | Draft score |
|---|---|---|---|---|
| `match/GolD3DRenderDevice-FUN_1000edf0-FUN_100106d0` | GolD3DRenderDevice::FUN_1000edf0, then FUN_100106d0 | GD 0x1000edf0 / 0x100106d0 | about 5.4 KB / 6 KB | 4.48% / 5.96% |

- Both are triangle-batch paths: `(firstTriangle, triangleCount, lastVertex)`. They are referenced only by absolute address (0x10007d32, 0x10012fbb/fc7, 0x10013039/5b), so they are function-pointer targets; there are no direct calls.
- GolD3DRenderDevice is on the Do-not-touch list because ChiefBoyardee was active there. **Exception for these two functions only:** nobody has pushed work on them; every branch on `github.com/ChiefBoyardee/racers` still has both as STUB, and that fork has been quiet since Oct 23. Change nothing else in the file.
- Method: map the whole original range with `disasm.py` first (stack frame, loops, the clip/emit structure), then rewrite against it. Work on one function at a time and keep its annotation `// STUB:` until it scores well. Measure by temporarily switching the annotation to `// FUNCTION:`; reccmp skips STUBs.
- Promote a function to `// FUNCTION:` in the commit only when it is a clear improvement with zero regressions. A partial is fine: report the score. This is long work, so budget most of the session for it, then continue with the table below.

`GolCameraBase::Dot2` (`// STUB: LEGORACERS 0x004044f0` in `golcamerabase.h`) is the third stub. Its only caller is `GolBoundingVolume::IntersectSegment` (call at 0x004042d4, queue #10 below), and our draft inlines it. Promote it only when that caller makes a real call to it (see CLAUDE.md, ICF section).

### Then: low scorers

Lowest scores and largest first. Group by file as shown.

| # | Branch | Function(s) | Address | Score |
|---|---|---|---|---|
| 1 | `match/RaceSession-BindCheckpointMaterials` | RaceSession::BindCheckpointMaterials | LR 0x00435e70 | 55.74% (Codex: 10 trials, no gain). The original keeps `this` in edx with a stack spill reloaded after each call, puts the checkpoint index in ebp, and computes `lea ecx,[this+0x27e0]` before the name-table null test. |
| 2 | `match/RaceDecalManager-Trail-Decal-EmitPolygon-Pass2` | RaceDecalManager::Trail::Decal::EmitPolygon | LR 0x00414f40 | 17.23%. Codex's held branch `match/RaceDecalManager-Trail-Decal-EmitPolygon` got 19.25% with unverified clipping claims; verify or redo them. |
| 3 | `match/DirectSoundManager-QueueSound-MakeSoundAvailable-Update` | DirectSoundManager::QueueSound, MakeSoundAvailable, Update | LR 0x004194b0 / 0x004190e0 / 0x00418940 | 29.61% / 44.96% / 33.28% |
| 4 | `match/RaceSkyState-ModelBuilder-BuildSphere-BuildSeamedSphere-Pass2` | BuildSphere, BuildSeamedSphere | LR 0x004907f0 / 0x004910e0 | 42.65% / 49.49% |
| 5 | `match/MenuManager-BuildPlayerDriverModel-PrepareRaceContext-Pass2` | MenuManager::BuildPlayerDriverModel, PrepareRaceContext | LR 0x0042dfa0 / 0x0042d730 | 38.42% / 64.20% |
| 6 | `match/GdbPartLibrary-FlushCopyBatch-Pass2` | GdbPartLibrary::FlushCopyBatch | LR 0x00407d60 | 38.66% |
| 7 | `match/TriggerWorld-IntersectSegment-Pass2` | TriggerWorld::IntersectSegment | LR 0x0041f4d0 | 39.81% |
| 8 | `match/GolRenderDevice-SelectTextureFormat-Pass2` | GolRenderDevice::SelectTextureFormat (common/, GOLDP annotation) | GD 0x10028c50 | 40.00% |
| 9 | `match/GolBoundingShape-CollectVisibleLeaves-CollectLeavesFromPvs-Pass2` | CollectVisibleLeaves, CollectLeavesFromPvs (common/) | GD 0x1001b2c0 / 0x1001b640 | 48.28% / 43.37% |
| 10 | `match/GolBoundingVolume-IntersectSegment-Pass2` | GolBoundingVolume::IntersectSegment (common/) | LR 0x00403fa0 | 46.48% |
| 11 | `match/AwardCinematicScreen-CreateWidgets-Pass2` | AwardCinematicScreen::CreateWidgets | LR 0x00475f40 | 51.56% (held: verify behaviour changes) |
| 12 | `match/GolImage-UploadTiles-Pass2` | GolImage::UploadTiles | GD 0x10005b00 | 52.00% |
| 13 | `match/CarShadowRenderState-DrawTriangles-Pass2` | DrawTriangles4Bpp, 16Bpp, 8Bpp | LR 0x00409b10 / 0x0040a3e0 / 0x00409f90 | 54.68% / 54.10% / 64.62% |
| 14 | `match/HomingProjectile-UpdateTargeting-Pass2` | HomingProjectile::UpdateTargeting | LR 0x00423640 | 57.48% |
| 15 | `match/LegoEventQueue-Descriptor-RigidBody-CalculateBoxContact-Pass2` | CalculateBoxContact (then TestBoxOverlap 87.81%) | LR 0x00441330 / 0x00441790 | 60.44% |
| 16 | `match/CmbModelPartTrackData-InterpolatePosition-InterpolateRotation-Pass2` | InterpolatePosition, InterpolateRotation (common/: both targets) | LR 0x0040e670 / 0x0040e830 | 60.76% / LR 70.75%, GD 63.12% |
| 17 | `match/RaceSession-LoadRaceContent-Pass2` | RaceSession::LoadRaceContent | LR 0x00433480 | 61.92% (same file as #1: put it on #1's branch if #1 isn't pushed yet) |
| 18 | `match/GolCameraBase-ComputeFrustum-ComputeFrustumFromBounds-Pass2` | both frustum builders (common/) | GD 0x1001bfc0 / 0x1001c450 | 62.63% / 62.62% |
| 19 | `match/RacePowerupManager-ReclaimExplosion-Pass2` | RacePowerupManager::ReclaimExplosion | LR 0x0045b3a0 | 63.77% |

If you finish the queue, re-rank the remaining functions under 80% with `score.sh LEGORACERS` / `score.sh GOLDP` and their JSON. Apply the same exclusions and continue as Cloud Round 2 in the same report.
