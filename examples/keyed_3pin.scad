// A keyed 3-pin coupling: one locked orientation instead of three.
// Cameron K. Brooks - MIT License

use <../bayonet_lock.scad>;

$fn = $preview ? 64 : 128;

interface_radius = 10;
pin_radius = 1;
allowance = 0.2;
sweep_angle = 30;
turn_direction = "CW";
part_height = 10;

// Evenly spaced pins repeat every 360/n, so an unkeyed 3-pin coupling mates in three
// orientations 120 degrees apart and nothing distinguishes them. Bringing one pin back by
// key_angle leaves a single seating. The offset has to clear the entry shaft's half-width or
// a wrong attempt still finds the mouth and starts to go in.
key_angle = 25;
pin_angles = bayonet_keyed_pin_angles(3, key_angle);

echo(
    str(
        "pins ", pin_angles,
        " | symmetry order ", bayonet_pin_pattern_order(pin_angles),
        " | keyed ", bayonet_pin_pattern_is_keyed(pin_angles),
        " | margin ", bayonet_pin_pattern_margin(pin_angles), " deg",
        " vs channel half-width ", bayonet_channel_half_angle(interface_radius, pin_radius, allowance), " deg"
    )
);

assert(
    bayonet_pin_pattern_is_keyed(pin_angles),
    "this example is about keying; the pattern has to be keyed"
);
assert(
    bayonet_pin_pattern_margin(pin_angles) > bayonet_channel_half_angle(interface_radius, pin_radius, allowance),
    "key_angle is too small to block a wrong seating"
);

module coupling(half) {
    bayonet(
        half=half,
        interface_radius=interface_radius,
        allowance=allowance,
        part_height=part_height,
        pin_angles=pin_angles,
        pin_radius=pin_radius,
        sweep_angle=sweep_angle,
        pin_direction="outer",
        turn_direction=turn_direction
    );
}

// Locked: the pin half turned from entry (the common origin) by the sweep.
coupling("lock");
rotate([0, 0, bayonet_locked_rotation(sweep_angle, turn_direction)]) coupling("pin");

// The seating that an unkeyed coupling would also have accepted. Turned 120 degrees the pins
// land 25 degrees off the mouths, so intersecting the halves here is non-empty - it does not
// go together. Keep it visible while tuning key_angle.
translate([interface_radius * 3, 0, 0]) {
    #intersection() {
        coupling("lock");
        rotate([0, 0, 120]) coupling("pin");
    }
    coupling("lock");
}
