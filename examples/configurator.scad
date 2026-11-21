// Both halves of one coupling, with every parameter in the Customizer.
// Shows the lock and pin halves side by side, or the pin half locked into the lock.
// Cameron K. Brooks - MIT License

use <../bayonet_lock.scad>;

/* [Coupling] */
// Which way the pins point: outer pins point out, into a lock that surrounds them
pin_direction = "outer"; // [outer, inner]
// Direction the pin half turns to lock
turn_direction = "CW"; // [CW, CCW]
// Number of pins, evenly spaced
number_of_pins = 3; // [1:8]
// Arc each pin travels from entry to locked, in degrees
sweep_angle = 30; // [5:1:120]

/* [Size] */
// Radius of the mating surface between the halves
interface_radius = 10; // [4:0.5:60]
// Wall of each half; 0 uses the default, twice the pin radius
shell_thickness = 0; // [0:0.25:10]
// Radius of each pin
pin_radius = 1; // [0.5:0.25:5]
// Radial clearance between the halves
allowance = 0.2; // [0:0.05:1]
// Height of each half
part_height = 10; // [4:0.5:40]
// Depth the pins drop before turning; 0 uses the default, half the height
entry_depth = 0; // [0:0.5:39]

/* [View] */
// Side by side for printing, or the pin half turned into the locked position
layout = "side by side"; // [side by side, locked]

/* [Hidden] */
$fn = $preview ? 64 : 128;

max_sweep = bayonet_max_sweep_angle(number_of_pins, interface_radius, pin_radius, allowance);
echo(str("sweep_angle ", sweep_angle, " of at most ", max_sweep, " for this pin count and size"));

module half(which) {
    bayonet(
        half=which,
        interface_radius=interface_radius,
        shell_thickness=shell_thickness > 0 ? shell_thickness : undef,
        allowance=allowance,
        part_height=part_height,
        entry_depth=entry_depth > 0 ? entry_depth : undef,
        number_of_pins=number_of_pins,
        pin_radius=pin_radius,
        sweep_angle=sweep_angle,
        pin_direction=pin_direction,
        turn_direction=turn_direction
    );
}

half("lock");
if (layout == "locked")
    rotate([0, 0, bayonet_locked_rotation(sweep_angle, turn_direction)]) half("pin");
else
    translate([interface_radius * 3 + (shell_thickness > 0 ? shell_thickness : pin_radius * 2) * 2, 0, 0]) half("pin");
