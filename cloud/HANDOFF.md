# Codex handoff — decomp_racers matching contributions

Repo: `D:\Code\LR1\decomp_racers` (fork `DustStormPettigrew/decomp_racers`, upstream `isledecomp/racers`).
Goal: small, reviewable PRs to upstream that raise reccmp accuracy. Byte/instruction matching against the 1999 retail binaries is the ONLY goal — no bug fixes, no modernization.

## 0. Rules source — read first

- `CLAUDE.md` in the repo root is the authoritative rulebook. Read it in full before any edit.
- `AGENTS.md` is a git symlink to `CLAUDE.md`; on this Windows checkout it is a 9-byte text file containing only `CLAUDE.md`. Do not treat that as the rules — open `CLAUDE.md`.
- `CONTRIBUTING.md` still says clang-format 18; CI now runs **clang-format 22** (`pipx run "clang-format>=22,<23"`). Use 22.

## 1. Sync the local checkout (GitHub fork synced to upstream f1530e6 on 2026-10-28; local D:\ checkout still at 063c273)

```
git remote -v                     # upstream should be git@github.com:isledecomp/racers.git
git fetch upstream
git checkout master
git merge --ff-only upstream/master
git push origin master
git checkout -b match/<ClassName>
```
Stop and report if `--ff-only` fails. Never commit to master.

## 2. Build (MSVC 6.0, cmd.exe — not PowerShell)

```
call D:\Code\LR1\MSVC600-8168\VC98\Bin\VCVARS32.BAT
cd D:\Code\LR1\decomp_racers\build
cmake .. -G "NMake Makefiles" -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build .
cmake --build .
```
The second `cmake --build` is required (NMake bug). Existing `build\` is already configured against this compiler.

## 3. reccmp setup + baseline

```
python -m venv D:\Code\LR1\.venv-reccmp
D:\Code\LR1\.venv-reccmp\Scripts\activate
pip install -r tools\requirements.txt
```
`reccmp-user.yml` (originals in `D:\Code\LR1\ORIGINALS\1999\Program_Files_Group\`) and `build\reccmp-build.yml` already exist. Run all reccmp commands from `build\`.

Baseline BEFORE any edit (after syncing + building clean master):
```
reccmp-reccmp --target LEGORACERS --json LR-before.json --html LR-before.html
reccmp-reccmp --target GOLDP      --json GD-before.json --html GD-before.html
```

## 4. Pick a target (re-rank first)

Using the fresh `*-before.json`, produce `targets.md`: per class, function count, average match %, and the list of sub-100% functions with address + %. Sort ascending by average. Exclude any class touched by an open upstream PR or merged in the last 14 days (`git log --since=14.days upstream/master --name-only`).

Work queue — do these IN ORDER, one branch + one report per class. Counts are from a July snapshot; verify against fresh data and skip any class already at 100%.

| # | Class | Source | July state | Why |
|---|---|---|---|---|
| 1 | HazardActionBase | `LEGORacers/src/race/powerups/hazardactionbase.cpp` | 4 funcs, 1 <100% | Smallest PR — proves the full loop (build → reccmp → diff → lint → report) |
| 2 | TriggerWorld | `LEGORacers/src/race/triggerworld.cpp` | 4 funcs, 1 <100%, ~84% avg | Small; TRB domain |
| 3 | HomingProjectile | `LEGORacers/src/race/powerups/homingprojectile.cpp` | 8 funcs, 2 <100% | |
| 4 | TetherProjectile | `LEGORacers/src/race/powerups/tetherprojectile.cpp` | 11 funcs, 3 <100% | Neighbours GrapplingHookAction — do after #3 |
| 5 | RaceSkyState | `LEGORacers/src/race/racesky.cpp` | 16 funcs, 3 <100% | Bigger class, few misses |
| Stretch | `GolTiledTexture::ComputeSquareTileLayout` | `GolDP/src/image/goltiledtexture.cpp` (GOLDP 0x1001f790, 1609 bytes) | Unimplemented `STUB:` | Only after 1–3 land cleanly. Promote STUB → FUNCTION only at a verified 100%; otherwise leave it STUB and report the best % reached |

Stop after #1 and write its report before starting #2, so Dust can sanity-check the loop.

Avoid the other remaining STUBs: `GolWorldDatabase::InitializeEntities`, and GolD3DRenderDevice 0x1000edf0 / 0x100106d0 (5–6 KB each, in another contributor's active area).

### Round 2 queue (added 2026-10-28, from build/targets.md at f1530e6)

Round 1 lessons: parser/loader functions responded best (RaceSkyState::Load 38.92% -> 100%); FPU/vector-math functions resisted (HazardActionBase::ComputeDropPosition stuck at 50.79%). One branch per function, cut from upstream/master. If two functions only improve together, keep them on one branch and explain why.

| # | Function(s) | Address | Score | Why |
|---|---|---|---|---|
| 1 | RacerTriggerList::Load | 0x00463dc0 | 43.01% | Parser loop, same shape as the RaceSkyState::Load win |
| 2 | RaceEventTable::ParseLapZones | 0x00461990 | 59.21% | Parser. Also check the class's near-misses (ParseSounds 98.33%, ParseParticles 96.65%, ParseExternalForces 97.37%) as separate quick-win branches |
| 3 | MenuDialog::DialogScreen::EnableWidgets + DisableWidgets | 0x004686f0 / 0x00468740 | 45.28% each | Twin functions; one fix likely fixes both (one branch is fine) |
| 4 | GameState::LoadFromSaveGame, SelectFallbackInputBinding | 0x0042eb60 / 0x0042ea50 | 68.50% / 64.58% | Save-load path |
| 5 | TargetPointList::DisableTargetPoints, FindTargetInCone | 0x0045c660 / 0x0045c6a0 | 60.00% / 85.31% | Small class |

All five source files are untouched upstream since July. Re-check before starting each one.

Do not touch any function that already has a match/* branch on origin (`git branch -r --list "origin/match/*"`).

### Round 3 queue (added 2026-10-29, scores from build/targets.md)

Same rules as round 2. Cut every branch from the current upstream/master, not cd5e6d0, if upstream has moved. UI/input handlers and loaders are favoured, because that's where rounds 1–2 got full matches. All files below are untouched upstream since July; re-check before each one.

| # | Function | Address | Score |
|---|---|---|---|
| 1 | MultiplayerPickScreen::HandleKeyDown | 0x00481c80 | 51.97% |
| 2 | MainMenuScreen::HandleKeyDown | 0x004812f0 | 66.67% |
| 3 | DriverLicenseScreen::HasUnsavedChanges | 0x0047b580 | 60.12% |
| 4 | MenuScreen::ApplySelectorDefaults | 0x0046bb90 | 59.15% |
| 5 | AwardCinematicScreen::CreateWidgets | 0x00475f40 | 51.56% |
| 6 | SaveLoadScreen::CreateWidgets | 0x00487060 | 70.42% |
| 7 | RaceSession::LoadRouteRecords, LoadRaceContent | 0x00433190 / 0x00433480 | 63.97% / 61.79% (separate branches) |
| 8 | RacerModelScreenBase::OpenRecordCursors | 0x00485c80 | 63.39% |
| 9 | SaveRecordList::Record::SetTrophy | 0x0042b640 | 75.51% |
| 10 | GolWorldDatabaseEx::LoadResources (GOLDP) | 0x10017ac0 | 63.84% |

Prefer existing helpers (e.g. GolVec3::DistanceSquaredTo, which won FindTargetInCone) over new ones.

### Round 4 queue (added 2026-10-29)

Part A covers parsers and loaders already at 90–99%; they're likely quick 100%s. Part B covers UI and logic functions further from a match. All files are untouched upstream since July. Same rules: cut from current upstream/master, one branch per function, trial cap, full checks, push, no PRs. Apply the round 3 rule: behaviour changes need disassembly evidence in the report.

**Part A: near-miss parsers and loaders**

| # | Function | Address | Score |
|---|---|---|---|
| A1 | RaceTimerList::Load | 0x00464aa0 | 99.16% |
| A2 | TriggerList::Load | 0x00464ff0 | 97.67% |
| A3 | CutsceneDefinition::Frame::Parse | 0x00405950 | 96.03% |
| A4 | CutsceneDefinition::Frame::ModelEvent::Parse | 0x00404a10 | 90.15% |
| A5 | LegoPieceLibrary::Load | 0x0049ee30 | 95.38% |
| A6 | GhostHazard::Load | 0x0048c960 | 94.19% |
| A7 | DirectSoundGroup::Load | 0x0041ae60 | 92.58% |
| A8 | GolFontLibrary::LoadFontDefinitions (GOLDP) | 0x1001d8f0 | 95.32% |

**Part B: UI and logic**

| # | Function | Address | Score |
|---|---|---|---|
| B1 | PowerupExplosion::OnEvent | 0x00421c00 | 76.56% |
| B2 | RacerModelSlot::Reset | 0x00487570 | 82.35% |
| B3 | MenuTextLabel::DrawSelf | 0x0046f6f0 | 63.16% |
| B4 | TimeRaceManager::Draw | 0x00422960 | 64.71% |
| B5 | RacerCollisionWorlds::ActivateWorld | 0x0045e520 | 40.37% |
| B6 | MenuFrame::SetRect | 0x0046ee40 | 29.63% |

**Stretch (common/ code, compiled into both targets):** GolMaterialLibrary::Load (GOLDP 0x10026270, 85.56%). Follow the CLAUDE.md "Shared Common Code Inlining" and "COMDAT Folding Across Targets" rules. A change here must show zero regressions in BOTH targets' diffs.

### Round 5 queue (added 2026-10-29)

**Lesson from rounds 1–4:** large gains come from structural problems in the existing decomp source, such as `this` aliases (`X* field = this;`), walking pointers, `goto`, wrong return types and hand-translated loops. Near-misses (>95%) whose only residue is register or scheduling noise mostly failed in round 4. This queue was picked by a "smell scan": a grep of every sub-97% function body for those patterns (Part A). Part B holds low-scoring logic functions (not FPU math). All files are untouched upstream since July, except the stretch item.

Same rules as round 4: cut from current upstream/master, one branch per function, ~6-trial cap, full per-branch checks, push, no PRs. Behaviour changes need disassembly evidence in the report.

**Part A: structural smells found in the current source**

| # | Function | Address | Score | Smell |
|---|---|---|---|---|
| A1 | RaceSession::InitializeInput | 0x004343e0 | 27.62% | `this` alias |
| A2 | RaceDecalManager::Trail::AddSample | 0x00491fa0 | 59.73% | `field->` alias |
| A3 | MenuManager::InitializeSaveSystem | 0x0042d0e0 | 84.08% | walking pointer |
| A4 | CarVisuals::DrawTransparent | 0x0043fc20 | 89.29% | `field->` alias |
| A5 | CarBuildScreen::HandleBuildKey | 0x00473ee0 | 89.56% | `goto` |
| A6 | RaceSetup::Update | 0x0043a480 | 95.27% | `goto` |
| A7 | GolDirectDrawPalette::Set332PaletteEntries (GOLDP) | 0x100077f0 | 94.05% | `[-1]` indexing, `+= sizeof` stepping |
| A8 | GolBoundingVolume::IntersectSegment (common/) | LR 0x00403fa0 | 45.10% | `goto`; shared code, zero regressions in both targets |

**Part B: low-scoring logic functions**

| # | Function | Address | Score |
|---|---|---|---|
| B1 | DirectSoundManager::MakeSoundAvailable | 0x004190e0 | 34.52% |
| B2 | DirectSoundManager::QueueSound | 0x004194b0 | 22.29% |
| B3 | MenuManager::PrepareRaceContext | 0x0042d730 | 60.87% |
| B4 | MenuManager::BuildPlayerDriverModel | 0x0042dfa0 | 37.37% |
| B5 | RacePowerupManager::ReclaimExplosion | 0x0045b3a0 | 60.43% |
| B6 | PartAnimationResource::Update | 0x004633f0 | 43.59% |
| B7 | GdbPartLibrary::FlushCopyBatch | 0x00407d60 | 38.66% |

**Stretch:** GolTgaFile::ReadHeader (common/: LR 0x004138b0 and GOLDP 0x1002a5e0, both 66.25%). It's compiled into both binaries, so one source fix can count twice. Last touched upstream by Gustlik501 on 2026-09-10 (#520); git fetch upstream and stop if it has changed since. Follow the CLAUDE.md shared-common-code rules.

**If the queue runs out:** run the smell scan yourself on the latest per-function scores (grep sub-97% bodies for `= this;`, `field->`, `goto`, `[-1]`, `+= sizeof`, pointer `++` walks, `undefined4*` returns). Pick untouched, unbranched functions and record them in a "Round 5b" note in the report.

### Stub task: GolWorldDatabase::InitializeEntities (added 2026-10-29)

Target: `// STUB: GOLDP 0x1002e640` in GolDP/src/world/golworlddatabase.cpp. It is 3024 bytes (reccmp/goldp-function-size.csv) and scores about 43% against the existing draft body. File untouched upstream since 2026-07-04.

