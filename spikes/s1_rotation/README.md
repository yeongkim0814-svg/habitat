# S1 rotation and opposite district spike

## Choice: fixed habitat, rotating-frame forces (B)

Use a static habitat for gameplay and apply centrifugal acceleration
`-omega cross (omega cross p)` and Coriolis `-2 omega cross v` to free objects.
At R=1000m, omega=sqrt(9.81/R)=0.099045444 rad/s. There is no Euler term because
omega is constant. A radial constant 9.81 approximation alone is insufficient.
This avoids moving the whole environment and its future static colliders each
tick. This is a design choice based on equivalent trajectories and simpler
static geometry management, not a measured physics-performance win.

A is an inertial free particle with initial velocity `v_relative + omega cross p`;
the habitat and observer rotate about Z. B integrates rotating-frame forces with
RK4. Scene R toggles A/B: A actually rotates the habitat/observer; B holds them
fixed. Red is the A trajectory, green is B transformed to the displayed frame.
They represent the same single throw, not two interacting physical objects.
Both repeat after 3s before floor impact. No collision response or rigid-body
solver is modeled. The observer rotates with the habitat in A, so equivalent
views should remain the same. Renderer benchmarking is separate from this throw.

## Run and inspect

From repository root, with Godot 4.6.x:

```sh
godot --path . res://spikes/s1_rotation/main.tscn
```

R toggles actual rotation/fixed world; O toggles throw view/opposite district
view; L toggles distance detail. The opposite view looks inward along +Y from
the bottom at y=-998.3m toward buildings near y=+990m, roughly 2km away.
512 building boxes remain visible in both modes. Simplification hides the 512
rooftop detail boxes beyond 500m, preserving the opposite district silhouette.
All geometry uses basic meshes. Cylinder.segment() is preloaded unchanged from
the merged S2 implementation; project.godot and S2 files are not modified.

## Numeric verification

```sh
XDG_DATA_HOME=/tmp/s2-data XDG_CACHE_HOME=/tmp/s2-cache XDG_CONFIG_HOME=/tmp/s2-config godot --headless --path . --script tests/s1/run.gd
XDG_DATA_HOME=/tmp/s2-data XDG_CACHE_HOME=/tmp/s2-cache XDG_CONFIG_HOME=/tmp/s2-config godot --headless --path . res://spikes/s1_rotation/main.tscn --quit-after 180
```

Tests compare analytic inertial A converted into habitat coordinates against
independently integrated B at 60/120/240Hz over 3 seconds. The tolerance is 1cm
for float32 Vector3 accumulation, with a no-Coriolis control (>1m discrepancy).
This verifies free-flight transforms and signs, not contact stability.

## Rendering measurement: 미실행

Headless uses a dummy renderer: it cannot measure GPU work or displayed frames.
No visual inspection, screenshot, GPU frame time, or LOD speedup is claimed.
Run on a display/GPU with the same Godot build, renderer, resolution and hardware:

```sh
godot --path . --resolution 1280x720 res://spikes/s1_rotation/main.tscn -- --benchmark
```

The script disables VSync, fixes the opposite camera and simulation at t=0,
warms up 120 frames, then records 600 frame intervals without simplification;
it repeats warm-up/measurement with simplification. It prints mean and p95 frame
interval milliseconds and draw calls. These are end-to-end frame intervals, not
GPU timer measurements. Run at least five times, compare phase medians, and
record GPU/CPU, OS, resolution, renderer and VSync state. Check both modes using O/L
for silhouette continuity. Use Godot's visual profiler for separate CPU/GPU
timing if supported by the target renderer. Reverse the phase order in an
additional local experiment to check warm-cache/thermal bias. The headless
benchmark explicitly refuses to report frame times.

| Measure | State |
|---|---|
| A/B free-flight numeric equivalence | Headless test executable |
| Opposite buildings and controls scene load | Headless smoke executable |
| Full-detail mean/p95 displayed frame time | 미실행: no display/GPU render measurement |
| Simplified mean/p95 displayed frame time | 미실행: no display/GPU render measurement |
| Screenshot / visual comparison | 미실행: manual run instructions above |

