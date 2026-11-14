// The README pictures; `just images` renders each VIEW.
use <../bayonet_lock.scad>

VIEW = "halves"; // [halves, locked_cutaway]
R = 10; SWEEP = 30; TD = "CW";

module half(h) bayonet(half = h, interface_radius = R, shell_thickness = 2.5, allowance = 0.2, part_height = 10,
                       entry_depth = 6, number_of_pins = 3, pin_radius = 1.2, sweep_angle = SWEEP,
                       pin_direction = "outer", turn_direction = TD, $fn = 96);

if (VIEW == "halves") {
  color("SteelBlue") half("lock");
  translate([3 * R, 0, 0]) color("Orange") half("pin");
}
if (VIEW == "locked_cutaway")
  difference() {
    union() {
      color("SteelBlue") half("lock");
      color("Orange") rotate(bayonet_locked_rotation(SWEEP, TD)) half("pin");
    }
    // Cut on the plane through a locked pin, so the section shows it seated in its channel.
    rotate(bayonet_locked_rotation(SWEEP, TD)) translate([-2 * R, -4 * R, -1]) cube([4 * R, 4 * R, 12]);
  }