Reference: GolTiledTexture::ComputeSquareTileLayout (branch `match/GolTiledTexture-ComputeSquareTileLayout`) went from a 6% STUB to byte-exact in two iterations with this method:

1. **Disassemble the whole original range first** (Capstone, 0x1002e640 to 0x1002f210), not the existing draft. Annotate each call target with names from the source annotations, and each vtable call with its slot.
2. **Map the stack frame before writing code.** List every `[esp+N]` home after the prologue pushes: which callee results, spilled `this`, arrays (`rep stosd` = memset of a local array) and reused slots. Look for mirrored blocks (the same code twice for two orientations or types). The original usually just repeats the code; existing inline helpers in the file (like ChooseTileSize) reproduce repeated inlined sequences.
3. **Write the plainest C++ that follows the control flow**, reusing inline helpers already in the file. Measure, then fix in this order:
   - (a) The frame. A spilled function-scope local that the original zero-initialises mid-function (`mov [esp+N], reg(0)`) must be a function-scope variable assigned 0 at that point.
   - (b) Signedness. `jl`/`jge` means a signed counter; `jb`/`jae` means unsigned. Different loops in the same function can differ, so use separate counters.
   - (c) Register and scheduling noise last.
4. reccmp skips STUB annotations. To measure, change the annotation to `// FUNCTION: GOLDP 0x1002e640` on the branch. Keep FUNCTION if the result beats the old 43%; title the commit "Match" only at a verified exact 100%.
5. Keep any original quirks (dead loops, out-of-range defaults) and mention them in the report. Do not "fix" them.

Branch: `match/GolWorldDatabase-InitializeEntities` from current upstream/master. Use the usual full per-branch checks, push, no PR. Report to D:\Code\LR1\codex_reports\match\GolWorldDatabase.md, including the stack-frame map and the trial table. Trial cap: 10 for this one, since it's larger. If it is below 80% after 10 trials, stop and report the remaining diff regions so Claude can take over.

### Round 6: rewrite pass (added 2026-10-30)

Treat each function below as if it were a STUB: follow the five-step method in the "Stub task" section (disassemble the whole original range, map the stack frame, write plain C++ following the control flow, then fix frame → signedness → scheduling). Use the existing source only as a hint for names and types. These are all under 40% and mostly integer or logic code, which is where full rewrites have paid off. Trial cap: 10 per function. If one is still under 60% after 10, stop on it and list its remaining diff regions in the report.

Do not touch `match/GolWorldDatabase-InitializeEntities`. Claude pushed a follow-up commit (6c48520) on it, so your local copy is one commit behind; `git fetch` before anything else.

| # | Function | Address | Score | Notes |
|---|---|---|---|---|
| 1 | GolBmpFile::LoadTiledTexture (common/) | LR 0x00402d70, GD 0x1001a340 | 22.30% both | Shared code: one fix counts in both targets. Zero regressions required in BOTH. |
| 2 | CarShadowRenderState::DrawTriangles4Bpp | 0x00409b10 | 30.61% | Siblings DrawTriangles8Bpp (62.04%) and DrawTriangles16Bpp (47.73%) probably share structure; apply what works to them as separate branches. |
| 3 | CircuitStandings::Draw | 0x00440350 | 25.24% | |
| 4 | GolBoundingShape::CollectVisibleLeaves (common/, GOLDP entry) | GD 0x1001b2c0 | 28.48% | Then CollectLeavesFromPvs (GD 0x1001b640, 32.56%) as a separate branch. |
| 5 | GolModel::DrawNode, then GolModel::Draw | GD 0x10006e00 / 0x10006c50 | 32.49% / 38.16% | Separate branches. |

Skip any function where git fetch shows new upstream commits touching its file since this note. Same per-branch checks, push each branch, no PRs. Report to codex_reports\match\<Class>.md with the frame map and trial table for each.

### Round 7: rewrite pass 2 (added 2026-10-30)

Same method and rules as Round 6 (stub-style rewrite, 10-trial cap, stop and report below 60%). Several of these are siblings of round-6 wins: reuse what worked there.

| # | Function | Address | Score | Notes |
|---|---|---|---|---|
| 1 | GolTgaFile::LoadTiledTexture (common/) | LR 0x00414120, GD 0x1002ae50 | 63.34% both | Sibling of the GolBmpFile::LoadTiledTexture rewrite (branch `match/GolBmpFile-LoadTiledTexture`): read it first. |
| 2 | GolBmpFile::ReadPixels (common/) | LR 0x00402a10, GD 0x10019fe0 | 54.70% both | Same file as the LoadTiledTexture branch: cut from upstream/master, not from that branch. |
| 3 | CheckpointGraph::ComputeLapFractions | 0x0041e950 | 38.25% | Lap progress logic. Remake-relevant: record any behaviour findings in REMAKE_LEDGER.md. |
| 4 | DirectMusicStream::Initialize | 0x0041a360 | 33.33% | |
| 5 | DirectMusicInstance::FillBuffer | 0x004197a0 | 33.78% | |
| 6 | CarVisuals::Update, then CarVisuals::UpdateCurseEntity | 0x0043e070 / 0x0043f530 | 42.87% / 45.99% | Separate branches. |
| 7 | CutscenePlayer::UpdateListener | 0x004a2f80 | 26.19% | |
| 8 | GdbPartLibrary::FlushCopyBatch | 0x00407d60 | 38.66% | Polish failed in round 5; try the rewrite method. |
| 9 | GolImage::DrawStretched, then GolImage::UploadTiles | GD 0x10005510 / 0x10005b00 | 45.96% / 50.43% | Separate branches. |

Do not touch any function with an existing `origin/match/*` branch, and do not edit DirectSoundManager (two combined branches are queued as PRs).

### Round 8: rewrite pass 3, gameplay first (added 2026-10-30)

Same method, rules and ledger requirement as Round 7. This round leans toward gameplay and physics code, because those findings matter most for the remake. Put every behaviour difference from the old decomp into REMAKE_LEDGER.md with addresses. Trial cap 10; stop and report below 60%.

| # | Function | Address | Score | Notes |
|---|---|---|---|---|
| 1 | LegoEventQueue::Descriptor::RigidBody::CalculateBoxContact | 0x00441330 | 35.86% | Collision physics (legoeventqueuerigidbody.cpp). Then TestBoxOverlap 0x00441790 (82.38%) as a separate branch. |
| 2 | PlayerControls::UpdateSteering | 0x00430120 | 68.78% | Player steering input. Ledger anything that changes feel: rates, clamps, dead zones. |
| 3 | PowerupProjectile::LaunchAtRacer, then Deflect | 0x00430d80 / 0x00431310 | 52.86% / 63.54% | Separate branches. |
| 4 | HomingMissileAction::Update | 0x004568f0 | 65.16% | |
| 5 | RollingRockHazard::Update | 0x0048be70 | 67.94% | |
| 6 | PartAnimationResource::Update | 0x004633f0 | 43.59% | Round-5 polish failed; use the rewrite method. |
| 7 | CutsceneAnimation::SpawnParticle | 0x00489d70 | 42.91% | |
| 8 | RaceDecalManager::Trail::Initialize, then AddSample | 0x00491c70 / 0x00491fa0 | 49.15% / 59.73% | Separate branches. |
| 9 | CmbModelPartTrackData::InterpolatePosition (common/) | LR 0x0040e670, GD 0x10024380 | 38.82% both | Animation keyframes; zero regressions required in BOTH targets. Then InterpolateRotation (GD 35.05% / LR 69.66%). |
| 10 | RaceSkyState::ModelBuilder::BuildSphere, then BuildSeamedSphere | 0x004907f0 / 0x004910e0 | 15.10% / 19.09% | Stretch: generated geometry, FPU-heavy. |

