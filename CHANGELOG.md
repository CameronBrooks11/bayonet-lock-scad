# Changelog

<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning is informal - no git tags have been applied yet.

---

## [0.11.1] - 2026-09-23

### Fixed

- The lock half's rounded entry transition no longer leaves coincident faces in the mesh. It was built as a hemisphere — `difference() { sphere(_channel_radius); cylinder(h = _channel_radius * 2, r = _channel_radius * 2); }` — whose cutting plane passes exactly through the sphere's centre. That plane is also the swept torus's cross-section centre and the entry shaft's base, so three surfaces meet on one circle, and CGAL keeps the contact as a pair of coincident triangles instead of merging it. The result is still a closed surface, so OpenSCAD raises nothing and the file reaches a slicer as a "non-manifold" warning to be repaired. The cut was redundant: the sphere's upper half already lies inside the entry shaft unioned beside it, so the bare sphere gives the same solid without the exact contact.

### Notes

- **The solid is unchanged**; only the tessellation is. Twelve keyed lock halves on a 56.5 mm circle, `$fa = 2` / `$fs = 0.6`, `interface_radius = 10`, `shell_thickness = 2.5`, `part_height = 18`, `pin_angles = [0, 95, 240]`, `pin_radius = 1.2`, `sweep_angle = 30`, outer/CW: 35620.17762 mm³ before and 35620.17737 after, identical bounding box, and the 8 edges shared by more than two faces and 4 repeated triangles become none.
- Facet counts move a little either way, because the hemisphere's rim circle is gone. Against 0.11.0: `inner_2pin` 29112 → 29112, `inner_3pin_thick_shell` 42926 → 42926, `minimal` 28432 → 28400, `outer_3pin` 43276 → 43314, `outer_4pin_ccw` 57632 → 57616, `keyed_3pin` 58714 → 58794, `assembly_shell_only_preview` 188564 → 188754. Every example's volume is identical to eight significant figures and no bounding box moves. This is the first release since 0.10.0 where the multiset is not identical.
- A single coupling never showed it, at any tessellation — the shipped examples are all clean before and after. It takes several lock halves in one union before CGAL trips, four in the case above, and it is erratic with the count (three clean, four not, six fewer than five). That is why it surfaced in a consumer with twelve ports on a lid rather than here.

---

## [0.11.0] - 2026-08-11

### Added

- `pin_angles` parameter on `bayonet`, placing the locking pins at explicit angles instead of spacing them evenly. Evenly spaced pins carry that spacing's rotational symmetry, so an n-pin coupling has n indistinguishable locked positions; nothing in the geometry prefers one. That is harmless while both halves are axisymmetric and wrong as soon as one carries an orientation — a baffle, a tilted sensor, a keyed connector seated one position out locks correctly and points somewhere else, with no resistance to tell the assembler. Any unequal spacing removes the symmetry, which is how a BA15d lamp cap keys its two pins.
- `bayonet_keyed_pin_angles(number_of_pins, key_angle)`, returning even spacing with the second pin brought back by `key_angle` — the least disturbance that leaves no rotational symmetry.
- `bayonet_pin_pattern_order(angles)` and `bayonet_pin_pattern_is_keyed(angles)`, reporting how many ways a pattern can be seated. Consumers that hang something orientation-bearing off a coupling can assert on these rather than trusting the pin count.
- `bayonet_pin_pattern_margin(angles)`, the angle by which the worst-placed pin misses a channel mouth at the easiest wrong seating, and `bayonet_channel_half_angle(interface_radius, pin_radius, allowance)`, the mouth's half-width. Being keyed only says a wrong seating is not identical; it is only *blocked* when the margin exceeds the half-width, and a key below it still reads as keyed while letting a wrong attempt start to go in. The two are separate functions so this stays the caller's check rather than a hidden assert.
- `bayonet_pin_pattern_min_gap(angles)`, the ceiling on `sweep_angle`.
- `examples/keyed_3pin.scad`, showing a keyed coupling locked, the blocked seating drawn as an intersection beside it, and the margin asserted against the mouth half-width.

