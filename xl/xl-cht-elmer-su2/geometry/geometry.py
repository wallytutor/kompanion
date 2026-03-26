# -*- coding: utf-8 -*-
""" Geometry for 1/12 of a honeycomb structure with circular holes. """
from majordome.simulation import GmshOCCModel
from majordome.simulation import GeometricProgression
from math import cos, sin, tan, pi as PI

#region: parameters
NAME = "honeycomb_1_12"

# Height of the domain [m]
H = 0.05

# Radius of the hole [m]
R = 0.030

# Distance between holes centers [m]
L = 0.10

# XXX: experimental, make a hole in the middle!
HOLED = True

# Radius splitting fluid in 2 parts [m]
r = 0.75 * R if not HOLED else 0.05 * R

# Number of elements along the hole arc:
HOLE_ARC_ELEMENTS = 10

# Mid-fluid characteristic length [m]
DR_MIDDLE = R / 15

# First radial element inner arc [m]
# TODO compute based on r and HOLE_ARC_ELEMENTS
DR_ORIGIN = 0.001

# Last radial element at interface [m]
DR_INTERFACE = 0.0001

# Target element size near outer wall [m]
DR_OUTER = 0.0010

# Number of layers in mesh extrusion:
NUM_LAYERS = 50

# 1/12 sector: 30-degree wedge (0° to 30°)
ANGLE = PI / 6

# Options for configuring the model:
options = {
    "Mesh.CharacteristicLengthMin": DR_INTERFACE / 2,
    "Mesh.CharacteristicLengthMax": L / 10,
    "Mesh.SaveAll": False,
    "Mesh.SaveGroupsOfNodes": True,
    "Mesh.MeshSizeMax": L / 10,
    "Mesh.Algorithm": 6,
    "Mesh.ElementOrder": 1,
    "Geometry.Points": False,
    "Geometry.Lines": True,
    "Geometry.Surfaces": True,
}
#endregion: parameters


def extrude(model, what, layers=[NUM_LAYERS]):
    return model.extrude(what, 0, 0, H, numElements=layers, recombine=True)


def add_physical_groups(model, all_surfaces, all_volumes):
    for surface in all_surfaces:
        model.add_physical_surface(**surface)

    for volume in all_volumes:
        model.add_physical_volume(**volume)


def cht_arc(model):
    # - Origin at hole center:
    p_origin   = model.add_point(0.0, 0.0, 0.0)

    # - Interface arc:
    p_inner_0  = model.add_point(R, 0.0, 0.0)
    p_inner_30 = model.add_point(R * cos(ANGLE), R * sin(ANGLE), 0.0)
    interface_arc = model.add_circle_arc(p_inner_0, p_origin, p_inner_30)

    return p_origin, p_inner_0, p_inner_30, interface_arc


def fluid_model(model, p_origin, p_inner_0, p_inner_30, interface_arc):
    #region: base
    # - Split arc:
    p_split_0     = model.add_point(r, 0.0, 0.0)
    p_split_30    = model.add_point(r * cos(ANGLE), r * sin(ANGLE), 0.0)
    split_arc     = model.add_circle_arc(p_split_0, p_origin, p_split_30)

    # - Fluid symmetry segments
    inner_sym_b   = model.add_line(p_origin, p_split_0)
    inner_sym_t   = model.add_line(p_origin, p_split_30)
    outer_sym_b   = model.add_line(p_split_0, p_inner_0)
    outer_sym_t   = model.add_line(p_split_30, p_inner_30)

    # - Fluid outer: transfinite annular sector (r <= r' <= R)
    items         = [outer_sym_b, interface_arc, -outer_sym_t, -split_arc]
    outer_loop    = model.add_curve_loop(items)
    outer_surface = model.add_plane_surface([outer_loop])
    #endregion: base
    model.synchronize()

    #region: meshing
    # - Structured boundary-layer-like meshing on outer fluid ring
    if HOLED:
        n, q = GeometricProgression.fit_bump(R-r, DR_INTERFACE, DR_MIDDLE)
        method = "Bump"
    else:
        n, q = GeometricProgression.fit_bump(R-r, DR_INTERFACE, DR_ORIGIN)
        method = "Progression"

    model.set_transfinite_curve(outer_sym_b, n+1, method, q)
    model.set_transfinite_curve(outer_sym_t, n+1, method, q)
    model.set_transfinite_curve(split_arc, HOLE_ARC_ELEMENTS + 1)
    model.set_transfinite_curve(interface_arc, HOLE_ARC_ELEMENTS + 1)

    corners = [p_split_0, p_inner_0, p_inner_30, p_split_30]
    model.set_transfinite_surface(outer_surface, cornerTags=corners)
    model.set_recombine(2, outer_surface)
    #endregion: meshing
    model.synchronize()

    #region: transform
    fluid_outer_base = [(2, outer_surface)]
    ext_fluid_outer = extrude(model, fluid_outer_base)
    #endregion: transform
    model.synchronize()

    #region: physical_groups
    fluid               = [ext_fluid_outer[1][1]]
    fluid_inlet         = [fluid_outer_base[0][1]]
    fluid_outlet        = [ext_fluid_outer[0][1]]
    ext_fluid_sym_main  = [ext_fluid_outer[2][1]]
    ext_fluid_sym_slice = [ext_fluid_outer[4][1]]
    cht_fluid_solid     = [ext_fluid_outer[3][1]]

    if HOLED:
        hole_wall = {
            "tags": [ext_fluid_outer[5][1]],
            "tag_id": 49,
            "name": "hole_wall"
        }
    else:
        hole_wall = {}

        # - Fluid inner: unstructured circular sector (0 <= r' <= r)
        items         = [inner_sym_b, split_arc, -inner_sym_t]
        inner_loop    = model.add_curve_loop(items)
        inner_surface = model.add_plane_surface([inner_loop])
        model.synchronize()

        # - Inner fluid region (r' < r): unstructured mesh around 0.002 m
        corners = [(0, p_origin), (0, p_split_0), (0, p_split_30)]
        model.set_size(corners, DR_ORIGIN)
        model.set_recombine(2, inner_surface)
        model.synchronize()

        # - Extrude inner fluid to create volume
        fluid_inner_base = [(2, inner_surface)]
        ext_fluid_inner = extrude(model, fluid_inner_base)
        model.synchronize()

        fluid               += [ext_fluid_inner[1][1]]
        fluid_inlet         += [fluid_inner_base[0][1]]
        fluid_outlet        += [ext_fluid_inner[0][1]]
        ext_fluid_sym_main  += [ext_fluid_inner[2][1]]
        ext_fluid_sym_slice += [ext_fluid_inner[4][1]]

    tags_fluid_volumes = [{"tags": fluid, "tag_id": 100, "name": "fluid"}]
    tags_fluid_surfaces = [
        {"tags": fluid_inlet,         "tag_id": 1,  "name": "fluid_inlet"},
        {"tags": fluid_outlet,        "tag_id": 2,  "name": "fluid_outlet"},
        {"tags": ext_fluid_sym_main,  "tag_id": 21, "name": "fluid_sym_main"},
        {"tags": ext_fluid_sym_slice, "tag_id": 22, "name": "fluid_sym_slice"},
        {"tags": cht_fluid_solid,     "tag_id": 50, "name": "cht_fluid_solid"}
    ]

    if hole_wall:
        tags_fluid_surfaces.append(hole_wall)

    add_physical_groups(model, tags_fluid_surfaces, tags_fluid_volumes)
    #endregion: physical_groups


