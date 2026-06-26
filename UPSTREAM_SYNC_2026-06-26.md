# ObtainX ⇆ Obtainium upstream sync — 2026-06-26

Branch: `chore/sync_upstream_20260626` (off `main`).

## Situation
- **True merge-base:** `49b42f67` = upstream `v1.3.3+32` (2026-03-20).
- **Last "sync" (v1.4.2) was cherry-picked/squashed, NOT merged** → v1.4.2…v1.5.2 tags are
  *not* ancestors of `main`, so git still thinks the common point is v1.3.3+32.
- Upstream is **150 commits** ahead of merge-base (**90 non-merge**); your `main` is 68 ahead.
- Trial `git merge upstream/main` → **53 conflicting files** (29 translations, 17 dart, 7 other).
- Split of the 90 new non-merge commits:
  - **35 commits** merge-base…v1.4.2 = content you already have (will mostly auto-resolve).
  - **115 commits** v1.4.2…upstream/main = genuinely new (90 non-merge, below).

## Collision hotspots (your big rewrites vs upstream refactors of the SAME files)
`apps.dart` (+5763/−1207), `settings.dart` (+2470/−1011), `apps_provider.dart` (+3504/−548),
`generated_form.dart` (+1259/−267), `source_provider.dart`, `add_app.dart`.
Upstream independently refactored exactly these — that's where semantic (not just textual) conflicts live.

---

## Triage of the 90 new commits

