# -*- coding: utf-8 -*-
""" Geometry for 1/12 of a honeycomb structure with circular holes. """
from majordome.simulation import GmshOCCModel
from majordome.simulation import GeometricProgression
import math
import gmsh

#region: parameters
# Height of the domain [m]
H = 0.10

# Radius of the hole [m]
R = 0.03

# Distance between holes centers [m]
L = 0.10

# Radius splitting fluid in 2 parts [m]
r = R * 3/4

# Number of elements along the hole arc:
HOLE_ARC_ELEMENTS = 15

# First radial element inner arc [m]
# TODO compute based on r and HOLE_ARC_ELEMENTS
HOLE_DR_ORIGIN = 0.0010

# Last radial element at interface [m]
HOLE_DR_INTERFACE = 0.0002

# Target element size near outer wall [m]
SOLID_DR_OUTER = 0.0030

# 1/12 sector: 30-degree wedge (0° to 30°)
ANGLE = math.pi / 6
#endregion: parameters

#region: initialization
gmsh.initialize()
gmsh.model.add("honeycomb_1_12")

occ  = gmsh.model.occ
mesh = gmsh.model.mesh

add_point         = occ.addPoint
add_line          = occ.addLine
add_circle_arc    = occ.addCircleArc
add_curve_loop    = occ.addCurveLoop
add_plane_surface = occ.addPlaneSurface

set_size                = mesh.setSize
set_transfinite_curve   = mesh.setTransfiniteCurve
set_transfinite_surface = mesh.setTransfiniteSurface
set_recombine           = mesh.setRecombine

add_physical_group = gmsh.model.addPhysicalGroup

#endregion: initialization

#region: points
cos_theta = math.cos(ANGLE)
sin_theta = math.sin(ANGLE)
tan_theta = math.tan(ANGLE)

# Thickness of the solid region between hole and hex edge:
d = (L - 2 * R) / 2

# Distance from hole center to hex edge along symmetry line:
D = R + d

p_origin = add_point(0.0, 0.0, 0.0)

# Split arc endpoints:
p_split_0  = add_point(r, 0.0, 0.0)
p_split_30 = add_point(r * cos_theta, r * sin_theta, 0.0)

# Interface arc endpoints:
p_inner_0  = add_point(R, 0.0, 0.0)
p_inner_30 = add_point(R * cos_theta, R * sin_theta, 0.0)

# Outer wall endpoints (hex-like boundary in this 1/12 sector):
p_outer_0  = add_point(D, 0.0, 0.0)
p_outer_30 = add_point(D, D * tan_theta, 0.0)
#endregion: points

#region: curves
split_arc     = add_circle_arc(p_split_0, p_origin, p_split_30)
interface_arc = add_circle_arc(p_inner_0, p_origin, p_inner_30)
outer_wall    = add_line(p_outer_0, p_outer_30)

# Fluid symmetry segments
fluid_inner_sym_b = add_line(p_origin, p_split_0)
fluid_inner_sym_t = add_line(p_origin, p_split_30)
fluid_outer_sym_b = add_line(p_split_0, p_inner_0)
fluid_outer_sym_t = add_line(p_split_30, p_inner_30)

# Solid symmetry segments
solid_sym_b = add_line(p_inner_0, p_outer_0)
solid_sym_t = add_line(p_inner_30, p_outer_30)
#endregion: curves

#region: surfaces
# Fluid inner: unstructured circular sector (0 <= r' <= r)
fluid_inner_loop = add_curve_loop([
    fluid_inner_sym_b,
    split_arc,
    -fluid_inner_sym_t
])
fluid_inner_surface = add_plane_surface([fluid_inner_loop])

# Fluid outer: transfinite annular sector (r <= r' <= R)
fluid_outer_loop = add_curve_loop(
  [fluid_outer_sym_b, interface_arc, -fluid_outer_sym_t, -split_arc]
)
fluid_outer_surface = add_plane_surface([fluid_outer_loop])

# Solid: annular wedge (R <= r' <= D)
solid_loop = add_curve_loop([
    solid_sym_b,
    outer_wall,
    -solid_sym_t,
    -interface_arc
])
solid_surface = add_plane_surface([solid_loop])
#endregion: surfaces

#region: meshing
occ.synchronize()

# Inner fluid region (r' < r): unstructured mesh around 0.002 m
corners = [(0, p_origin), (0, p_split_0), (0, p_split_30)]
set_size(corners, HOLE_DR_ORIGIN)
set_recombine(2, fluid_inner_surface)

# Structured boundary-layer-like meshing on outer fluid ring
n, q = GeometricProgression.fit(R-r, HOLE_DR_ORIGIN, HOLE_DR_INTERFACE)
set_transfinite_curve(fluid_outer_sym_b, n+1, "Progression", q)
set_transfinite_curve(fluid_outer_sym_t, n+1, "Progression", q)
set_transfinite_curve(split_arc, HOLE_ARC_ELEMENTS + 1)
set_transfinite_curve(interface_arc, HOLE_ARC_ELEMENTS + 1)

corners = [p_split_0, p_inner_0, p_inner_30, p_split_30]
set_transfinite_surface(fluid_outer_surface, cornerTags=corners)
set_recombine(2, fluid_outer_surface)

# Structured meshing for solid (fine at interface -> coarse at outer wall)
n, q = GeometricProgression.fit(d, HOLE_DR_INTERFACE, SOLID_DR_OUTER)
set_transfinite_curve(solid_sym_b, n+1, "Progression", q)
set_transfinite_curve(solid_sym_t, n+1, "Progression", q)
set_transfinite_curve(outer_wall, HOLE_ARC_ELEMENTS + 1)

corners = [p_inner_0, p_outer_0, p_outer_30, p_inner_30]
set_transfinite_surface(solid_surface, cornerTags=corners)
set_recombine(2, solid_surface)
#endregion: meshing

#region: groups
region_fluid = [fluid_inner_surface, fluid_outer_surface]
region_solid = [solid_surface]

sym_fluid_lower = [fluid_inner_sym_b, fluid_outer_sym_b]
sym_fluid_upper = [fluid_inner_sym_t, fluid_outer_sym_t]
sym_solid_lower = [solid_sym_b]
sym_solid_upper = [solid_sym_t]
sym_solid_outer = [outer_wall]

add_physical_group(1, sym_fluid_lower, name="sym_fluid_lower")
add_physical_group(1, sym_fluid_upper, name="sym_fluid_upper")
add_physical_group(1, sym_solid_lower, name="sym_solid_lower")
add_physical_group(1, sym_solid_upper, name="sym_solid_upper")
add_physical_group(1, sym_solid_outer, name="sym_solid_outer")

add_physical_group(2, region_fluid, name="fluid")
add_physical_group(2, region_solid, name="solid")
#endregion: groups

#region: generate
min_len = min(HOLE_DR_INTERFACE, HOLE_DR_ORIGIN)
max_len = L / 5

gmsh.option.setNumber("Mesh.CharacteristicLengthMin", min_len)
gmsh.option.setNumber("Mesh.CharacteristicLengthMax", max_len)
gmsh.model.mesh.generate(2)
# gmsh.write("honeycomb_1_12.msh")
#endregion: generate

gmsh.fltk.run()
gmsh.finalize()
