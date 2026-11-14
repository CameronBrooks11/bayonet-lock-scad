// An assembly of several couplings that previews fast with shell_only.
// Cameron K. Brooks - MIT License
//
// The locking channel is a boolean-heavy cut, so an assembly holding several bayonets
// gets slow to pan long before it gets slow to render. Setting the dynamically scoped
// $bayonet_shell_only special variable once, at the top of the assembly, drops the
// pin/channel features from every bayonet() call below it - including calls buried
// inside your own modules - while leaving the coupling shells where they are.
//
// Wiring it to $preview gives the usual OpenSCAD workflow: F5 previews the assembly as
// bare shells, F6 renders the real geometry. Nothing else in the file changes.
//
// Try it: comment the line out and pan the preview to feel the difference.

use <../bayonet_lock.scad>;

$fn = $preview ? 64 : 128;

$bayonet_shell_only = $preview;

interface_radius = 10;
part_height = 10;
joint_count = 4;

// Shared parameters, so both halves of a joint mate.
module half(which) {
  bayonet(
    half=which,
    interface_radius=interface_radius,
    allowance=0.2,
    part_height=part_height,
    number_of_pins=3,
    pin_radius=1,
    sweep_angle=30,
    pin_direction="outer",
    turn_direction="CW"
  );
}

// A complete, locked coupling. At a common origin the halves are at entry, so the pin half is
// turned by the sweep to lock it.
// Note that half() never mentions shell_only: the special variable reaches it anyway,
// which is the whole point when bayonet() calls are buried inside your own modules.
module joint() {
  half("lock");
  rotate([0, 0, bayonet_locked_rotation(30, "CW")]) half("pin");
}

// Four couplings spaced along a rail - the kind of assembly that gets painful to pan.
for (i = [0:joint_count - 1])
  translate([i * interface_radius * 3, 0, 0])
    joint();

// A per-call override still wins over the special variable, so one joint can stay fully
// detailed for inspection while the rest of the assembly stays light during preview.
translate([0, interface_radius * 3, 0])
  bayonet(
    half="lock",
    interface_radius=interface_radius,
    allowance=0.2,
    part_height=part_height,
    number_of_pins=3,
    pin_radius=1,
    sweep_angle=30,
    pin_direction="outer",
    turn_direction="CW",
    shell_only=false
  );
