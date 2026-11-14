// One coupling, set by the -D values below, and a CHECK that picks what to
// render. tests/test_bayonet.py drives it.
//   "pin" / "lock":  one half
//   "pair":          the lock against the pin half turned TURN degrees from
//                    entry and lifted LIFT; empty when they are clear
//   "functions":     echoes the helper functions' values
use <../bayonet_lock.scad>

CHECK = "pair";
TURN = 0;
LIFT = 0;
DIR = "outer";
TD = "CW";
N = 3;
ANGLES = [];  // non-empty: pin_angles instead of N evenly spaced
R = 10;
PR = 1;
ALLOW = 0.2;
SH = 2.5;
H = 10;
ED = 5;
SWEEP = 30;
SHELL_ONLY = false;
FN = 48;

module half(h)
  bayonet(half = h, interface_radius = R, shell_thickness = SH, allowance = ALLOW, part_height = H, entry_depth = ED,
          number_of_pins = len(ANGLES) > 0 ? undef : N, pin_angles = len(ANGLES) > 0 ? ANGLES : undef,
          pin_radius = PR, sweep_angle = SWEEP, pin_direction = DIR, turn_direction = TD, shell_only = SHELL_ONLY, $fn = FN);

if (CHECK == "pin") half("pin");
else if (CHECK == "lock") half("lock");
else if (CHECK == "pair") intersection() { half("lock"); translate([0, 0, LIFT]) rotate(TURN) half("pin"); }
else if (CHECK == "functions") {
  echo(str("F max_sweep_3 ", bayonet_max_sweep_angle(3, 10, 1, 0.2)));
  echo(str("F max_sweep_keyed ", bayonet_max_sweep_angle(bayonet_keyed_pin_angles(3, 25), 10, 1, 0.2)));
  echo(str("F locked_cw ", bayonet_locked_rotation(30, "CW")));
  echo(str("F locked_ccw ", bayonet_locked_rotation(30, "CCW")));
  echo(str("F half_angle ", bayonet_channel_half_angle(10, 1, 0.2)));
  echo(str("F keyed ", bayonet_keyed_pin_angles(3, 25), " order ", bayonet_pin_pattern_order(bayonet_keyed_pin_angles(3, 25)),
           " even order ", bayonet_pin_pattern_order([0, 120, 240])));
}
