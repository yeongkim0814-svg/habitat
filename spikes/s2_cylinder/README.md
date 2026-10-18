# S2 cylinder spike

Godot 4.6.x. Open `project.godot` and run. WASD walks at 8 m/s,
mouse looks, Escape releases the cursor. Z is the cylinder axis; outward radial
direction is down, and inward is up. Eye height is 1.7 m. The minimal controller
constrains scalar angle/Z analytically to the cylinder; it does not test a
CharacterBody3D gravity/collision solver. No imported assets are needed.

`cylinder.gd` defines R=1000 m, L=200 m, N=32 modules. Each module has 256
angular subdivisions. Identical integer boundary indices make all seams close,
including the wrap seam. Faces and vertex normals point inward. Modules use
global vertices in this scene; origin shifting is measured as a separate numeric
experiment, not enabled in the interactive scene.

Run:

```sh
godot --headless --path . --script tests/s2/run.gd
godot --headless --path . --quit-after 3
```

The measurement samples 10,001 deterministic off-grid points around the entire
circumference and along the length for each radius. Scalar GDScript floats
provide a double reference; Vector3 storage performs the engine real_t rounding.
Global error is Euclidean distance from that reference. Shifted error stores
offsets from a module-center double anchor in Vector3, then reconstructs in
double scalars. Returning that result to a global Vector3 would lose the gain.
This compares coordinate representation errors, not accumulated movement drift.

Mesh chord sagitta is reported separately: R*(1-cos(pi/(N*STEPS))). Tests require
both the global and shifted sampled error plus sagitta below 1 mm, and check
actual generated arrays, shared seams, vertex normals and face winding. This
conservative sum includes geometry approximation; it is not a physics-contact
measurement. At 1 km, coarse 32-flat-panel geometry alone would miss by metres,
so internal tessellation matters more than float32 position storage here.

Conclusion scope: passing establishes a minimal scene and sub-mm representation
and tessellation budget at R=250/500/1000 m and L=200 m. Long-time integration,
physics contacts, rendering on a GPU, and longer axial distances need separate
experiments. No interactive visual run is claimed by the headless tests.
