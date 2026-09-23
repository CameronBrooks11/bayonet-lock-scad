// simple bayonet cylindrical locking mechanism
// Cameron K. Brooks
// MIT License
// version 0.11.1

// ----- pin pattern -----
// Evenly spaced pins give the coupling that spacing's rotational symmetry, so an n-pin
// coupling has n indistinguishable locked positions. That is fine when the halves carry
// nothing with an orientation, and wrong the moment one does - a keyed part seated one
// position out mates just as happily and points somewhere else. An explicit pin_angles list
// breaks the symmetry, the way a BA15d lamp cap offsets its two pins.

// Smallest absolute angle between two directions, in [0, 180].
function _bayonet_sep(a, b) = let (d = abs( (a - b) % 360 )) min(d, 360 - d);

// Is x one of the angles, to within eps?
function _bayonet_has(angles, x, eps) = len([for (a = angles) if (_bayonet_sep(a, x) < eps) 1]) > 0;

// Does rotating every pin by r reproduce the set?
function _bayonet_maps(angles, r, eps) =
  len([for (a = angles) if (_bayonet_has(angles, a + r, eps)) 1]) == len(angles);

/**
 * Smallest gap between adjacent pins, in degrees. The sweep has to fit inside this or
 * neighbouring channels run into each other.
 */
function bayonet_pin_pattern_min_gap(angles) =
  len(angles) < 2 ? 360
  : min([
      for (a = angles) min([for (b = angles) if (_bayonet_sep(a, b) > 1e-6) let (d = (b - a) % 360) d < 0 ? d + 360 : d]),
  ]);

/**
 * How many distinct rotations map the pin set onto itself. Evenly spaced pins give the pin
 * count; 1 means the coupling can only be seated one way.
 */
function bayonet_pin_pattern_order(angles, eps = 1e-6) =
  len([for (a = angles) if (_bayonet_maps(angles, a - angles[0], eps)) 1]);

/**
 * True when the pattern admits a single locked orientation. Ask this before hanging anything
 * with an orientation - a baffle, a tilted probe, a keyed connector - off a bayonet half.
 */
function bayonet_pin_pattern_is_keyed(angles) = bayonet_pin_pattern_order(angles) == 1;

/**
 * How far the worst-placed pin misses a channel mouth at the easiest wrong seating, in
 * degrees. Being keyed only says a wrong seating is not identical; this says whether it is
 * physically blocked, so compare it against bayonet_channel_half_angle().
 */
function bayonet_pin_pattern_margin(angles) =
  len(angles) < 2 ? 360
  : min([
      for (a = angles) if (_bayonet_sep(a, angles[0]) > 1e-6) let (r = a - angles[0])
          max([for (b = angles) min([for (c = angles) _bayonet_sep(b + r, c)])]),
  ]);

/**
 * Angular half-width of the entry shaft: how far a pin can sit from a mouth and still find it.
 */
function bayonet_channel_half_angle(interface_radius, pin_radius, allowance) =
  atan2(pin_radius + allowance / 2, interface_radius);

/**
 * Evenly spaced pins with the second one brought back by key_angle - the least disturbance
 * that leaves the pattern with no rotational symmetry. key_angle must clear
 * bayonet_channel_half_angle() for a wrong seating to actually be blocked.
 */
function bayonet_keyed_pin_angles(number_of_pins, key_angle) =
  [for (i = [0:number_of_pins - 1]) 360 / number_of_pins * i - (i == 1 ? key_angle : 0)];