### A. WANT — bug fixes (low conflict, high value)
- `64709072` fix(notifications): separate exempt-from-BG-updates notifications (#2854)
- `4ffa249b`/`c5f562fb` fix(import): handle missing file picker gracefully (#2609)
- `9198a3c8` fix(build): fall back to ~/.pub-cache when PUB_CACHE unset (#2977)
- `547b8cb1` fix(build): jni build-id patch for reproducible builds (#2977)  [+ `2d371f93` TODO note]
- `83265f50` fix(zip): match APK filter regex against relative path (#2868)
- `1b843e61` fix(tv): restore import/export buttons on Android TV (#2879)
- `9c989edf` fix(sort): null release dates at bottom regardless of direction (#2626)
- `e88695ed` fix(notifications): separate track-only update notifications (#2945)
- `0717400b` Fix error on APK install (#2973)
- `e73d2710` fix(tarball): null-guard file.content cast + add archive dep
- `185fb0ed`/`649cfad3` fix(itch.io): null/abbr hardening
- `45d7a582` fix: iterate all JSON-LD blocks for SoftwareApplication schema
- `b0f35938` fix: apply global default settings to form items before building form
- `ff92bb44` fix: batch of critical bug fixes
- `1200b724` Fix syntax errors from #2803/#2631
- `4ec837bb` Fix scrolling on app info page stops short (#2877)
- `a0cd5d52` Fix RockMods locale data not initialized (#2762)
- `f81413bd` Fix Traditional Chinese reverting to Simplified on relaunch (#2872)
- `b751f0af` Fix changelog dialog text clipping (#2949)
- `750496e9` Fix type error adding via search + disable rename check by default (#2878)
- `4705956e` fix: Many issues and agentic code
- **`effcc546` Fix black bar around camera cutout in landscape (#2771) — directly relevant to your landscape work**

### B. WANT — features / source support
- `a7ed3aba` feat: detect .apkm/.apks as APK container formats (#2664)
- `38e30304` feat: tarball APK support (.tar.gz/.bz2/.xz)
- `a7d8d5dc` feat: itch.io source  [+ `a22b9e3f` Additional improvements]
- `3af8d068` fix: rewrite RockMods as track-only for new Next.js site
- `75627f44` feat(categories): sort tags alphabetically (#2947)
- `77914b34`/`ac29fa5d` APK filter regex pre-selects default asset (#2929)
- `118a5187`/`0824851c` Show OS installed version alongside pseudo-version (#2926)  [`d42c032b` undo]
- `09740604` Show latest version alongside installed in Apps tab (#2801)
- `b13a97ee` Dismiss update notifications after successful update (#2631)
- `6f690105` Include pre-releases by default option (#2895)
- `5e34f6fc` Disable battery optimization prompt option (#2753)
- `cad70431` Disable older-version warning option (#2752)
- `360d6842`/`4352f95f` Disable tactile feedback option (#2962)
- `6ed52fac` Disable markdown rendering for RuStore (#2923)
- `cd83d1d2` Inherit global Google Play installer default per-app (#2803)
- repo-rename detection (disabled by default per `750496e9`)

### C. WANT — infra/deps (do EARLY, affects everything)
- `2914d76b` Update Flutter + packages, increment version  ← land first
- `376e5bd6` / `d16a9120` Update packages
- `0f2439ca` Enable async MTE in AndroidManifest
- `8f29b2a2` Migrate WillPopScope → PopScope (#2928) — touches many widgets, port carefully
- `9fde14e0`/`848d8e66`/`9fde14e0` pubspec.lock churn (regenerate instead)
- docs: `731d955a` troubleshooting, `aecad461` sources

### D. SKIP — refactors that collide with your rewrites (you've already restructured these files)
Take the *behavior* if any, but do NOT take the refactor:
- `e5e7a2fa` split installApk/downloadAndInstallLatestApps (apps_provider — you rewrote)
- `d565b3c4` extract AppListBuilder, dedupe casts (apps.dart/generated_form — you rewrote)
- `dc61da50` extract SettingsToggleRow/SectionHeader/Dropdown (settings.dart — you rewrote)
- `2bd68d16` remove build side effects + busy-wait timeouts
- `32be5184` batch UX fixes + cleanups
- `367e698c` remove dead code generated_form
- `b81b067b` remove dead code + optimize apps list
- `2fad80e5` extract tactile feedback guard into SettingsProvider
- **PERF — evaluate to port manually (real behavior, but on rewritten files):**
  - `3ca525c6` optimize apps list build (#2962)
  - `845f68c3` eliminate icon-loading rebuild cascade (#2962)
  - `53ee3beb` remove deep copy from getAppValues()

### E. BATCH SEPARATELY — translations / assets (noisy, low-signal)
`9321a9a4 6fa2150e e2027d13 233e9d9d 20095100 c55c61ec 30243e6b 7c5e5b03 2b04d316`
`4636fb63 25ff8d03 0d31c3cb 963eb850 46460da2 b9af38ca 072cd306 6f6fc1d5 9deff6a6`
`298b48a0 30414685` (Add files via upload — assets). Resolve by taking upstream base, re-adding your keys.

### SKIP — version bumps (your scheme differs: you're 2.9.0+3900, upstream 1.5.2+2338)
`98864407` Increment version, and the `+version` hunk of `2914d76b`/`1f30e96f` (keep yours).

---

## Resolution outcome (merge of `upstream/main` @ `4ad4b1be`)

Strategy used: **full merge, ours-biased**. 53 conflicts resolved. `flutter analyze` →
*No issues found*; `assembleNormalDebug` → APK built. Merge-base is now repaired, so the
next sync will be a normal merge (no cherry-pick ancestry gap).

**How each bucket was resolved:**
- **pubspec.yaml** — kept our version + the two intentional pins (`dynamic_color` swap,
  `file_picker` beta.5), added NOTE comments so future agents don't "fix" them; took
  upstream's safe bumps (permission_handler, fluttertoast, animations, sqflite, app_links,
  background_fetch, webview, path_provider, flutter_local_notifications). `archive ^4.0.9`
  is now present (tarball dep). `pubspec.lock` regenerated via `flutter pub get`.
- **`.flutter` submodule** + `de`/`ru-RU` fastlane descriptions — these were deleted on our
  side (modify/delete); kept deleted.
- **29 translations** — recursive 3-way key union (ours wins on true conflicts; upstream
  fixes flow into keys we didn't touch; no key dropped). 9 upstream-only keys pulled into
  en.json (tarball/tactile/battery/pre-release/track-only strings). Files reformatted by
  the merge script (4-space → 2-space) — cosmetic.
- **rockmods.dart** — took upstream's track-only rewrite for the new Next.js site, then
  reapplied our off-isolate HTML parsing (`parseHtmlOffIsolate`).
- **All other dart files** — kept OURS (our rewrites supersede upstream's refactors).
  Removed 3 orphan upstream files that ours doesn't use: `app_list_builder.dart`,
  `settings_widgets.dart` (refactor extractions), `itchio.dart` (new source, see below).
  Fixed `generated_form_modal.dart` (auto-merge had injected the deferred
  `settingsProvider.selectionClick()` → reverted to `HapticFeedback.selectionClick()`).

**DEFERRED — wanted upstream features NOT ported (each needs integration into ObtainX's
redesigned UI; do as focused follow-up commits/PRs, not as part of the merge):**
1. **Tarball / `.apkm` / `.apks` container support** — github (`isApkContainer`,
   `allowIncludeTarballs`, `includeTarballs`), gitlab (`.apkm/.apks` filter), source_provider
   (`allowIncludeTarballs`). The `archive` dep + en.json keys are already in place.
2. **itch.io source** (`a7d8d5dc`) — re-add `lib/app_sources/itchio.dart` and register it in
   our `source_provider.dart` sources list (was removed as an orphan).
3. **Tactile-feedback toggle** (`#2962`) — `SettingsProvider.{selectionClick,lightImpact,
   heavyImpact,tactileFeedbackEnabled}` + settings UI + call sites.
4. **Include pre-releases by default** (`#2895`) + apply-defaults-to-form-items (`b0f35938`).
5. **Disable battery-optimization prompt** (`#2753`) / **disable older-version warning**
   (`#2752`) — `showBatteryOptimizationPrompt` / `showAppDowngradeError`.
6. **Track-only update notification separation** (`#2945`) — `TrackOnlyUpdateNotification`
   class + its usage in apps_provider.
7. **`tryParseLocale`** fix for Traditional Chinese reverting to Simplified (`#2872`).
8. **`noFilePickerAvailable`** graceful handling (`#2609`).
9. **Show OS-installed / latest version alongside** (`#2926`, `#2801`) and **repo-rename
   warning UI** in app.dart (we already have the detection logic in github.dart).
10. **WillPopScope → PopScope** migration (`#2928`) if any of our pages still use WillPopScope.

The 3 perf commits (`3ca525c6`, `845f68c3`, `53ee3beb`) target files we rewrote — re-measure
on our code before porting; they may already be moot.
