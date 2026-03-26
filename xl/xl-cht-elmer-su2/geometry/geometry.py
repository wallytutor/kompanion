# -*- coding: utf-8 -*-
""" Geometry for 1/12 of a honeycomb structure with circular holes. """
from majordome.simulation import GmshOCCModel
from majordome.simulation import GeometricProgression
import math

#region: parameters
NAME = "honeycomb_1_12"

# Height of the domain [m]
H = 0.05

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

# Number of layers in mesh extrusion:
NUM_LAYERS = 30

# 1/12 sector: 30-degree wedge (0° to 30°)
ANGLE = math.pi / 6
#endregion: parameters

#region: initialization
# Precompute trigonometric values for angle:
cos_theta = math.cos(ANGLE)
sin_theta = math.sin(ANGLE)
tan_theta = math.tan(ANGLE)

# Thickness of the solid region between hole and hex edge:
d = (L - 2 * R) / 2

# Distance from hole center to hex edge along symmetry line:
D = R + d

# Characteristic lengths for meshing:
min_len = min(HOLE_DR_INTERFACE, HOLE_DR_ORIGIN)
max_len = L / 10

# Options for configuring the model:
options = {
    "Mesh.CharacteristicLengthMin": min_len,
    "Mesh.CharacteristicLengthMax": max_len,
    "Mesh.SaveAll": None,
    "Mesh.SaveGroupsOfNodes": None,
    "Mesh.MeshSizeMax": max_len,
    "Mesh.Algorithm": 6,
    "Mesh.ElementOrder": 2,
    "Geometry.Points": False,
    "Geometry.Lines": True,
    "Geometry.Surfaces": True,
}
#endregion: initialization