module bayonet(
  half,
  interface_radius,
  shell_thickness = undef,
  allowance,
  part_height,
  entry_depth = undef,
  number_of_pins = undef,
  pin_radius,
  sweep_angle,
  pin_direction,
  turn_direction,
  shell_only = undef,
  pin_angles = undef
) {

  // Default the entry shaft to half the part height unless the caller overrides it.
  _entry_depth = is_undef(entry_depth) ? part_height * 0.5 : entry_depth;

  // Drop the pin/channel features and emit only the bare shell. Intended for previewing
  // assemblies, where the channel booleans dominate the cost but the coupling envelope is
  // all you need to see; the final render restores the real geometry.
  // Resolution order: explicit argument, then the dynamically scoped $bayonet_shell_only,
  // then false. The special variable lets an assembly opt in once at its top level
  // ($bayonet_shell_only = $preview;) rather than threading an argument through every
  // intermediate module. Deliberately not given a file-scope default here: a top-level
  // assignment in a use'd library shadows the consumer's value, so the fallback is is_undef.
  _shell_only = is_undef(shell_only)
    ? (is_undef($bayonet_shell_only) ? false : $bayonet_shell_only)
    : shell_only;

  // Where the pins sit around the circle. number_of_pins spaces them evenly; pin_angles gives
  // the positions outright, which is how a coupling is keyed to one locked orientation.
  _pin_angles = is_undef(pin_angles)
    ? [for (i = [0:number_of_pins - 1]) 360 / number_of_pins * i]
    : pin_angles;

  assert(
    is_undef(number_of_pins) != is_undef(pin_angles),
    "bayonet: give exactly one of number_of_pins or pin_angles"
  );
  assert(
    is_undef(pin_angles) || (is_list(pin_angles) && len(pin_angles) >= 1),
    str("bayonet: pin_angles must be a non-empty list of angles, got: ", pin_angles)
  );
  assert(
    is_undef(pin_angles) || len([for (a = pin_angles) if (!is_num(a)) 1]) == 0,
    str("bayonet: pin_angles must all be numbers, got: ", pin_angles)
  );

  assert(
    half == "pin" || half == "lock",
    str("bayonet: half must be \"pin\" or \"lock\", got: ", half)
  );
  assert(
    pin_direction == "inner" || pin_direction == "outer",
    str("bayonet: pin_direction must be \"inner\" or \"outer\", got: ", pin_direction)
  );
  assert(
    turn_direction == "CW" || turn_direction == "CCW",
    str("bayonet: turn_direction must be \"CW\" or \"CCW\", got: ", turn_direction)
  );
  assert(
    interface_radius > 0,
    str("bayonet: interface_radius must be > 0, got: ", interface_radius)
  );
  assert(
    allowance >= 0,
    str("bayonet: allowance must be >= 0, got: ", allowance)
  );
  assert(
    pin_radius > 0,
    str("bayonet: pin_radius must be > 0, got: ", pin_radius)
  );
  assert(
    (is_undef(shell_thickness) ? true : (pin_radius + allowance / 2 <= shell_thickness)),
    str(
      "bayonet: shell_thickness must be >= pin_radius + allowance/2 (",
      pin_radius + allowance / 2,
      "), got: ",
      shell_thickness
    )
  );
  assert(
    is_undef(number_of_pins) || number_of_pins >= 1,
    str("bayonet: number_of_pins must be >= 1, got: ", number_of_pins)
  );
  assert(
    _entry_depth > 0,
    str("bayonet: entry_depth must be > 0, got: ", _entry_depth)
  );
  assert(
    _entry_depth < part_height,
    str("bayonet: entry_depth (", _entry_depth, ") must be < part_height (", part_height, ")")
  );
  assert(
    sweep_angle > 0,
    str("bayonet: sweep_angle must be > 0, got: ", sweep_angle)
  );
  // Generalises the old sweep < 360/number_of_pins: with the pins spaced evenly that gap is
  // 360/n, and with them keyed it is whichever pair sits closest.
  assert(
    sweep_angle < bayonet_pin_pattern_min_gap(_pin_angles),
    str(
      "bayonet: sweep_angle (", sweep_angle, ") must be < the smallest gap between pins (",
      bayonet_pin_pattern_min_gap(_pin_angles), ") to avoid channel overlap"
    )
  );
  assert(
    is_bool(_shell_only),
    str("bayonet: shell_only must be true or false, got: ", _shell_only)
  );

  // Canonical mating surface and derived geometry.
  _shell_thickness = is_undef(shell_thickness) ? pin_radius * 2 : shell_thickness;
  _outer_radius = interface_radius + _shell_thickness;
  _internal_radius = interface_radius - _shell_thickness;
  _channel_z = part_height - _entry_depth;

  // Determine which annular shell carries the pin vs the channel/lock.
  // For pin_direction=="inner": pin on outer shell, channel on inner shell.
  // For pin_direction=="outer": pin on inner shell, channel on outer shell.
  pin_direction_inner = (pin_direction == "inner");
  pin_ext_r = pin_direction_inner ? _outer_radius : interface_radius - (allowance / 2);
  pin_int_r = pin_direction_inner ? interface_radius + (allowance / 2) : _internal_radius;

  lock_ext_r = pin_direction_inner ? interface_radius - (allowance / 2) : _outer_radius;
  lock_int_r = pin_direction_inner ? _internal_radius : interface_radius + (allowance / 2);

  // A shell_only part exported as a mesh would silently ship a coupling that cannot lock.
  if (_shell_only && !$preview)
    echo("WARNING: bayonet: shell_only active in a render - the emitted part has no locking features");

  if (_shell_only) {
    // Bare coupling shell: same shell radii and height as the real part. The pin bosses are
    // features, so a pin half previews pin_radius smaller in radius than it prints.
    _tube(
      h=part_height,
      r_outer=(half == "pin") ? pin_ext_r : lock_ext_r,
      r_inner=(half == "pin") ? pin_int_r : lock_int_r
    );
  } else if (half == "pin") {
    _bayonet_channel(
      half,
      pin_direction,
      _pin_angles,
      sweep_angle,
      turn_direction,
      interface_radius,
      pin_radius,
      allowance,
      part_height,
      _channel_z
    );
    // pin-bearing shell body
    _tube(
      h=part_height,
      r_outer=pin_ext_r,
      r_inner=pin_int_r
    );
  } else {
    difference() {
      // channel-bearing shell body
      _tube(
        h=part_height,
        r_outer=lock_ext_r,
        r_inner=lock_int_r
      );
      // cut out the locking channel
      _bayonet_channel(
        half,
        pin_direction,
        _pin_angles,
        sweep_angle,
        turn_direction,
        interface_radius,
        pin_radius,
        allowance,
        part_height,
        _channel_z
      );
    }
  }
}