### Changed

- `number_of_pins` is now optional. Give exactly one of `number_of_pins` or `pin_angles`; supplying both or neither asserts.
- The channel-overlap check generalises from `sweep_angle < 360 / number_of_pins` to `sweep_angle < bayonet_pin_pattern_min_gap(...)`. For evenly spaced pins the smallest gap *is* `360/n`, so the rule is unchanged in the existing case.

### Notes

- Default behavior is unchanged: with `pin_angles` omitted, all five side-by-side examples render an identical facet multiset to 0.10.0 (`outer_3pin` 43276, `inner_2pin` 29112, `inner_3pin_thick_shell` 42926, `minimal` 28432, `outer_4pin_ccw` 57632). No shipped example was modified.
- `pin_angles` is appended after `shell_only` in the signature rather than placed beside `number_of_pins`, so positional callers are unaffected. The parameter table lists it next to `number_of_pins`, where it reads.

---

## [0.10.0] - 2026-08-08

### Added

- `shell_only` parameter on `bayonet`. When true, the pin and channel features are omitted and only the bare coupling shell is emitted, with the same shell radii and height as the real part. Intended for previewing composite assemblies, where the channel booleans dominate the cost but only the coupling envelope needs to be visible. The pin bosses are features and go with them, so a pin half previews `pin_radius` smaller in radius than it prints; the mode shows where the couplings sit, not how much room they need.
- A warning is echoed when `shell_only` is active outside `$preview`, since such a render emits a coupling with no locking features.
- `shell_only` falls back to the dynamically scoped `$bayonet_shell_only` special variable, then to `false`. This lets an assembly opt in once at its top level (`$bayonet_shell_only = $preview;`) instead of threading an argument through every intermediate module, and it reaches `bayonet()` calls buried inside consumer modules. An explicit `shell_only=` argument always wins over the special variable, and `let($bayonet_shell_only = ...)` scopes it to part of a tree. The library deliberately does not declare a file-scope default for the special variable, because a top-level assignment in a `use`d file shadows the consumer's value; the fallback uses `is_undef` instead.
- `examples/assembly_shell_only_preview.scad`, a four-coupling assembly wired to `$preview`, also showing a per-call override that keeps one joint fully detailed. The mode cuts that example's CSG tree from 752 nodes to 240; on a comparable eight-half assembly at `$fn = 64` the CGAL render drops from ~104 s to ~3.8 s.

### Changed

- All parameter validation still runs in `shell_only` mode, so a preview and a render validate identically and a passing preview cannot surprise the caller with an assertion at render time.

### Notes

- Default behavior is unchanged: with `shell_only` omitted and `$bayonet_shell_only` unset, the generated solid is geometrically identical to 0.9.1 (verified as an identical facet multiset). The emitted STL is no longer byte-for-byte identical, because the added branch introduces one inert `group()` node per call and CGAL's facet emission order follows the tree shape. No shipped example was modified.

---

## [0.9.1] - 2026-08-03

### Fixed

- The pin half's locking sphere is now placed at the lock's channel end rather than measured up from the pin's own base, so both halves are authored in one frame: instantiated at a common origin they are in the locked position. Previously the two only lined up when `entry_depth` equalled `part_height / 2`. Since that is the default the common case was unaffected, but callers who set `entry_depth` explicitly got a pin sitting at the wrong height in the channel, with no warning. At the default `entry_depth` the generated geometry is byte-for-byte unchanged.
- README: documented the mating convention, including how to place the halves at the entry position and the locked position.

---

## [0.9.0] - 2026-04-19

### Changed

- `entry_depth` is now optional in `bayonet`; when omitted, the lock entry shaft defaults to `part_height * 0.5`.
- Updated the shipped examples so the default-entry-depth behavior is exercised directly, while `outer_3pin.scad` remains as the explicit override example.
- README: documented the new `entry_depth` default, updated the usage block to show omission of optional parameters, and refreshed the example descriptions.

