// The bare minimum: one bayonet() call per half, default shell and entry depth.
// Cameron K. Brooks - MIT License

use <../bayonet_lock.scad>;

$fn = $preview ? 64 : 128;

example_interface_radius = 8;

// Lock - rendered at origin
bayonet(
  half="lock",
  interface_radius=example_interface_radius,
  allowance=0.2,
  part_height=8,
  number_of_pins=2,
  pin_radius=1,
  sweep_angle=40,
  pin_direction="inner",
  turn_direction="CW"
);

// Pin - translated right for side-by-side comparison
translate([example_interface_radius * 3, 0, 0])
  bayonet(
    half="pin",
    interface_radius=example_interface_radius,
    allowance=0.2,
    part_height=8,
    number_of_pins=2,
    pin_radius=1,
    sweep_angle=40,
    pin_direction="inner",
    turn_direction="CW"
  );