with GmshOCCModel(name=NAME, render=True, **options) as model:
    #region: points
    # - Origin at hole center:
    p_origin   = model.add_point(0.0, 0.0, 0.0)

    # - Split arc endpoints:
    p_split_0  = model.add_point(r, 0.0, 0.0)
    p_split_30 = model.add_point(r * cos_theta, r * sin_theta, 0.0)

    # - Interface arc endpoints:
    p_inner_0  = model.add_point(R, 0.0, 0.0)
    p_inner_30 = model.add_point(R * cos_theta, R * sin_theta, 0.0)

    # - Outer wall endpoints (hex-like boundary in this 1/12 sector):
    p_outer_0  = model.add_point(D, 0.0, 0.0)
    p_outer_30 = model.add_point(D, D * tan_theta, 0.0)
    #endregion: points

    #region: curves
    # - Shared elements:
    split_arc     = model.add_circle_arc(p_split_0, p_origin, p_split_30)
    interface_arc = model.add_circle_arc(p_inner_0, p_origin, p_inner_30)
    outer_wall    = model.add_line(p_outer_0, p_outer_30)

    # - Fluid symmetry segments
    inner_sym_b   = model.add_line(p_origin, p_split_0)
    inner_sym_t   = model.add_line(p_origin, p_split_30)
    outer_sym_b   = model.add_line(p_split_0, p_inner_0)
    outer_sym_t   = model.add_line(p_split_30, p_inner_30)

    # - Solid symmetry segments
    solid_sym_b   = model.add_line(p_inner_0, p_outer_0)
    solid_sym_t   = model.add_line(p_inner_30, p_outer_30)
    #endregion: curves

    #region: surfaces
    # - Fluid inner: unstructured circular sector (0 <= r' <= r)
    items         = [inner_sym_b, split_arc, -inner_sym_t]
    inner_loop    = model.add_curve_loop(items)
    inner_surface = model.add_plane_surface([inner_loop])

    # - Fluid outer: transfinite annular sector (r <= r' <= R)
    items         = [outer_sym_b, interface_arc, -outer_sym_t, -split_arc]
    outer_loop    = model.add_curve_loop(items)
    outer_surface = model.add_plane_surface([outer_loop])

    # - Solid: annular wedge (R <= r' <= D)
    items         = [solid_sym_b, outer_wall, -solid_sym_t, -interface_arc]
    solid_loop    = model.add_curve_loop(items)
    solid_surface = model.add_plane_surface([solid_loop])
    #endregion: surfaces

    #region: meshing
    model.synchronize()

    # - Inner fluid region (r' < r): unstructured mesh around 0.002 m
    corners = [(0, p_origin), (0, p_split_0), (0, p_split_30)]
    model.set_size(corners, HOLE_DR_ORIGIN)
    model.set_recombine(2, inner_surface)

    # - Structured boundary-layer-like meshing on outer fluid ring
    n, q = GeometricProgression.fit(R-r, HOLE_DR_ORIGIN, HOLE_DR_INTERFACE)
    model.set_transfinite_curve(outer_sym_b, n+1, "Progression", q)
    model.set_transfinite_curve(outer_sym_t, n+1, "Progression", q)
    model.set_transfinite_curve(split_arc, HOLE_ARC_ELEMENTS + 1)
    model.set_transfinite_curve(interface_arc, HOLE_ARC_ELEMENTS + 1)

    corners = [p_split_0, p_inner_0, p_inner_30, p_split_30]
    model.set_transfinite_surface(outer_surface, cornerTags=corners)
    model.set_recombine(2, outer_surface)

    # - Structured meshing for solid (fine at interface -> coarse at outer wall)
    n, q = GeometricProgression.fit(d, HOLE_DR_INTERFACE, SOLID_DR_OUTER)
    model.set_transfinite_curve(solid_sym_b, n+1, "Progression", q)
    model.set_transfinite_curve(solid_sym_t, n+1, "Progression", q)
    model.set_transfinite_curve(outer_wall, HOLE_ARC_ELEMENTS + 1)

    corners = [p_inner_0, p_outer_0, p_outer_30, p_inner_30]
    model.set_transfinite_surface(solid_surface, cornerTags=corners)
    model.set_recombine(2, solid_surface)
    #endregion: meshing

    #region: transform
    def share_extrusion(who, layers=[NUM_LAYERS]):
        return model.extrude(who, 0, 0, H, numElements=layers, recombine=True)

    fluid_inner_base = [(2, inner_surface)]
    fluid_outer_base = [(2, outer_surface)]
    solid_base       = [(2, solid_surface)]

    ext_fluid_inner = share_extrusion(fluid_inner_base)
    ext_fluid_outer = share_extrusion(fluid_outer_base)
    ext_solid       = share_extrusion(solid_base)
    #endregion: transform

    #region: groups
    model.synchronize()

    # - Base elements are on inlet side
    # - First elements of the extrusion (mapping) are on the outlet side
    # - The second entry of extruded entities are the volumes:
    # - The remaining elements are counterclockwise from 0° to 30° planes
    all_surfaces = [
        {
            "tags": [fluid_inner_base[0][1], fluid_outer_base[0][1]],
            "tag_id": 1,
            "name": "fluid_inlet"
        },
        {
            "tags": [ext_fluid_inner[0][1], ext_fluid_outer[0][1]],
            "tag_id": 2,
            "name": "fluid_outlet"
        },
        {
            "tags": [solid_base[0][1]],
            "tag_id": 10,
            "name": "solid_inlet"
        },
        {
            "tags": [ext_solid[0][1]],
            "tag_id": 11,
            "name": "solid_outlet"
        },
        {
            "tags": [ext_fluid_inner[2][1], ext_fluid_outer[2][1]],
            "tag_id": 21,
            "name": "fluid_sym_main"
        },
        {
            "tags": [ext_fluid_inner[4][1], ext_fluid_outer[4][1]],
            "tag_id": 22,
            "name": "fluid_sym_slice"
        },
        {
            "tags": [ext_solid[2][1]],
            "tag_id": 23,
            "name": "solid_sym_main"
        },
        {
            "tags": [ext_solid[3][1]],
            "tag_id": 24,
            "name": "solid_sym_outer"
        },
        {
            "tags": [ext_solid[4][1]],
            "tag_id": 25,
            "name": "solid_sym_slice"
        }
    ]

    all_volumes = [
        {
            "tags": [ext_fluid_inner[1][1], ext_fluid_outer[1][1]],
            "tag_id": 100,
            "name": "fluid"
        },
        {
            "tags": [ext_solid[1][1]],
            "tag_id": 101,
            "name": "solid"
        }
    ]

    for surface in all_surfaces:
        model.add_physical_surface(**surface)

    for volume in all_volumes:
        model.add_physical_volume(**volume)
    #endregion: groups

    #region: generate
    model.synchronize()
    model.generate_mesh(dim=3)
    model.dump(f"{NAME}.msh", f"{NAME}.su2")
    #endregion: generate