---

## [0.8.1] - 2026-04-19

### Fixed

- Restored the explicit `shell_thickness` validation in `bayonet` so user-supplied wall thicknesses must satisfy `pin_radius + allowance / 2 <= shell_thickness`, matching the actual `_channel_radius` used for lock-channel geometry.
- README: corrected the public API documentation to use `interface_radius`, documented `shell_thickness` as optional with its `pin_radius * 2` default, and added the refreshed example list including `inner_3pin_thick_shell.scad`.
- Cleaned up refreshed examples so their comments match the rendered geometry: `outer_3pin.scad` no longer refers to a removed neck, and `inner_3pin_thick_shell.scad` now describes its 3-pin thick-shell configuration accurately.

---

## [0.8.0] - 2026-04-19

### Breaking Changes

- `bayonet` now uses `interface_radius` as its primary radial input. Existing callers that pass `inner_radius` must be updated.
- `shell_thickness` is now optional. When omitted, it defaults to `pin_radius * 2`, which changes the generated shell radii relative to earlier releases that required an explicit wall thickness.
- Removed the public `bayonet_neck` helper from the library and from the documented examples.

### Changed

- Reworked the derived shell geometry around a single canonical `interface_radius`, with `_outer_radius` and `_internal_radius` now computed from that interface and the effective shell thickness.
- Simplified the pin-side and lock-side annulus derivation by computing the four shell radii directly from `pin_direction`.
- `_bayonet_channel` now uses a dedicated `_channel_radius` helper and shared signed-angle variables for the torus sweep and locking-notch placement.
- Refreshed the examples for the new API: renamed the baseline examples to `outer_3pin.scad` and `inner_2pin.scad`, kept `outer_4pin_ccw.scad` and `minimal.scad`, and added `inner_3pin_thick_shell.scad` to show an explicit thicker wall.
- README examples were revised to focus on the core `bayonet(...)` call without the removed neck helper.

---

## [0.7.1] - 2026-04-19

### Changed

- Changed `tube(h, r_outer, r_inner)` to be an internal helper `_tube(h, r_outer, r_inner)` to signal that it is not intended for public use. This is a minor API change but helps clarify the library's public interface and prevents accidental use of an internal module.

---

## [0.7.0] - 2026-04-18

### Added

- `assert(pin_radius > 0)` in `bayonet` module. Previously a zero pin_radius produced
  a degenerate sphere and silent zero-volume channel; the existing
  `shaft_radius <= shell_thickness` check did not catch it.

### Fixed

- `minimal.scad`: hardcoded `translate([29, 0, 0])` replaced with the computed
  expression `translate([(inner_radius + 2 * shell_thickness) * 2 + 5, 0, 0])`,
  consistent with all other example files.
- Removed stale `example_usage.scad` from repo root (v0.5.0 API, superseded by
  the `examples/` directory added in 0.5.1).

### Changed

- Inline comments on the two outer-direction `atan2` branches in `_bayonet_channel`
  now explicitly state that `allowance / 4` and `1.5 * allowance` are empirically
  tuned and give the validated parameter range (allowance ∈ [0.1, 0.4],
  pin_radius ∈ [0.5, 3.0]).
- README: updated features bullet to reference `shell_thickness` instead of the
  removed `outer_radius` parameter.

---

## [0.6.0] - 2026-04-18

### Breaking Changes

The `bayonet` module has a new signature. All named arguments must be updated.

| Old parameter                                 | New parameter               | Notes                                                                     |
| --------------------------------------------- | --------------------------- | ------------------------------------------------------------------------- |
| `part_to_render`                              | `half`                      | Same values: `"pin"` \| `"lock"`                                          |
| `outer_radius`                                | `shell_thickness`           | `shell_thickness = (outer_radius - inner_radius) / 2`                     |
| `path_sweep_angle`                            | `sweep_angle`               | Identical semantics                                                       |
| `channel_depth`                               | `entry_depth`               | Identical semantics                                                       |
| _(removed)_ `mid_in_radius`, `mid_out_radius` | _(internal)_ `_interface_r` | These were never intended as public params; now derived inside the module |