def solid_model(model, p_origin, p_inner_0, p_inner_30, interface_arc):
    #region: base
    # Thickness of the solid region between hole and hex edge:
    d = (L - 2 * R) / 2

    # Distance from hole center to hex edge along symmetry line:
    D = L / 2

    # - Outer wall endpoints (hex-like boundary in this 1/12 sector):
    p_outer_0   = model.add_point(D, 0.0, 0.0)
    p_outer_30  = model.add_point(D, D * tan(ANGLE), 0.0)

    # - Solid symmetry segments
    solid_sym_b = model.add_line(p_inner_0, p_outer_0)
    solid_sym_t = model.add_line(p_inner_30, p_outer_30)
    outer_wall  = model.add_line(p_outer_0, p_outer_30)

    # - Solid: annular wedge (R <= r' <= D)
    items         = [solid_sym_b, outer_wall, -solid_sym_t, -interface_arc]
    solid_loop    = model.add_curve_loop(items)
    solid_surface = model.add_plane_surface([solid_loop])
    #endregion: base
    model.synchronize()

    #region: meshing
    # - Structured meshing for solid (fine at interface -> coarse at outer wall)
    n, q = GeometricProgression.fit(d, DR_INTERFACE, DR_OUTER)
    model.set_transfinite_curve(solid_sym_b, n+1, "Progression", q)
    model.set_transfinite_curve(solid_sym_t, n+1, "Progression", q)
    model.set_transfinite_curve(outer_wall, HOLE_ARC_ELEMENTS + 1)
    model.set_transfinite_curve(interface_arc, HOLE_ARC_ELEMENTS + 1)

    corners = [p_inner_0, p_outer_0, p_outer_30, p_inner_30]
    model.set_transfinite_surface(solid_surface, cornerTags=corners)
    model.set_recombine(2, solid_surface)
    #endregion: meshing
    model.synchronize()

    #region: transform
    solid_base       = [(2, solid_surface)]
    ext_solid       = extrude(model, solid_base)
    #endregion: transform
    model.synchronize()

    #region: physical_groups
    tags_solid_volumes = [
        {
            "tags": [ext_solid[1][1]],
            "tag_id": 101,
            "name": "solid"
        },
    ]
    tags_solid_surfaces = [
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
        },
        {
            "tags": [ext_solid[5][1]],
            "tag_id": 51,
            "name": "cht_solid_fluid"
        }
    ]

    add_physical_groups(model, tags_solid_surfaces, tags_solid_volumes)
    #endregion: physical_groups


render = not False

with GmshOCCModel(name=NAME, render=render, **options) as model:
    p_origin, p_inner_0, p_inner_30, interface_arc = cht_arc(model)
    fluid_model(model, p_origin, p_inner_0, p_inner_30, interface_arc)
    model.synchronize()
    model.generate_mesh(dim=3)
    model.dump(f"../model-su2/{NAME}_fluid.su2")

with GmshOCCModel(name=NAME, render=render, **options) as model:
    p_origin, p_inner_0, p_inner_30, interface_arc = cht_arc(model)
    solid_model(model, p_origin, p_inner_0, p_inner_30, interface_arc)
    model.synchronize()
    model.generate_mesh(dim=3)
    model.dump(f"../model-su2/{NAME}_solid.su2")

# XXX: only for Elmer, otherwise NPOIN is wrong in SU2 mesh!
options["Mesh.ElementOrder"] = 2

with GmshOCCModel(name=NAME, render=render, **options) as model:
    p_origin, p_inner_0, p_inner_30, interface_arc = cht_arc(model)
    fluid_model(model, p_origin, p_inner_0, p_inner_30, interface_arc)
    solid_model(model, p_origin, p_inner_0, p_inner_30, interface_arc)
    model.synchronize()
    model.generate_mesh(dim=3)
    model.dump(f"{NAME}_elmer.msh")
