// --------------------------------------------------------------------
// Parametric geometry of a 2-D slab.
//
// Author: Walter Dal'Maz Silva
// Date  : May 13 2025
// --------------------------------------------------------------------

General.BackgroundGradient = 0;
General.Color.Background = {255, 255, 255};
General.Color.Foreground = White;
General.Color.Text = White;
General.Color.Axes = White;
General.Color.SmallAxes = White;
General.Axes = 0;
General.SmallAxes = 1;
Geometry.OldNewReg = 0;

// --------------------------------------------------------------------
// Parameters
// --------------------------------------------------------------------

// Refinement level:
LEVEL = 1;

// Slab HALF width:
width = 1.5;

// Slab FULL height:
height = 0.3;

// Cells per meter on average:
rho = 100.0;

// First and last cell sizes.
rx = 5;
ry = 5;

// --------------------------------------------------------------------
// Computed coordinates
// --------------------------------------------------------------------

// Origin of system:
x1 = 0.0;
y1 = 0.0;

// External wall:
x2 = x1 + width;

// Vertical coordinates:
y2 = y1 + height;

// --------------------------------------------------------------------
// Computed discretization
// --------------------------------------------------------------------

n1 = Round(LEVEL * rho * (x2 - x1));
n2 = Round(LEVEL * rho * (y2 - y1));

p1 = 1.0 * (1.0 / rx)^(1.0 / (n1/1 - 1));
p2 = 0.5 * (0.5 / ry)^(1.0 / (n2/2 - 1));

Printf("Number of cells in layer 1 : %4g (prog. %3.2f)", n1, p1);
Printf("Number of cells in layer 2 : %4g (prog. %3.2f)", n2, p2);

// --------------------------------------------------------------------
// Points
// --------------------------------------------------------------------

Point(1)  = {x1, y1, 0};
Point(2)  = {x2, y1, 0};
Point(3)  = {x2, y2, 0};
Point(4)  = {x1, y2, 0};

// --------------------------------------------------------------------
// Lines
// --------------------------------------------------------------------

Line(1) = {1, 2};
Line(2) = {2, 3};
Line(3) = {3, 4};
Line(4) = {4, 1};

// --------------------------------------------------------------------
// Loops and surfaces
// --------------------------------------------------------------------

Curve Loop(1) = {1, 2, 3, 4};
Plane Surface(1) = {1};

// --------------------------------------------------------------------
// Mesh structuring
// --------------------------------------------------------------------

Transfinite Curve{1, -3} = n1 Using Progression p1;
Transfinite Curve{2, -4} = n2 Using Bump p2;

Transfinite Surface {1};
Recombine Surface {1};

// --------------------------------------------------------------------
// Physics: boundary conditions
// --------------------------------------------------------------------

// Axis:
Physical Curve(1) = {4};

// Block-side:
Physical Curve(2) = {2};

// Block-top:
Physical Curve(3) = {3};

// Bottom of system:
Physical Curve(4) = {1};

// --------------------------------------------------------------------
// Physics: bodies
// --------------------------------------------------------------------

Physical Surface(1) = {1};

// --------------------------------------------------------------------
// Meshing
// --------------------------------------------------------------------

Mesh 2;

SetOrder 2;

Save "domain.msh";

// --------------------------------------------------------------------
// EOF
// --------------------------------------------------------------------