Parameter order has also changed to group geometry first, then count/angle, then mode flags.

### Changed

- Replaced `outer_radius` with `shell_thickness` (radial depth of each shell wall). The canonical mating surface is now `_interface_r = inner_radius + shell_thickness`, derived once inside the module. Previously callers had to know that `mid_radius = (inner_radius + outer_radius) / 2` was the operative surface.
- Renamed `part_to_render` → `half`, `path_sweep_angle` → `sweep_angle`, `channel_depth` → `entry_depth` for clarity.
- New validation asserts cover the rewritten constraints: `shell_thickness > 0`, `shaft_radius <= shell_thickness` (replaces `outer_radius > inner_radius`), `entry_depth > 0`, `entry_depth < part_height`, `sweep_angle` bounds.
- `_bayonet_channel` internal parameter `mid_in_radius`/`mid_out_radius` replaced by single canonical `interface_r` plus derived `pin_interface_r`.
- `lock_pos` inner-direction formula simplified: was `interface_radius - pin_radius - allowance/2`, now `interface_r - pin_radius` (the `allowance/2` offset cancels algebraically with the new derivation).
- atan2 denominators updated from `mid_in_radius + allowance/2` to `interface_r` (equivalent value, now expressed through the canonical reference).
- Example files updated: `outer_radius` variable replaced with `shell_thickness`, neck formula updated to `inner_radius + shell_thickness - allowance / 2`.
- README usage block and parameter table updated.

---

## [0.5.2] - 2026-04-18

### Fixed

- `rotate_extrude` pre-rotation was applied unconditionally, misaligning the torus arc for CCW locks. The `rotate([0,0,torus_angle])` wrapper is now conditional on `turn_direction == "CW"` only; CCW sweeps start at 0° and need no pre-rotation. This caused the channel arc to be offset from the entry shaft by exactly `path_sweep_angle` degrees for any CCW configuration.

---

## [0.5.1] - 2026-04-18

### Changed

- Replaced monolithic `example_usage.scad` with an `examples/` directory containing four focused, immediately-renderable files: `outer_3pin_with_neck.scad`, `inner_2pin_no_neck.scad`, `outer_4pin_ccw.scad`, and `minimal.scad`. Each renders both halves side-by-side and demonstrates a distinct combination of `pin_direction`, `number_of_pins`, `turn_direction`, and neck usage.
- README: replaced `example_usage.scad` reference with an examples table linking to each file.

---

## [0.5.0] - 2026-04-18

### Added

- 8 input range assertions in `bayonet`: `inner_radius > 0`, `outer_radius > inner_radius`, `pin_radius > 0`, `allowance >= 0`, `number_of_pins >= 1`, `channel_depth > 0`, `channel_depth < part_height`, `path_sweep_angle > 0`, and `path_sweep_angle < 360 / number_of_pins` (overlap guard).

### Fixed

- Removed `#` debug modifier from `tube`'s inner cylinder (caused bright-pink highlight in all previews and renders).
- Removed `color("Red")` from the channel cutout in the `bayonet` lock branch (same class of debug leak).
- `example_usage.scad`: `neck_outer_radius` now resolves to `mid_in_radius` when `pin_direction == "outer"`, matching the actual pin shell OD and eliminating the 2.6 mm neck/body step.
- `rotate_extrude` no longer receives a negative `angle`; a wrapping `rotate([0, 0, torus_angle])` pre-orients the sweep and `abs(torus_angle)` is passed to `rotate_extrude`, ensuring compatibility with OpenSCAD versions that require a positive angle argument.

### Changed

