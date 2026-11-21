// A printable canister with a bayonet lid.
// The lock half is the jar's rim and the pin half the cap's: push the cap down and turn it to
// lock. Laid out for printing, cap upside down beside the jar.
// Cameron K. Brooks - MIT License

use <../bayonet_lock.scad>;

/* [Canister] */
// Inside diameter of the jar
bore = 40; // [16:1:120]
// Inside depth of the jar below the coupling
depth = 50; // [10:1:200]
// Wall thickness of the jar and of both coupling halves
wall = 2.4; // [1.6:0.1:6]
// Thickness of the jar's floor and the cap's top
floor_thickness = 2; // [1:0.2:5]

/* [Coupling] */
// Number of pins, evenly spaced
number_of_pins = 3; // [2:6]
// Turn from entry to locked, in degrees
sweep_angle = 30; // [10:1:60]
// Direction the cap turns to lock
turn_direction = "CW"; // [CW, CCW]
// Radius of each pin
pin_radius = 1.2; // [0.6:0.1:2.5]
// Radial clearance between cap and jar; raise it if the cap binds
allowance = 0.3; // [0.1:0.05:0.8]
// Height of the coupling at the jar's rim
coupling_height = 10; // [6:0.5:20]

/* [View] */
view = "print"; // [print, assembled, cut away]

/* [Hidden] */
$fn = $preview ? 64 : 128;

// The jar's bore runs straight up through the lock half, so the lock's inside face is the bore.
interface_radius = bore / 2 - allowance / 2;
outer_radius = interface_radius + wall;
// The cap's top clears the rim by the allowance once the pins have seated.
cap_gap = allowance;
cap_height = coupling_height + cap_gap + floor_thickness;

module coupling(which) {
    bayonet(
        half=which,
        interface_radius=interface_radius,
        shell_thickness=wall,
        allowance=allowance,
        part_height=coupling_height,
        number_of_pins=number_of_pins,
        pin_radius=pin_radius,
        sweep_angle=sweep_angle,
        pin_direction="outer",
        turn_direction=turn_direction
    );
}

// The jar: a cup whose rim, from z = 0 up, is the lock half.
module jar() {
    coupling("lock");
    translate([0, 0, -depth - floor_thickness])
        difference() {
            cylinder(h=depth + floor_thickness, r=outer_radius);
            translate([0, 0, floor_thickness]) cylinder(h=depth + 1, r=bore / 2);
        }
}

// The cap, drawn at entry on the jar: its pin half drops inside the rim, its top sits above it.
module cap() {
    coupling("pin");
    // Carry the pin half's wall up through the gap to the top.
    translate([0, 0, coupling_height])
        difference() {
            cylinder(h=cap_gap + 0.01, r=interface_radius - allowance / 2);
            translate([0, 0, -1]) cylinder(h=cap_gap + 2, r=interface_radius - wall);
        }
    translate([0, 0, coupling_height + cap_gap]) cylinder(h=floor_thickness, r=outer_radius);
}

module assembled() {
    jar();
    rotate([0, 0, bayonet_locked_rotation(sweep_angle, turn_direction)]) cap();
}

if (view == "print") {
    translate([0, 0, depth + floor_thickness]) jar();
    translate([outer_radius * 2 + 10, 0, cap_height]) rotate([180, 0, 0]) cap();
} else if (view == "assembled") {
    assembled();
} else if (view == "cut away") {
    difference() {
        assembled();
        // Remove the half nearest the default camera, which looks along +y.
        translate([-outer_radius - 1, -outer_radius - 1, -depth - 10])
            cube([2 * outer_radius + 2, outer_radius + 1, depth + cap_height + 20]);
    }
}