Selection B is supported by the numerical equivalence; rendering cost remains
unresolved until the above GPU measurement. No frame-time budget is asserted.

## Touch controls and on-screen measurement (tablet, no keyboard)

The scene has four bottom buttons that mirror the keys: R (rotation/fixed),
O (overhead/throw), L (distance detail) and 측정 (on-screen benchmark). The top
label shows FPS and frame time. The 측정 button runs the same sequence as
`-- --benchmark` (120 warm-up + 600 measured frames, detail off then on,
VSync disabled where the platform allows it) and prints the result lines on
screen and to the console; the scene keeps running afterward. Keys and the
`-- --benchmark` command-line mode behave as before (the command-line mode
still quits when finished). The benchmark runs the overhead (opposite district)
view, so do not touch the buttons while it shows "[측정 중...]".

Checked here (not on a device): headless tests and scene load on Godot 4.6.3
and 4.7.2, and a software-rendered screenshot under Xvfb showing the four
buttons, the label and the opposite district. Touch input itself, button size on
the real screen and the FPS numbers are **미실행** (software rendering FPS is
meaningless); run on the tablet and report the on-screen result lines.

## Load multiplier and refresh rate (tablet limit finding)

The first tablet measurement (512 buildings, 8.75 ms mean) may be capped by the
display refresh (120 Hz = 8.33 ms), so it does not show headroom. The `부하` button
cycles the opposite-district building count 512 → 2048 → 8192 (x1/x4/x16; the 16
rows stay and each row gets more columns, so everything remains in the opposite
district). The label and every benchmark line now include `buildings`,
`refresh` (display refresh rate in Hz, `?` if the platform cannot report it) and
`vsync` (DisplayServer vsync mode: 0 = disabled, 1 = enabled, 2 = adaptive,
3 = mailbox). Run `측정` at each load and compare `mean_ms` with the refresh
period. Distance-simplification visibility is recomputed only when mode, view or
load changes, not every frame, so it does not add harness cost to frame timings.

Checked here: headless tests and scene load on Godot 4.6.3 and 4.7.2, a scripted
Xvfb run (counts 512/2048/8192, node count back to baseline after cycling, no
leak, button label, simplified visibility) and a screenshot of the x16 layout.
**미실행:** tablet frame times at x4/x16 and whether VSync is actually disabled on
Android.

## MultiMesh comparison and render CPU time (draw call finding)

The tablet measurement showed the opposite district is draw-call bound:
16,429 draw calls took 24.0 ms and 8,237 took 15.0 ms (8,192 buildings), while
512 and 2,048 buildings fit inside one 120 Hz refresh period (8.33 ms, VSync
was on, so frame times are rounded up to multiples of the refresh period). The
`MM` button switches the buildings from one `MeshInstance3D` per mesh to two
`MultiMeshInstance3D` (one for boxes, one for rooftop details). In MultiMesh
mode the distance simplification reorders the tower instances (near first) and
sets `visible_instance_count`, so it still hides far details.

The label and every benchmark line now show `mm`, `render_cpu` (the engine's
measured CPU time to submit the last frame, not rounded up to the refresh
period) and `gpu` (`?` when the renderer reports none). Benchmark lines carry
`render_cpu_mean_ms` and `draw_calls`.

Tablet run (x16, `측정` each time, 2 lines per run): MM off and MM on. Compare
`draw_calls`, `mean_ms` and `render_cpu_mean_ms`; `render_cpu_mean_ms` is the
number to compare when `mean_ms` is pinned to the refresh period.

Checked here: headless tests and scene load on Godot 4.6.3 and 4.7.2, and a
scripted Xvfb run (software rendering, 4.7.2): x16 nodes = 16,430 draw calls,
x16 MultiMesh = 48 draw calls with 2 MultiMesh nodes (8,192 instances each),
simplified view hides all rooftop instances at 2 km, switching back to nodes
restores 8,224 children with no leaked nodes, and the screenshot looks the same
as the node version. **미실행:** tablet frame times and render CPU time with
MultiMesh, and whether the Android renderer reports GPU time.