- `_bayonet_channel` signature: replaced `mid_radius` parameter with `mid_in_radius` and `mid_out_radius`; both call sites in `bayonet` now pass the already-computed values, eliminating the duplicate derivation inside the private module.
- Removed three redundant `assert` blocks from `_bayonet_channel`; all three parameters are already validated by the public `bayonet` module before the call.
- Added inline comments explaining the asymmetric angle-offset multipliers in `sweep_entry_angle` and `lock_notch_angle`, and the `allowance/2` radial correction asymmetry in `lock_pos`.

### Docs

- README: removed stale "two or four locking points" and FreeCAD detail-setting references; added Usage code block and full parameter reference table.

---

## [0.4.1] - 2026-04-18

### Added

- `tube(h, r_outer, r_inner)` primitive module encapsulating the repeated hollow-cylinder boolean pattern (outer shell minus triple-height centered bore). Used by `bayonet_neck`, and both pin/lock branches of `bayonet`, removing three instances of duplicated `difference()`/`cylinder` pairs.

---

## [0.4.0] - 2026-04-18

### Added

- `assert` guards on `part_to_render`, `pin_direction`, and `turn_direction` in `bayonet` and `_bayonet_channel` - invalid strings now produce a clear error instead of silent empty geometry.

### Changed

- `add_neck` renamed to `bayonet_neck` for consistent `bayonet_` public module prefix.
- `depth` parameter renamed to `channel_depth` across all modules and `example_usage.scad` for clarity (it is an axial Z-position, not a material depth).
- `bayonet_channel` renamed to `_bayonet_channel` (leading underscore signals internal/private by convention).
- Removed duplicate `pin_position` variable inside `_bayonet_channel`; replaced its sole use with the already-computed `interface_radius`.
- `lock_pos` computation replaced floating-point equality checks on derived radii with a direct `pin_direction` string comparison.
- `thorus_angle` typo corrected to `torus_angle`.
- `add_angle1` / `add_angle2` renamed to `sweep_entry_angle` / `lock_notch_angle`.
- All positional `cylinder(h, r, r)` calls converted to named-parameter form `cylinder(h=..., r=...)`.
- Removed unused `zFite` variable from `example_usage.scad`.

---

## [0.3.0] - 2026-04-18

### Changed

- Unified `inner_bayonet` and `outer_bayonet` into a single `bayonet` module. The existing `pin_direction` parameter controls shell assignment via four derived radius variables (`pin_ext_r`, `pin_int_r`, `lock_ext_r`, `lock_int_r`), removing ~130 lines of duplicate geometry code.
- Simplified `example_usage.scad` call site: the `if/else` branch dispatching to two module names is replaced by a single `bayonet(...)` call.

### Fixed

- `bayonet_channel` was called without the `part_height` argument inside the old `inner_bayonet`, causing `depth` to be assigned to the wrong positional slot and producing an `undef` translate warning.

---

## [0.2.0] - 2026-04-18

### Added

- `example_usage.scad`: all user settings and top-level render invocation moved here, leaving `bayonet_lock.scad` as a pure module library.

### Changed

- `bayonet_channel` now receives `part_height` and `depth` as explicit parameters instead of referencing top-level variables.
- Reorganized `bayonet_lock.scad` into labeled sections (global settings, user settings, derived values).
- Reduced z-fighting preview offset (`zFite`) from `0.1` to `0.05`.

### Fixed

- `$fn` preview/render selection was inverted (`$preview ? 128 : 64`); corrected to `$preview ? 64 : 128` so previews are fast and final renders are high-resolution.

---

## [0.1.0] - 2025-02-07

### Added

- Initial OpenSCAD library with four modules: `add_neck`, `inner_bayonet`, `outer_bayonet`, `bayonet_channel`.
- `manual_pin_radius` parameter with automatic fallback: `(outer_radius - inner_radius) / 4` when set to `0`.
- README with project description and source attribution links.

### Changed

- Tolerance variable renamed from `gap` to `allowance` throughout all module signatures and calculations.
- Default dimensions updated: `inner_radius 15→10`, `outer_radius 20→15`, `part_height 20→10`, `depth 8→5`.
- Tessellation control changed from `detail = 48` to preview-aware `$fn = $preview ? 64 : 128`.