module _bayonet_channel(
  half,
  pin_direction,
  pin_angles,
  sweep_angle,
  turn_direction,
  interface_r,
  pin_radius,
  allowance,
  part_height,
  channel_depth
) {

  _channel_radius = pin_radius + allowance / 2;

  // Radial position of pin centre: +/- allowance/2 from the canonical mating surface.
  pin_interface_r =
    (pin_direction == "outer") ? interface_r - allowance / 2
    : interface_r + allowance / 2;

  for (angle = pin_angles) {
    rotate([0, 0, angle]) {
      if (half == "lock") {
        difference() {
          union() {
            // vertical entry shaft
            translate([pin_interface_r, 0, channel_depth]) {
              cylinder(h=part_height - channel_depth + _channel_radius, r=_channel_radius);
            }
            // Rounded entry transition. The whole sphere, not a hemisphere: its upper half is
            // already inside the entry shaft unioned above, so cutting it away changes nothing
            // about the solid and costs something. The cutting plane passed through the sphere's
            // centre, which is also the torus's cross-section centre and the shaft's base - three
            // surfaces meeting on one circle - and CGAL leaves that contact as coincident faces.
            translate([pin_interface_r, 0, channel_depth]) {
              sphere(_channel_radius);
            }
            // curved sweep path
            // Angular correction so the torus cross-section meets the entry shaft tangentially.
            // Inner: numerator = _channel_radius - allowance/2, derived from the pin/torus tangent geometry.
            // Outer: coefficient allowance/4 is empirically tuned; the outer-direction interface offset
            // shifts the tangent point differently and a closed-form derivation has not been done.
            // Validated for allowance ∈ [0.1, 0.4] and pin_radius ∈ [0.5, 3.0].
            sweep_entry_angle =
              (pin_direction == "inner") ? atan2(_channel_radius - allowance / 2, interface_r)
              : atan2(_channel_radius - allowance / 4, interface_r);

            torus_angle = sweep_angle + sweep_entry_angle;
            torus_angle_signed =
              (turn_direction == "CW") ?
                -torus_angle
              : torus_angle;

            // Pre-rotate only for CW: torus_angle_signed is negative, so rotating by it places
            // the profile start at torus_angle_signed°; sweeping abs(torus_angle_signed) CCW returns to 0°
            // (the entry shaft). For CCW no pre-rotation needed - sweep runs 0° to torus_angle_signed°.
            translate([0, 0, channel_depth]) {
              rotate([0, 0, (turn_direction == "CW") ? torus_angle_signed : 0])
                rotate_extrude(angle=abs(torus_angle_signed), convexity=10) {
                  translate([pin_interface_r, 0, 0]) {
                    circle(r=_channel_radius);
                  }
                }
            }
          }

          // locking notch cutout
          // Inner: notch at interface_r - pin_radius (symmetric about interface_r).
          // Outer: notch at interface_r - allowance/2 + pin_radius (pin centre sits allowance/2 inside interface_r).
          lock_pos =
            (pin_direction == "inner") ?
              interface_r - pin_radius
            : interface_r + pin_radius - allowance / 2;

          // Same atan2 geometry as sweep_entry_angle; places the notch under the pin at end-of-travel.
          // Inner: same derivation as sweep_entry_angle.
          // Outer: coefficient 1.5*allowance is empirically tuned; same caveat and validated range
          // as sweep_entry_angle outer (allowance ∈ [0.1, 0.4], pin_radius ∈ [0.5, 3.0]).
          lock_notch_angle =
            (pin_direction == "inner") ?
              atan2(_channel_radius - allowance / 2, interface_r)
            : atan2(_channel_radius - 1.5 * allowance, interface_r);

          lock_angle = sweep_angle - lock_notch_angle;
          lock_angle_signed =
            (turn_direction == "CW") ?
              -lock_angle
            : lock_angle;

          x = cos(lock_angle_signed) * lock_pos;
          y = sin(lock_angle_signed) * lock_pos;
          z = channel_depth - _channel_radius;

          translate([x, y, z]) {
            cylinder(h=2 * _channel_radius, r=allowance);
          }
        }
      } else if (half == "pin") {
        // Locking pin sphere, at the same height as the lock's channel end so that the two
        // halves are authored in one frame: placed at a common origin they are locked
        // together. Measuring from the pin's own base instead would only line up when
        // entry_depth happens to equal part_height / 2.
        translate([pin_interface_r, 0, channel_depth]) {
          sphere(pin_radius);
        }
      }
    }
  }
}

// Hollow cylindrical tube primitive consisting of an outer shell minus thru-bore.
// The bore is triple-height and centered to avoid z-fighting on both faces.
module _tube(h, r_outer, r_inner) {
  difference() {

    cylinder(h=h, r=r_outer);

    if (r_inner > 0)
      cylinder(h=h * 3, r=r_inner, center=true);
  }
}