All files are untouched upstream since July, except racesky.cpp, which has only our merged #551. Skip any function that already has an origin/match/* branch.

**Round 8 checkpoint (2026-10-30):** main queue complete: 13 functions, 13 pushed branches, full checks and zero regressions. Base `d02f5b5`. See `codex_reports/match/Round8.md` and per-class reports for scores, commits, frame maps and trials. Deflect is raw100%. Ledger adds24 unchecked rows; all47 pre-existing rows/Status cells verified unchanged. Stopped at budget before the ModelBuilder stretch: next is BuildSphere0x004907f0, then BuildSeamedSphere0x004910e0. Neither was edited or branched. Fetch and refresh baseline on resume if upstream moves.

### Round 9: rewrite pass 4, engine/visuals/audio (added 2026-10-30)

Same method, rules, trial cap (10) and ledger requirement as Rounds 7–8. Start from a fresh `upstream/master` (a7ddc5f or later; #569–#583 have merged since Round 8's base) and refresh both baselines first. Leave the Round 8 branches alone; they are queued for PRs. Claude pushed one follow-up commit (4b2df21) to `match/HomingMissileAction-Update`, so `git fetch` before anything else.

Most gameplay files are being worked on upstream right now (see the Do-not-touch list, which now includes RacerPhysics, RaceTrailManager, DriverModelBuilder and GolAnimatedEntity), so this round covers rendering, audio and menu code. Ledger any behaviour change as usual (sizes, counts, thresholds, formats, priorities).

| # | Function | Address | Score | Notes |
|---|---|---|---|---|
| 1 | RaceSkyState::ModelBuilder::BuildSphere, then BuildSeamedSphere | 0x004907f0 / 0x004910e0 | 15.10% / 19.09% | Round 8 stretch carried over. Separate branches (same file: racesky.cpp). Generated sky geometry, FPU-heavy: map the stack frame first. |
| 2 | RaceDecalManager::Trail::Decal::EmitPolygon | 0x00414f40 | 17.23% | racedecaltrail.cpp (not racedecalmanager.cpp, which has queued R8 branches). Skid-mark geometry. ~2.2 KB: rewrite method. |
| 3 | DirectSoundManager::Update | 0x00418940 | 17.05% | Per-frame voice management; our MakeSoundAvailable/QueueSound changes merged in #581, build on them (the Round 7 "do not edit DirectSoundManager" note no longer applies). Ledger anything about voice priority, stealing, distance or volume. |
| 4 | GolCameraBase::ComputeFrustum, then ComputeFrustumFromBounds | GD 0x1001bfc0 / GD 0x1001c450 | 26.15% / 22.14% | common/src/golcamerabase.cpp (GOLDP annotations only, but compiled into both targets: zero regressions in BOTH). Mind the in-class Dot2 note in CLAUDE.md (ICF section). Separate branches. |
| 5 | GolRenderDevice::SelectTextureFormat | GD 0x10028c50 | 38.81% | common/src/golrenderdevice.cpp. Not the GolD3DRenderDevice one at 0x1000a110 (do-not-touch class). Ledger the format preference order. |
| 6 | ParticleSystem::Draw | 0x00412a50 | 50.60% | |
| 7 | GolWorldEntityGroup::UpdateBounds | 0x00411ef0 | 52.76% | common/: zero regressions in both targets. |
| 8 | RaceDialog::Draw | 0x00427440 | 50.76% | |
| 9 | GolFont::CreateSurfaces | GD 0x100047b0 | 59.10% | |
| 10 | CarBuildScreenBase::Draw | 0x00475010 | 65.56% | Stretch. |

Two review catches from Round 8 to apply from the start (both are in §4b): cast high-bit enum `case` labels with `static_cast<LegoU32>(...)`, and delete the `lego-racers-floats.csv` row for any float you turn into a `// GLOBAL:` (plain file-scope `const`, not `extern const`). Skip any function that already has an origin/match/* branch. Report in `codex_reports/match/Round9.md` plus per-class reports, as before. No PRs.

**Round 9 checkpoint (2026-10-30):** queue complete, including CarBuildScreenBase::Draw stretch: 12 pushed branches, 90 matching trials, full per-branch checks, current-MSVC compiles, strict whole-object scope audits and zero regressions. Base `a7ddc5f`; all branches cut independently from it. RaceDialog::Draw is raw100% (Match); ParticleSystem::Draw98.80% and UpdateBounds99.22% remain Improve. Ledger adds33 unchecked rows; all71 pre-existing full rows/Status cells verified unchanged. Reports: `codex_reports/match/Round9.md` plus per-class maps/trials/remaining regions. No PRs; clean final checkout `match/CarBuildScreenBase-Draw`. No pending Round 9 item. Fetch/rebaseline before any next round.

### Round 10: low scorers (added 2026-10-31)

Same method, rules, trial cap (10 per function) and ledger requirement as Rounds 7–9. Fetch first and start from a fresh `upstream/master`; refresh both baselines. **Grouping applies from this round (see "Branch grouping" below): one branch per class or file, one commit per function inside it.**

Skip any file that a queued branch already touches. Those files are: racedecalmanager, racedecaltrail, cmbmodelparttrackdata, playercontrols, legoeventqueuerigidbody, homingmissileaction, homingprojectile, driverlicensescreen, powerupprojectile, raceeventtable, timeracemanager, racepowerupmanager, triggerworld, menumanager, racermodelscreenbase, menuframe, gamestate, carshadowrenderstate, golboundingshape, golboundingvolume, goltgafile, golimage, racesky, golcamerabase, golrenderdevice, racedialog, particlesystem, golworldentitygroup, golfont, carbuildscreenbase, directsoundmanager. Also skip audiohelpers.cpp and savegame.cpp (ChiefBoyardee, Oct 23) and everything on the Do-not-touch list.

| # | Branch | Function(s) | Address | Score |
|---|---|---|---|---|
| 1 | `match/CutsceneVisual-ComputeLayout-Update` | CutsceneVisual::ComputeLayout, then Update | 0x004a36e0 / 0x004a3550 | 56.50% / 63.64% |
| 2 | `match/MenuTextField-DrawSelf` | MenuTextField::DrawSelf | 0x00471300 | 56.21% |
| 3 | `match/MenuTextLabel-DrawSelf` | MenuTextLabel::DrawSelf | 0x0046f6f0 | 63.16% |
| 4 | `match/RaceSession-BindCheckpointMaterials-TakeScreenshot` | RaceSession::BindCheckpointMaterials, then TakeScreenshot | 0x00435e70 / 0x00435f20 | 55.74% / 87.14% |
| 5 | `match/TargetPointList-DisableTargetPoints` | TargetPointList::DisableTargetPoints | 0x0045c660 | 60.00% (64 bytes) |
| 6 | `match/TurboAction-AnchorToRacer` | TurboAction::AnchorToRacer | 0x0045cf90 | 62.02% |
| 7 | `match/GolD3DTexture-CreateMipmapBuffers` | GolD3DTexture::CreateMipmapBuffers | GD 0x100168c0 | 66.25% |
| 8 | `match/MenuModelCarousel-SetupCamera` | MenuModelCarousel::SetupCamera | 0x0046cc10 | 68.09% |
| 9 | `match/MainMenuScreen-HandleKeyDown` | MainMenuScreen::HandleKeyDown | 0x004812f0 | 66.67% (32 bytes: check for a fold/inline/thunk cause before rewriting) |
| 10 | `match/MultiplayerPickScreen-HandleKeyDown` | MultiplayerPickScreen::HandleKeyDown (second pass after #567) | 0x00481c80 | 69.52% |
| 11 | `match/GrapplingHookAction-AdvanceState-Update` | GrapplingHookAction::AdvanceState, then Update | 0x00454360 / 0x00453ef0 | 73.02% / 87.65% |
| 12 | `match/SaveLoadScreen-CreateWidgets` | SaveLoadScreen::CreateWidgets | 0x00487060 | 70.42% |

Stretch (second passes on our merged work, one branch per file):

| # | Branch | Function(s) | Address | Score |
|---|---|---|---|---|
| 13 | `match/TetherProjectile-UpdateReleased-RebuildBeam-UpdateAttached` | TetherProjectile::UpdateReleased, RebuildBeam, UpdateAttached | 0x00444690 / 0x00444540 / 0x00444820 | 77.98% / 78.65% / 81.32% |
| 14 | `match/GolBmpFile-LoadTiledTexture-ReadPixels-ReadHeader` | GolBmpFile::LoadTiledTexture, ReadPixels, ReadHeader (common/: zero regressions in BOTH targets) | LR 0x00402d70 / 0x00402a10 / 0x004017d0 | 68.64% / 78.09% / 86.34% |
| 15 | `match/CutsceneParticle-Update-SetOrientation` | CutsceneParticle::Update, SetOrientation | 0x004897e0 / 0x00489540 | 82.69% / 89.74% |

Within a grouped branch, keep any function that does not improve out of the branch (drop its commit) and say so in the report. Report in `codex_reports/match/Round10.md` plus per-class reports. No PRs.

### Round 11: second passes and mid scorers (added 2026-10-31)

Same method, rules, trial cap (10 per function), grouping (one branch per file, one commit per function) and ledger requirement as Round 10. Fetch first and start from a fresh `upstream/master`, then refresh both baselines. Several of these files had our PRs merged after the Round 10 base, so **use the fresh baseline scores, not the ones below**, as "before".

The queue below was pre-filtered against every unmerged `origin/match/*` branch. If a new branch appears that touches one of these files before you reach it, skip that file. The Do-not-touch list, audiohelpers.cpp and savegame.cpp still apply.

| # | Branch | Function(s) | Address | Score at R10 base |
|---|---|---|---|---|
| 1 | `match/CarVisuals-Update-UpdateCurseEntity-UpdateSkidMarks-DrawTransparent` | CarVisuals::Update, UpdateCurseEntity, UpdateSkidMarks, DrawTransparent | 0x0043e070 / 0x0043f530 / 0x0043f1e0 / 0x0043fc20 | 68.78% / 72.46% / 84.63% / 89.29% |
| 2 | `match/DirectMusicInstance-FillBuffer-SetPath` | DirectMusicInstance::FillBuffer, SetPath | 0x004197a0 / 0x0041a060 | 60.84% / 93.2% |
| 3 | `match/GolStream-BufferedRead-BuildPathname` | GolStream::BufferedRead, BuildPathname (common/: zero regressions in BOTH targets) | LR 0x0044cd00 (GD 0x10031800) / LR 0x0044d190 | 81.47% / 90.7% |
| 4 | `match/CircuitStandings-Draw-Pass2` | CircuitStandings::Draw (second pass after #571) | 0x00440350 | 74.79% |
| 5 | `match/HomingMissileAction-Update-Pass2` | HomingMissileAction::Update (second pass after #594) | 0x004568f0 | ~75% |
| 6 | `match/PlayerControls-UpdateSteering-Pass2` | PlayerControls::UpdateSteering (second pass after #592) | 0x00430120 | ~82% |
| 7 | `match/GolOrientedEntity-TransformMatrixToLocal-SetDirectionSide-SetDirectionUp` | GolOrientedEntity::TransformMatrixToLocal, SetDirectionSide, SetDirectionUp (common/) | 0x00410f30 / 0x00410a00 / 0x00410900 | 81.08% / 91.7% / 93.1% |
| 8 | `match/DriverLicenseScreen-HasUnsavedChanges-Pass2` | DriverLicenseScreen::HasUnsavedChanges (second pass after #595) | 0x0047b580 | ~83% |
| 9 | `match/SpatialSoundInstance-UpdateSpatialFromNode` | SpatialSoundInstance::UpdateSpatialFromNode | 0x00417de0 | 78.34% |
| 10 | `match/PowerupExplosion-OnEvent` | PowerupExplosion::OnEvent | 0x00421c00 | 76.56% |
| 11 | `match/ColorBrick-Update` | ColorBrick::Update | 0x00457710 | 78.48% |
| 12 | `match/LightningAction-UpdateBoltPath-OnHitRacer` | LightningAction::UpdateBoltPath, OnHitRacer | 0x00455100 / 0x00455440 | 90.3% / 92.9% |
| 13 | `match/CarBuildScreen-HandleBuildKey` | CarBuildScreen::HandleBuildKey | 0x00473ee0 | 89.56% (1.1 KB) |

Stretch (same rules):

| # | Branch | Function(s) | Address | Score at R10 base |
|---|---|---|---|---|
| 14 | `match/RacerCollisionWorlds-ActivateWorld-Pass2` | RacerCollisionWorlds::ActivateWorld (second pass after #568) | 0x0045e520 | 75.47% |
| 15 | `match/SaveRecordList-Record-SetTrophy` | SaveRecordList::Record::SetTrophy | 0x0042b640 | 75.51% |
| 16 | `match/DirectMusicGroup-CreateMusicInstance` | DirectMusicGroup::CreateMusicInstance | 0x0041a8a0 | 85.86% |
| 17 | `match/MenuInputDispatcher-InitializeCursor-ProcessInputEvents` | MenuInputDispatcher::InitializeCursor, ProcessInputEvents | 0x00468fa0 / 0x004692b0 | 87.27% / 92.4% |
| 18 | `match/RaceInputRouter-OnKeyDown-OnKeyUp` | RaceInputRouter::OnKeyDown, OnKeyUp | 0x00427a00 / 0x00427aa0 | 89.04% / 89.04% |
| 19 | `match/GolTransform-InverseTransformPoint` | GolTransform::InverseTransformPoint | GD 0x10002d00 | 81.82% |

For second passes (4, 5, 6, 8, 14), use the `-Pass2` branch names given (the old names still exist on origin; never force-push), keep every behaviour fix already merged, ledger only new findings. Report in `codex_reports/match/Round11.md` plus per-class reports. No PRs.

**Branch grouping (from Round 10):** upstream accepts multi-function PRs (e.g. #541, #548), so from Round 10 put related functions from the same class or file on ONE branch (name it `match/<Class>-<FuncA>-<FuncB>`, max ~5 functions). Keep one commit per function inside the branch so each can be measured and reverted alone, and still report every function's before/after separately. Round 9 keeps one branch per function as written.

### Remake ledger (applies to every round from now on)

`D:\Code\LR1\REMAKE_LEDGER.md` tracks retail behaviour that the remake (wackynack_LR1, GolModern) must match or deliberately deviate from. When a branch:
- changes behaviour relative to the old decomp source (arguments, units, conditions, indices, sizes, call order with side effects), or
- keeps an original bug or quirk (out-of-bounds reads/writes, dead loops, odd tie-breaks),

then append a row to the right section of the ledger with: next ID, `[ ]`, MATCH/DECIDE/INFO, the legacy behaviour in plain terms (gameplay units where possible), what the old decomp did, and the branch name plus the disassembly addresses. Never edit the Status column; Dust owns it. Add a line to the ledger changelog for each round.

**Do not touch** (heavy recent upstream activity — collision risk): GolD3DRenderDevice, GolMath, GolModelRenderState, GolSoftwareRenderer, RaceState, RaceCameraController, BeamMesh, GolFontBase, GolImgFile, GolSurface, RaceHud, Racer/RacerCarBody, CarBuildModel, MenuIcon/MenuWidget, RacerPhysics, RaceTrailManager, DriverModelBuilder, GolAnimatedEntity (others merged work there on 2026-10-23).

## 4b. Bag of tricks: proven in rounds 1–2 (try these first)

Each technique below is listed with the function where it produced a gain. Add new entries after every round, and record dead ends too.

| Technique | Where it worked |
|---|---|
| Drop a `this` alias (`RaceEventTable* field = this;`) and use members directly | ParseSounds → 100%, ParseLapZones → 100% |
| Drop a reused member-pointer local (`MenuIcon* icon = m_x; ... icon = m_y;`) and test/use the members directly | EnableWidgets / DisableWidgets 45% → 100%, HomingProjectile::UpdateTargeting |
| Replace a walking pointer or raw offsets (`p[-1]`, `p + 3`, `p += sizeof(T)`) with plain indexed member access (`m_arr[i].m_field`) | GameState::LoadFromSaveGame 68% → 99.2%, RaceSkyState::Load → 100% |
| Replace a hand-unrolled sub/dec comparison chain with the `switch` the compiler lowered | ParseLapZones 59% → 100% |
| Use one `memset(..., 0xff, sizeof)` for runs of `= -1` stores | ParseLapZones |
| Hoist a local struct/buffer out of a loop, or reuse one buffer (e.g. a single `GolName`) when the original reuses one stack slot | ParseLapZones (InitParams), RaceSkyState::Load (GolName) |
| Reuse an existing helper (`GolVec3::DistanceSquaredTo`, golmath.h macros) before writing one | FindTargetInCone 85% → 100% |
| A file-local inline helper with `const T&` inputs and a `T* p_dest` output, when the inline form fails (precedent: magnetaction.cpp CrossVectors) | HomingProjectile::Update |
| Split float expressions into temporaries in the original x87 order (`v = a; v *= b; v += c;`) | Tether* +26 to +43pp |
| A named index local for the final array access after a long loop body | ParseSounds |
| Check every call's argument order and units against the disassembly. Sub-50% functions can hide real decomp bugs | TetherProjectile: ms vs s, swapped MoveToward args, delta vs step passed to Begin |

| Round 3: re-read through the accessor in each case instead of caching it in a local before a switch | MultiplayerPickScreen::HandleKeyDown 52% → 70% |
| Round 3: declare the loop counter at function scope when the original reuses its leftover value after the loop | MenuScreen::ApplySelectorDefaults → 100% (the original checks `m_images[i]` with i == 6, eight times: a real bug in the original code) |
| Round 3: change the return type to `void` when the epilogue has no `mov eax`, including base-class pure virtuals, after checking no caller uses the result | GolWorldDatabaseEx::LoadResources 64% → 98.9% |
| Round 3: pass a call result straight as an argument instead of through a local | RaceSession::LoadRaceContent, RacerModelScreenBase::OpenRecordCursors |

**Rule added after round 3:** a trial that changes behaviour (moves calls between branches, changes conditions or indices) needs disassembly evidence in the report. Without it, a score gain under ~5pp isn't worth keeping (see AwardCinematicScreen::CreateWidgets: +1.4pp from moving three cleanup calls and changing a condition).

<!-- Round 4 matching findings -->

Round 4 findings:

| Technique or dead end | Evidence |
|---|---|
| Order zero initializers by their retail homes: place a stack initializer before the register locals when its store precedes their xor instructions; declaration order affects both zero sharing and scheduling. | RaceTimerList::Load 99.16% -> 100%; initialDelay, onDuration, flags, offDuration reproduces 0x00464c4e-0x00464c58. |
| Dead end: parameter-buffer hoisting, Clear, a named final index, chained integer defaults, and an inline initializer did not move an early parser-vtable load to its retail position; putting an integer zero first also changed float stores to register stores. | TriggerList::Load: six trials, no retained gain from 97.67%; integer-first variant fell to 93.02%. All reverted. |
| Dead end: named indices, derived/base pointer locals, separate loop-counter scope, and an inline lookup did not fix final-loop address-generation scheduling; moving both counter increments into the for clause regressed. | CutsceneDefinition::Frame::Parse: six trials, no gain from 96.03%; for-clause increment variant 94.72%. Reverted. |
| A false integer return can extend a parser local across the whole function and force an early callee-saved-register push; void restores its stack home and late push after caller audit. | CutsceneDefinition::Frame::ModelEvent::Parse 90.15% -> 100%; epilogue 0x00404c43-0x00404c53, sole caller overwrites EAX at 0x00405dba. |
| Dead end: shared parser indices, hoisted UV locals, pointer-to-reference substitution, and commuted integer sums did not change scratch-register allocation; removing a record alias and reversing variant initializers regressed. | LegoPieceLibrary::Load: six trials, baseline/best 95.38%; direct indexing 94.37%, reversed initializers 95.18%. All reverted. |
| Dead end: signed count, reciprocal splitting, and naming an intermediate pointer were identical; removing the data local, moving its declaration, and direct conversion worsened the scratch-register mismatch. | GhostHazard::Load: six trials, baseline/best 94.19%; three alternatives 93.02%. Retail animation-data chain and frame-count zero use EAX/EDX, rebuilt EDX/ECX. Reverted. |
| Combine indexed buffer access with explicit resets in both for clauses; the resets can also restore a shared zero register used by earlier allocation/null checks. | DirectSoundGroup::Load 92.58% -> 97.19% from indexing alone -> 100% with both explicit loop initializers. Moving index before the file constructor regressed to 96.68%. |
| Dead end: separate flag operations and an inline helper still fold redundant mask bits; full-width locals, style-buffer hoisting and a named index were identical, and swapping flag/color stores regressed. | GolFontLibrary::LoadFontDefinitions: six trials, baseline/best 95.32%; swapped stores 92.91%. All reverted; GolFontBase untouched. |
| Dead end: existing vector operators and output-pointer helpers still fold retail zero-component additions; an extra vector grows the stack, while direct member Clear loses partial-copy scheduling. | PowerupExplosion::OnEvent: six regressions from 76.56%, 60.00%-71.70%. Reverted, reinforcing the HazardActionBase zero-vector/FPU limitation. |
| Dead end: replacing a three-dword memset with an unrolled indexed loop, clear/set helpers, explicit retail-order stores or a chain did not recover a saved zero register and cross-member scheduling. | RacerModelSlot::Reset: six trials, 82.35% baseline, 80% loop and 76% alternatives. Reverted without changing unknown types. |
| Dead end: separate countdown, paired rectangle updates, hoisted buffers and source-store reordering did not change a mismatched float/counter stack layout; early edge initialization strongly regressed. | MenuTextLabel::DrawSelf: six trials, baseline/best 63.16%; split division 62.43%, early lineTop 38.10%. Reverted. |
| Separate interpolation input vectors from the output, and reuse that output for later transformed positions; represent the next sample as a vector rather than scalar locals to recover stack homes and x87 scheduling. | TimeRaceManager::Draw 64.71% -> 65.63% with separate input/reused output -> 76.92% with next-position vector. Direct indexing alone regressed to 50.15%; all retained arithmetic audited at 0x00422b12-0x00422bd4. |
| Use indexed searches with the exact retail condition order and found-return loop shape; a hand-translated walking-pointer loop can compile to a different bottom test and alter register allocation. | RacerCollisionWorlds::ActivateWorld 40.37% -> 55.05% with indexing -> 75.47% with the second bounded found-return loop. Retail exhaustion at index 6 and both TTL paths preserved; three local refinements were identical. |
| Reuse prepared rectangle edges across virtual border calls and compute dependent fill bounds after the call shown in retail; cached dimensions and repeated image reads can hide the original snapshots. | MenuFrame::SetRect 29.63% -> 75.79% via edge reuse and retail preparation/call order. Delaying dimensions alone regressed; a final coordinate precompute fell to 72.28%. Evidence 0x0046ee89-0x0046f02b. |
| Dead end: name-buffer hoisting, token-loop spelling, blend-counter scope and spelling constructor defaults locally were identical; constructor-assignment buffer reuse and token-order case movement regressed. | GolMaterialLibrary::Load stretch: six trials, baseline/best 85.56%, constructor assignment 65.70%, case movement 84.07%. Reverted; no shared-header/inlining/COMDAT changes. LR 0x00410810 is CreateMaterials, not Load. |

<!-- End Round 4 matching findings -->

<!-- Round 5 matching findings -->

Round 5 findings:

| Technique or dead end | Evidence |
|---|---|
| Express conditional calls in each branch when retail selects and pushes arguments there; a cached source-pointer local before a common call can change the entire register layout. Combine this with fresh member reads across callbacks. | RaceSession::InitializeInput 27.62% -> 51.66% from direct binding reads -> 53.94% with the retail sink lifetime -> 92.53% from branch-local SetBinding calls. Alias removal alone regressed; indexed player walks were identical. |
| Dead end: a decal-member alias can preserve useful store scheduling; removing it, center-vector storage and existing vector helpers regressed a function whose retail code retains zero-vector FPU operations. | RaceDecalManager::Trail::AddSample: six trials, best/baseline 59.73%; direct member 53.39%, vector variants 46.09%-53.33%. All reverted. |
| Dead end: indexed save-record copying and an early zero counter restored the retail context reload but exchanged count/byte-offset homes; named indices, loop spelling and record-address form did not fix allocation. | MenuManager::InitializeSaveSystem: six trials, baseline 84.08%, alternatives 83.33%. A signed counter needed an explicit unsigned comparison to avoid a new warning. All reverted. |
| Dead end: removing a shadow-decal alias, whole-vector copy/assignment and DistanceSquaredTo regressed a near-match; a clean transform local did not alter virtual-call scratch registers. | CarVisuals::DrawTransparent: six trials, baseline/best 89.29%; alias removal 68.29%, helper 77.11%. Reverted. |
| Dead end: grouped nested cases and a post-switch movement flag did not reproduce a shared goto sound branch; moving the success initializer changed saved-register roles without a gain. | CarBuildScreen::HandleBuildKey: six trials, baseline/best 89.56%; structured variants 42.41%-72.88%, initializer-only controls 87.91%-89.07%. All reverted. |
| Dead end: removing an empty-roster goto and correcting an unused return to void can be codegen-neutral; indexed/ref/named-index neutral-loop access did not fix one address-generation scratch register. | RaceSetup::Update: six trials, baseline/best 95.27%; direct indexed neutral loop 87.68%. Both source and audited header trial reverted. |
| Dead end: converting a strength-reduced byte palette walk into typed indexing, natural loops or entry references worsened scheduling; store/counter reorderings also regressed. | GolDirectDrawPalette::Set332PaletteEntries: six trials, raw baseline 94.05% and effective 100%; typed candidates 44.97%-62.20%. Reverted; effective 100% is not sufficient for a Match title. |
| Indexed triangle traversal plus eliminating a redundant start alias and success goto gave a small gain; traversal-stack indexing and vector-helper substitution regressed. | GolBoundingVolume::IntersectSegment 45.10% -> 46.48%; retail first/count range and success writes audited at 0x004041c8-0x004041d8, 0x004042ed-0x004042f6 and 0x004043cb. Both-target checks passed, GD unchanged. |
| A low-scoring list function may use a different traversal and tie ordering from its shared helper; implement the audited traversal locally to avoid changing unrelated functions. | DirectSoundManager::MakeSoundAvailable 34.52% -> 44.96%. Retail walks backwards and prepends on exhaustion; original 0x0041918b-0x004191ab, 0x0041924e-0x00419272. Shared helper unchanged. |
| Preserve a list terminal sentinel when retail calls an out-of-line insertion at exhaustion; converting it to NULL and appending inline loses the call shape. | DirectSoundManager::QueueSound 22.29% -> 29.61%; direct insertion at 0x0041953e, fallback InsertBefore call at 0x00419521. Combined loop guards and hoisted references did not beat the explicit walk. |
| A long-lived context local can be correct for most fields but wrong for call arguments after resource mutations; reload only where retail does. | MenuManager::PrepareRaceContext 60.87% -> 64.20%; context reloads at 0x0042da07, 0x0042da3b and 0x0042da50. Save-record walks and indexed player slots regressed; alpha hoisting was identical. |
| Extending a material counter zero across builder calls can give a small gain; splitting counters, caching the count and removing the builder alias did not solve the remaining stack/register mismatch. | MenuManager::BuildPlayerDriverModel 37.37% -> 38.42%; retail zero precedes GetCosmetics at 0x0042dfde. All six trials compared and only the named function changes. |
| Use a guarded do-while when retail tests selection only after scanning a nonempty list; commuting equality can also recover the original register/memory compare. | RacePowerupManager::ReclaimExplosion 60.43% -> 63.77%; guard/scan/reset at 0x0045b3c3-0x0045b401. Initializer-only changes regressed; named remaining-time and separate saved-head variants gave no further gain. |
| Dead end: retail sentinel comparisons, sequential state tests, flags reloads and split stores did not recover the animation current-part register allocation. | PartAnimationResource::Update baseline/best 43.59%; six trials 40.66%-43.59%, all reverted. Retail zero-extends queued U16 then compares -1 (0x00463423-0x0046342f); no speculative bug fix retained. |
| Dead end: reloading a group buffer can recover retail read-modify-write operations while making alias/address and register allocation worse. | GdbPartLibrary::FlushCopyBatch baseline 38.66%; six trials 22.70%-32.62%, all reverted. Repeated GetMutableGroups, cached model, masked locals and split count staging did not improve it. |
| Per-channel postincrement reads can recover palette decode scheduling when once-per-entry cursor stepping cannot; preserve retail metadata locals and signed byte-count rounding. | GolTgaFile::ReadHeader 66.25% -> 74.12% in BOTH targets. LR channel increments at 0x00413b9f and 0x00413bda, GD at 0x1002a8cf and 0x1002a90a. Masks alone were identical; widened packed colors regressed. No helper/header/build-setting changes. |
| Extracting identical insertion loops into private in-class helpers can preserve every comparison score while removing duplication. | DirectSoundManager helper follow-up: MakeSoundAvailable remains 44.95677233%, QueueSound remains 29.60526316%; both full LR/GD maps are unchanged from their published branches. Full checks passed and commits amended. |
| Dead end: improving every caller of a shared inline helper can still remove fully matched out-of-line callees; check both address sets as well as caller scores. | One InsertByPriority retail forward trial improved Update 17.05% -> 20.03%, MakeSoundAvailable 34.52% -> 34.59%, QueueSound 22.29% -> 29.61%, but NextValid and FirstValidLink disappeared (100% -> stub). Fully reverted; no retention or annotation hacks. |

<!-- End Round 5 matching findings -->

| Stub work: when the original reloads an array base AFTER a call whose result is stored into that array (`entities[i].m_x = GetY(...)`), store the call result in a local first and then assign. Writing the assignment directly evaluates the left-hand address before the call | GolWorldDatabase::InitializeEntities: 69 → 34 differing instructions from this alone |
| Stub work: a plain `while (j < count) { ...; j++; }` with a function-scope counter can put compiler-generated loop offsets in the original stack slots when both `for` and `do`/`while`-with-guard fail | InitializeEntities: 34 → 28 differing instructions |
| Stub work: measure the WHOLE object file before committing: only the target function's bytes should change | Every stub branch |

| CI gotcha (#570/#575): `switch` over a LegoU32 with `case` labels from an enum whose values are >= 0x80000000 builds in MSVC 6.0 but fails the "Current MSVC" job (narrowing: the enumerator is a negative int). Write `case static_cast<LegoU32>(c_enumValue):`. MSVC 6.0 codegen is unchanged. If Visual Studio 2019+ is installed, also build each branch's changed .cpp with the modern compiler before pushing. | GolModel::DrawNode, GolModel::Draw |

| Review catch (R8, HomingMissileAction): when you add a `// GLOBAL:` for a float that `reccmp/lego-racers-floats.csv` already lists, delete that CSV row in the same commit (a GLOBAL and a CSV row on one address always mismatch, see CLAUDE.md "Float Constants"). Use plain file-scope `const`, not `extern const`, unless another TU references the address. | HomingMissileAction::Update |

**Dead ends so far:** zero-vector construction feeding FPU math (`Clear()` then arithmetic) in HazardActionBase::ComputeDropPosition. Chained assignment, setters, memset and aggregate init all failed; it stays at 50.79%. DisableTargetPoints: six trials, no gain.


<!-- Round 6 rewrite findings -->

Round 6 rewrite findings:

| Technique or dead end | Evidence |
|---|---|
| Scope an address-taken temporary to the loop that uses it so its stack home can be reused later; keep truly shared outputs at function scope. | GolBmpFile::LoadTiledTexture: lock pitch scoped to its loop recovered the original 0x5c frame; 22.30% -> 68.64% in both targets. CircuitStandings::Draw: hoisted text-measurement outputs recovered 0xd4 frame; shared rank/sign/best-score locals recovered original homes; 25.24% -> 74.79%. |
| Audit the original allocation size, flags, signedness, callback reloads, and malformed-input quirks before optimizing a low-scoring draft. | GolBmpFile uses 4*rowByteStride+8 and clears only flag bits0x06. CircuitStandings carries its selected index across rows and consumes the delta entry after search exhaustion. GolBoundingShape treats bounds indices and PVS counts as signed16. Evidence in each class report. |
| A sparse switch plus fresh member reads and a single ternary store can recover most of a hand-translated dispatch function. Separate increments in the two original dirty-scan branches can also change the whole register allocation. | GolModel::DrawNode 32.49% -> 87.77%; Draw38.16% -> 87.32%. Recovered original renderer-source pointer loads, color store and switch tree; two-path dirty increments alone raised DrawNode64.03% -> 87.77%. No renderer/header edits. |
| Mutate the incoming cursor parameter after saving its immutable first payload; this can recover more retail register allocation than a second local alias. | CollectLeavesFromPvs: 38.32% -> 43.37%, signed count/bounds and shared append retained. Header and classification helper unchanged. |
| Preserve an original pointer-bounded fill and edge writes even when a draft added an outer integer span guard. | DrawTriangles4Bpp30.61% -> 54.68%; original odd-edge nibble writes occur without startX<endX. DrawTriangles16Bpp47.73% -> 54.10% after single word-pointer fill; compiler emits rep stosd/stosw. See original disassembly addresses in report. |
| Dead ends: case ordering, equivalent loop spelling, scalar declaration hoisting, field references and indexed traversal do not reliably solve register mirrors. A shared ignored fastcall argument can also block a local match. | DrawNode variants held87.77%, folded field initializers regressed81.00%. PVS indexed access regressed; its existing ClassifyBox formal forces EDX=0 unlike retail. Visibility traversal stopped48.28% after10, no signature or helper changes. Full trial tables and remaining regions documented. |

<!-- End Round 6 rewrite findings -->

<!-- Round 7 rewrite findings -->

Round 7 rewrite findings (queue complete):

| Technique or dead end | Evidence |
|---|---|
| Snapshot tile width together with height before the copy guard; reproduce callback output temporaries and allocation order rather than caching a single pre-call index. | GolTgaFile::LoadTiledTexture63.34% ->93.41% both targets. Width snapshot alone83.37% ->93.41%; pitch index recomputed after LockPixels. |
| Keep compressed-tail source once when retail reuses it for Read and Decompress; signed row-byte shifts and shared leftover state matter. | GolBmpFile::ReadPixels54.70% ->78.09% both; tail pointer trial72.61% ->78.09%. |
| Pointer-form termination over typed indexed entries can recover byte-offset strength reduction; name a converted float divisor before dividing to recover fild/fdivp, then split progress initialization from +=. | CheckpointGraph::ComputeLapFractions38.25% ->96.84% raw,100% effective. Three equivalent SIB encodings remain; Improve title retained. |
| A shared false epilogue, ZeroMemory descriptor initialization, and retail calculation/store order can recover an exact setup function. | DirectMusicStream::Initialize33.33% ->54.33% ->99.21% ->100%; service count before ring size, descriptor format before byte count. |
| Mask the byte size directly for dword-only memset; a typed indexed fill can reload aliased sizes, and countdown forms can add zero guards. Array outputs and declaration hoisting did not recover EBP frame selection. | DirectMusicInstance::FillBuffer33.78% ->60.84%; frame size0x24 correct, FPO and output homes remain different. Retail NULL file guard and average-byte-rate silence formula audited in report/ledger. |
| Capture the inputs of a repeated guarded virtual call in a file-local inline helper when retail loads its this argument before the null guard. | CarVisuals::Update62.20% ->67.80% with four-use CopyParticleOrientation; vector Clear/initializer placement ->68.78%. Whole-object audit required before retaining helpers. |

| Use separate chase storage, reuse movement/unit and facing/cross outputs, and preserve full matrix34 scratch including translation zeroing. Audit accumulated cdecl argument pushes before identifying quaternion endpoints. | CarVisuals::UpdateCurseEntity45.99% ->72.46%; frame0xfc restored. LerpQuat is CURRENT,DESIRED; declaration reorder and subtraction helper neutral; row copies/scalar projection regressed. |
| Whole SoundVector assignments plus an inline cross helper can recover member loads that direct scalar source propagates from camera locals. Normalize the actual output when retail passes the same address twice. | CutscenePlayer::UpdateListener26.19% ->40.00% after removing fourth vector ->96.25% with vector copies/helper. Combined cross/normalize helper neutral; three instruction placements remain. |
| Dead end: per-record helpers, model references, explicit group pointers, argument order and cursor spelling did not recover repeated group-base loads without extra register saves. An early scalar snapshot can still give a tiny isolated gain. | FlushCopyBatch10 trials:38.66% ->38.98% only from vertex-count capture before group zero; rewrites23.78%-36.88%. Stopped below60%; full remaining regions in class report. |
| Reconstruct contiguous float rectangles, then give tile intersection its own short lifetime so the compiler can reuse the expired setup clip home. Declaration order alone does not solve aggregate lifetime overlap. | GolImage::DrawStretched45.96% ->47.52% scalar reuse ->76.75% structs ->94.28% separate tileClip ->97.46% with original tileRight zero and final quad copies. Exact0x44 frame/homes; scalar scheduling trial regressed92.89%. |
| A null initializer across a virtual branch can change the register graph; a single call-or-null ternary recovers the retail join. Verify concrete virtual slot names through class definitions before interpreting snapshots. | UploadTiles50.43% ->52.00%,10 trials. Palette+1c gets SIZE, while entries pointer is field+04; original read order already matched. Source alias/output hoisting regressed49.86%, reversed palette order45.58%, paired palette struct30.86%; source byte order/minima/loop spelling neutral. |

<!-- End Round 7 rewrite findings -->

<!-- Round 8 rewrite findings -->

Round 8 rewrite findings (main queue complete; stretch not attempted):

| Technique or dead end | Evidence |
|---|---|
| Separate vector locals plus explicit component row copies can avoid the extra integer-copy register save from whole-vector assignment. Use the existing scalar multiply-assignment to capture a per-vector scale, and put the shared epilogue after a bounded outer loop. | CalculateBoxContact 35.86% -> 53.31% with component copies, 56.59% with per-vector scale capture, 60.44% with the two-shape loop. Recovered 0x38 frame. Whole Y/Z copies regressed to44.38%; by-value vector multiplication regressed to29.62%. Positive-corner operand reversal and half-scale operator spelling were neutral. |

| Replace a monolithic scratch struct with named locals and use whole-vector assignment when retail constructs a destination alias. Explicitly group the two projected radii before adding them. | TestBoxOverlap82.38% ->83.02% named locals ->84.03% pair grouping ->87.81% face-normal vector copies. Frame0xe0 retained; row declaration shuffle and convention-compliant cross helper were neutral; explicit center-delta input/output reuse regressed. |
| A duplicated digital-input centering block can obstruct the retail shared neutral path. | UpdateSteering68.78% ->81.56% after unmatched digital input selects zero delta and flows into the shared centering block. One global delta initializer regressed69.75%; expression/declaration spelling was neutral or worse. All retail rates and clamps preserved. |

| Reuse planar-delta storage for the later lead candidate and owner-direction storage for later facing; stage scalar factors and use the existing vector offset-add operator. | LaunchAtRacer52.86% ->71.66% vector reuse ->72.60% target capture/direct height ->75.12% staged products/vector offset. Frame0x30 recovered. Branch-local lead vectors, zero-z local and a projection helper did not improve; retail NaN minimum fallback explicitly restored. |

| Capture the member divisor into a real scalar before distance/divisor, stage the millisecond factor, and initialize object state before a zero vector when the original interleaves those stores. | Deflect63.54% ->75.51% after restoring retail millisecond lead/temp ->91.19% direct fallback copy/staged milliseconds ->94.90% divisor capture ->97.96% state-before-vector initialization ->100% after staging the Y product as component assignment then *=. Existing Clear and vector multiply, plus reversed Y operand spelling, were neutral. Original0x18 frame retained. |

| Recover real address-taken lifetimes, retain subobject pointers across callbacks and start their lifetimes at the observed call boundary. A missing const global can be hidden by literal folding. | HomingMissileAction::Update65.16% ->66.10% verified width-global restoration ->68.60% projectile lifetime/ternary ->70.99% animated pointer ->75.09% original perpendicular-test and direction-copy order. Hoisted/reused vectors plus retained projectile recover0x84 frame; hoisting alone is neutral and early pointer capture regresses. |

| Follow the full parent chain for the actual point transform, then reuse expired origin/axis-copy vectors for world outputs. | RollingRockHazard::Update67.94% ->95.42% after reconstructing unconditional parent point traversal and rock-only axis traversal. Original0x48 frame recovered with six real vectors. Existing scale operator is neutral. Behavior correction and exact callbacks recorded in ledger/report. |

| A retained object snapshot for reads/flags plus direct member writes can prevent early flag CSE and restore a caller-saved current-part register. Audit widened sentinels and compound-state fallthrough against the instructions first. | PartAnimationResource::Update43.59% ->55.28% direct members ->71.07% captured reads/direct queue writes ->90.68% one shared idle-queue block selected by a real queueIdle boolean. Simple flags lifetime edits and queue wrappers held41.49%; sparse switch regressed61.16% from the best. Original zero-extended ushort versus32-bit -1 guard and duplicate-role fallthrough restored and ledgered. |

| Preserve a walking scan but use indexed member accesses in a free-slot path when retail reloads the container base after callbacks. Initialize victim/priority before the name lookup when those values survive the call. | SpawnParticle42.91% ->94.92% indexed callbacks/early locals ->99.32% raw,100% effective with bounded while ref scan. A do-loop added an initial-load/test; independent ref-store ordering remains. Improve title retained below raw100. |

| Indexed nested slot accesses can remove an extra strength-reduced subobject cursor, freeing a register for the countdown. A convenience wrapper can then be less faithful than the direct virtual call. | RaceDecalManager::Trail::Initialize49.15% ->80% indexed slots/wrapper ->87.72% direct SetPrimaryModel. Original single slot cursor/countdown and no-local frame recovered. Factory-result capture alone, depth setter and input aliases were neutral. |

| Separate raw direction from divides only after preventing unwanted cross-threshold CSE; combine with real vector storage and existing float setters. | RaceDecalManager::Trail::AddSample59.73% ->78.60%. Reversing the equivalent squared-distance differences avoids two retained direction spills and recovers0x24 frame. Early raw-direction rewrite regressed45.89%; center only52.68%; zero offset subtractions still fold away and a const-reference subtraction helper is neutral. |

| Scope key cursor/base setup to its count guard, reuse the incoming signed frame-count slot for interval duration, and materialize the scaled blend vector before output additions. | CmbModelPartTrackData::InterpolatePosition38.82% ->57.78% frame reconstruction ->60.76% named float divisor/staged Y product in both targets. Original0x10 frame recovered; by-value vector result used0x18. Separate widened count and do-loop variants regressed40%-46%. |

| Shared source may need both original inlining shapes preserved; reject a candidate as soon as either target regresses from baseline, even if its other target improves. | InterpolateRotation69.66%LR/35.05%GD ->70.75%LR/63.13%GD with guarded key-base/cursor lifetime. Duration-argument reuse and common decode join regressedLR to46.94%/27.12% and were discarded. Existing GOLDP /Ob2 source setting verified, unchanged. |

<!-- End Round 8 rewrite findings -->


<!-- Round 9 rewrite findings -->

Round 9 rewrite findings (main queue and stretch complete):

| Technique or dead end | Evidence |
|---|---|
| Reuse one explicit RGBA buffer across repeated color assignments when independent inline calls allocate separate branch-arm temporaries. Use the existing const-reference color overload. | RaceDialog::Draw 50.76% → 79.90% with retail flow/colors → raw100% with shared ColorRGBA and sample-first pulse product. Recovered 0x18 frame; GolFontBase untouched. |
| Retain references to real addressable callback outputs through subsequent arithmetic, and bind a second output reference after its callback to shorten overlap with the caller object. Snapshot the model across group/dirty stores. | ParticleSystem::Draw 50.60% → 58.86% shared saved-next loop → 82.39% axis references → 87.69% deferred forward binding → 95.78% model snapshot → 98.80% entity binding after first callback. Original 0x24 frame/register roles recovered. Raw below100: Improve title. |
| Scalar deltas can recover descending homes that a GolVec3 cannot; in-place component operations avoid the extra result object from a value-return vector operator. Stage Y/Z products as component then *=scale. | UpdateBounds 52.76% → 76.47% scalar homes → 96.06% in-place operations/frame0x34 → 99.22% staged Y/Z. Radius-zero store scheduling is the only residue; moving its initialization was neutral. |
| Represent actual bound storage and its callback lifetime before chasing register scheduling; explicit stored-normal dot expressions can match better than an in-class alias helper. | ComputeFrustum 26.15% → 62.63%, ComputeFrustumFromBounds 22.14% → 62.62% with real GolVec4 bound storage and original corner/plane ordering. Existing Dot2 header left alone; pointer aliases/axis scalarization did not improve. |
| Replace walking object pointers across allocation calls with indexed member access, then reload arrays/counts at the observed boundaries. Distinct parameter-record homes can require distinct records. | GolFont::CreateSurfaces 59.10% → 92.95% indexed reloads → 94.27% final record initialization before inline name copy. Packed-key snapshot regressed70.93%, final texture alias93.39%; reverted. Original separate20-byte loop/final records retained. |
| Declaration order of real independent snapshots can change the whole register coloring; paired independent stores often need reversed source statements. | CarBuildScreenBase::Draw 65.56% → 66.94% alpha/edge-store order → 79.12% right/top/left/bottom snapshot declaration order. A Rect-value snapshot, broad output hoists and a translation helper regressed57–62%; measured-width/minWidth reuse was neutral or slightly worse. |
| Recover a real small result record rather than padding the stack. Reject source-only accessor gains that disturb folded CRT address sets. | SelectTextureFormat six-dword channel-count record recovers0x18 frame; 38.81% → 40.00% after count equality operand order. Getter T8 removed matched GD _CallMemberFunction0(0x1004afb6), so rejected with no annotation or ICF workaround. Search-mode grouping regressed34–37%. |
| Whole-object scope checks must include added and removed unannotated contributions, not just matched score maps or changed-name intersections. Normalize a return-signature spelling only for the exact target method. | DirectSoundManager::Update's35.48% candidate lost GolList::Append; restoring its existing fallback retains29 functions at33.28%. Final strict audits explicitly compare symbol additions/removals for all first four branches; seamed sphere changes only its own return signature. |
| Preserve retail scratch reuse and absolute-before-local output order even when the old geometry draft looks more conventional. A repeated scratch cursor advance can be an invented behavior. | BuildSphere15.10% →42.65%, BuildSeamedSphere19.09% →48.78% after byte winding scratch/output order and retail band reuse. No between-band scratchStart advance; seamed UV.v remains0. Ten trials each; scalar/frame variants did not reach60%. Details and addresses in RaceSkyState/ledger. |
| A larger scalar clipping rewrite can reveal real bugs while still yielding only a small byte gain; stop at the trial ceiling and record unresolved homes. | EmitPolygon17.23% →19.25% after10. Retail reads last clip flag and fan anchor before count guards, and keeps generated clip flags in sidecar storage. Original0x1a4 versus rebuilt0x1a0 frame remains; no invented guard or global flag write retained. |
| Treat raw100 and effective100 separately when choosing titles, and reproduce inherited warnings on pristine code before accepting them as baseline. | RaceDialog is the only Match title. Particle98.80% and UpdateBounds99.22% are only effective100 and remain Improve. Pristine header-triggered double rebuild reproduced existing warnings and exact LR/GD maps; all branches also compile under current MSVC with no new warnings. |

<!-- End Round 9 rewrite findings -->

<!-- Round 10 rewrite findings -->

Round 10 complete on `41b3dccdec2c88d6752f39595c70c66644359ba4`: main queue plus stretch, 23 functions, 16 improvement commits on 12 pushed class/file branches, no PRs. Raw100: CutsceneVisual::Update and MenuModelCarousel::SetupCamera. Seven functions had no retained gain. Reports: `codex_reports/match/Round10.md` plus per-class files. Ledger: G29–G32, U9–U15, R50–R54; all prior 104 rows preserved.

| Technique or dead end | Evidence |
|---|---|
| Reuse real viewport dimension homes for centering; stage each integration scalar from rate through elapsed product and current value before storing. | CutsceneVisual::ComputeLayout 56.50% →67.80%; Update 63.64% →raw100%. Expression reordering alone was neutral. No added stack storage or helper. |
| Copy real Rect values before editing edges; start a real accumulator while incoming argument homes are still live, then restore paired store order. | MenuTextField::DrawSelf 56.21% →87.01% with full Rect snapshots then bottom-4; MenuTextLabel::DrawSelf 63.16% →97.89% after early lineBottom lifetime and edge order. MenuModelCarousel::SetupCamera 68.09% →raw100% with a viewport-value copy after UpdateViewport; pointer/reference/Clear forms failed or were neutral. |
| Finish callback results before reloading the destination context. A call-or-null ternary can recover a snapshot even when its branch stays partial. | MultiplayerPickScreen::HandleKeyDown 69.52% →84.57% by staging GetSelectedRecord before reloading m_context for SetSelectedRecord. Typed cursors 82.98%, active-record alias 72.34%. RaceSession::TakeScreenshot 87.14% →91.55% with call-or-null selection; filename-exhaustion context quirk preserved. BindCheckpointMaterials had ten unsuccessful trials and was restored. |
| Capture actual short subobjects at the observed call boundary rather than flattening member/getter accesses; avoid extending their lifetime across unrelated callbacks. | CarVisuals +18/car+44 aliases raise TetherProjectile::UpdateReleased 77.98% →95.45%, RebuildBeam 78.65% →97.78%, UpdateAttached 81.32% →98.37%. In contrast, six GrapplingHookAction::AdvanceState alias/initialization trials lost the shared-zero EBX save or shifted homes; all reverted. |
| Preserve scalar/component-copy lifetimes and stage a named force before its x product. Existing record accessors can recover register allocation. | TurboAction::AnchorToRacer 62.02% →88.10%; GolD3DTexture::CreateMipmapBuffers 66.25% →79.63% after width/height capture, existing mapped-entry getter and bytes-per-pixel staging. GrapplingHookAction::Update 87.65% →90.02% with physics-car capture and staged force-x. Protected helpers untouched. |
| Reuse a carried decoded-count variable for each new chunk header, and start the available-pointer zero at acquisition. Branch-local initialization can recover an argument-slot accumulator. | Shared GolBmpFile::LoadTiledTexture 68.64% →81.60% with count reuse →82.10% with pointer-zero placement in both targets. ReadPixels 78.09% →92.61% with rowAmount initialized in partial-copy arms →95.24% with width/raw-output cursor lifetimes and minimum operand order. |
| Snapshot the emitter only through the first RNG/global write and use the observed word chance comparison; reload it at later callback boundaries. | CutsceneParticle::Update 82.69% →84.21%. Timer-only and vector-scope changes were neutral or worse. Matrix math already matched; emission policy and RNG order unchanged. |
| Inline-pool placement and effective100 do not excuse unrelated object changes or a false Match title. | MainMenuScreen::HandleKeyDown inline placement was neutral 66.67% or regressed 16.67%, and changed its destructor contribution. SaveLoadScreen::CreateWidgets stayed raw70.42% through two new lifetime trials plus six previous neutral attempts. TargetPointList byte flags remained intact after three new trials and prior dead ends. No empty branches pushed. |
| Keep the partial source when aggregate rows, publication order or cross-product helpers disturb a correct FPU frame. | CutsceneParticle::SetOrientation six failures: delayed cross-x 79.22%, typed rows 73.29%, standard cross helper 78.21%, staged helper neutral 89.74%, scalar cross 77.63%, direct member stores 85.90%. All restored; no helper retained. |
| Record original-supported discrepancies even when their correction regresses; include unannotated object contributions in scope checks. | ReadHeader full16-bit planes correction 72.58%, signature/type variants 78.63% or84.94%, all below86.34%; six trials restored. R53 records CORE401a8d–401ad6, INFO40 401c6c–401d5e, INFO64 401ea4–401f9b. Typed-plane T6 also changed LR LoadTiledTexture's contribution and was rejected. |

Final audit verified every commit parent/title/scope, only its target improving per commit, zero regressions/address-set changes, and all 12 remote tips. Double builds, both-target vtables/datacmp/folded/lint, address padding, clang-format22, complete COFF audits and current MSVC x86 compile passed for each retained commit. The restored final branch rebuilt to its published maps and object. No in-game acceptance claimed.

<!-- End Round 10 rewrite findings -->


<!-- Round 11 rewrite findings -->

Round 11 findings (in progress; results in codex_reports/match/Round11.md):

| Technique or dead end | Evidence |
|---|---|
| Keep a real scalar target component alive through distance, chase and snap; separate vectors whose old contents must not be exposed to later out-of-line output calls. | CarVisuals::UpdateCurseEntity72.46% ->85.29% target-X lifetime ->93.67% separate chase/blend movement objects ->96.08% direct scale and staged cross operands. Original FST at0x0043f611 preserves extended target X; no frame padding or helper-signature workaround. |
| Typed paired cursors over real member arrays can recover register pressure; an existing component-copy getter can recover x87 loads that direct orientation expressions lose. | CarVisuals::Update68.78% ->70.24% paired flag/timer fade walk; UpdateSkidMarks84.63% ->87.37% GetOrientationRow1/GOLVECTOR3_DOT plus original exclusive inactive-cleanup arm. Both commits change only their own function. |
| Proven behavior corrections can regress; isolate independent gains and ledger the unresolved defect. Byte-width casts can recover one opcode while disturbing the whole register graph. | Skid contact timer correction T1-T6 scored76.73%-82.77%, reverted; R55 records original0x0043f242->0x0043f259. DirectMusicInstance::SetPath byte-local/widening/inline-helper trials each65.79% versus93.15%; all reverted. FillBuffer restart snapshot/decoder aliases were neutral60.84% after prior six trials. |

| Reuse one address-taken length object for chunk callbacks and the later mapped-read accumulator. Destination lifetime and loop spelling can affect the entire function. | GolStream::BufferedRead81.47% ->85.04% in both targets with guarded do-loop and shared length. Typed buffer addressing alone was neutral; natural while/explicit break regressed70.31%/70.07%. BuildPathname common branch-lifetime form regressed LR77.38% while GD stayed97.96%; helper and else forms were neutral, all restored. |

| Keep one pointer variable across a state machine, but assign it at each observed branch boundary; distinct branch-local variables can color registers differently. Re-test component-copy order after recovering the register graph. | HomingMissileAction::Update76.45% ->77.13% direct member hit getters ->97.27% one entity variable with armed/flying assignments ->raw100% staged trail-Y product and natural XYZ copies. Distinct per-arm variables regressed73.72%. No gameplay policy changes; prior G24-G25 still applies. |

| Stage signed elapsed conversion separately from the seconds multiplication, after the observed integer input normalization. | PlayerControls::UpdateSteering81.56% ->83.80%; byte boolean regressed78.53%, analog/delta reuse and digital ternaries were neutral. Original signed units/rates/clamps and G17-G18 remain unchanged. |
| Separate actual per-cell matrix scalar lifetimes; stage first products, retain inline second products and write final sums directly. Aggregating a basis or copying rows can still disturb already-correct math/store scheduling. | TransformMatrixToLocal81.08% ->84.78%LR with0x24 frame; full staging77.72%, grouped expressions66.30%. SetDirectionSide six failures34.25%-85.92% versus91.67%; SetDirectionUp typed refs neutral93.06%, two store-order changes regressed. Restored both setters; effective100 is not raw100. |

<!-- End Round 11 rewrite findings -->

## 5. Work loop (per function)

1. Find the original in Ghidra (project `H:\Ghidra\Lego Racers\`, 1999 exe / GolDP.dll). Read-only — do NOT rename or edit the Ghidra project.
2. `reccmp-reccmp --target <T> --verbose 0x<ADDR> --print-rec-addr` to see the diff.
3. Edit, double-build, re-run. Iterate. Use CLAUDE.md "MSVC 6.0 Codegen Patterns" for register/branch/loop levers.
4. If a function won't improve after ~6 honest attempts, revert it and move on. Don't game the match with hacks.

## 6. Hard rules (summary — CLAUDE.md wins on any conflict)

- One class per PR; under ~10 files.
- Functions in a .cpp ordered by address ascending; addresses 8 hex digits lowercase.
- Annotation colon required (`// FUNCTION: LEGORACERS 0x...`). Every annotation is a real address.
- No raw pointer arithmetic / IDA-style casts; no gotos; no raw float bit patterns.
- Unproven types stay `undefined`/`undefined4`. Naming: `m_`/`p_`/`g_` prefixes, `m_unk0xXX`, `FUN_xxxxxxxx`, `VTable0xXX`, `c_` enums. Unused params unnamed.
- Lego types (`LegoS32`, `LegoFloat`, …) in game code; Win32 un-suffixed names (`CreateWindowEx`, not `...A`).
- No `this->`. `NULL`/`TRUE`/`FALSE` where applicable.
- Never regress another function. Never demote or remove someone else's match.

## 7. Acceptance criteria (every PR)

- Clean double build, no new warnings.
- After build:
  ```
  reccmp-reccmp --target LEGORACERS --json LR-after.json
  reccmp-reccmp --target LEGORACERS --diff LR-before.json
  reccmp-reccmp --target GOLDP --json GD-after.json
  reccmp-reccmp --target GOLDP --diff GD-before.json
  ```
  Diff shows only improvements; ZERO regressions on either target.
- `reccmp-vtable --target LEGORACERS` and `--target GOLDP` clean.
- `reccmp-datacmp` on both targets clean if any global changed.
- `reccmp-decomplint --module LEGORACERS --warnfail ..\LEGORacers` and `--module GOLDP --warnfail ..\GolDP` pass.
- clang-format 22 applied to touched files only.
- Also run the CI checks not covered above (see PR_GUIDE_decomp_racers.md section 2): `python tools\check_folded.py --target LEGORACERS` and `--target GOLDP`, `python tools\reccmp_addr_padding.py`, decomplint with BOTH dirs (`reccmp-decomplint LEGORacers common --module LEGORACERS --warnfail`, `reccmp-decomplint GolDP common --module GOLDP --warnfail`), and `reccmp-datacmp` on both targets.
- If a change alters behaviour (call arguments, units, control flow), confirm it against the original disassembly and say so in the report. A higher score alone doesn't prove the semantics.

## 8. Out of scope

- No pushes to upstream, no PR creation — Dust opens PRs.
- No edits to CMakeLists.txt, tools/, reccmp/*.csv, .github/, CLAUDE.md unless the task requires it and it's flagged in the report.
- No Ghidra writes. No changes outside `D:\Code\LR1\decomp_racers`.

## 9. Report (per branch)

`D:\Code\LR1\codex_reports\<branch>.md`: class, functions touched with before→after %, full `--diff` output for both targets, lint/format results, anything abandoned and why, suggested PR title in upstream style (`Match X::Y`, `Improve X::Y`).
