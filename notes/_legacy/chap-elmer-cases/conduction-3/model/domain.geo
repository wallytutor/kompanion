// --------------------------------------------------------------------
// Parametric geometry of a 1-D multi-layer domain.
//
// Author: Walter Dal'Maz Silva
// Date  : Mar 16, 2025
// --------------------------------------------------------------------

General.BackgroundGradient = 0;
General.Color.Background = {200, 220, 240};
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

// Height of domain:
height = 100.0;

// Thickness of layers:
thick1 = 200.0;
thick2 = 50.0;
thick3 = 10.0;
thick4 = 40.0;

// Cells per meter on average:
rhox = 2000.0;
rhoy = 100.0;

// --------------------------------------------------------------------
// Computed coordinates
// --------------------------------------------------------------------

x0 = 0.0;
y0 = 0.0;

x1 = x0;
x2 = x1 + 0.001 * thick1;
x3 = x2 + 0.001 * thick2;
x4 = x3 + 0.001 * thick3;
x5 = x4 + 0.001 * thick4;

y1 = y0;
y2 = y1 + 0.001 * height;

// --------------------------------------------------------------------
// Computed discretization
// --------------------------------------------------------------------

n1 = 1 + rhox * (x2 - x1);
n2 = 1 + rhox * (x3 - x2);
n3 = 9 + rhox * (x4 - x3);
n4 = 9 + rhox * (x5 - x4);
ny = 1 + rhoy * (y2 - y1);

p1 = 1.0;
p2 = 1.0;
p3 = 1.0;
p4 = 1.0;

Printf("Number of cells in layer 1 : %4g (prog. %3.2f)", n1, p1);
Printf("Number of cells in layer 2 : %4g (prog. %3.2f)", n2, p2);
Printf("Number of cells in layer 3 : %4g (prog. %3.2f)", n3, p3);
Printf("Number of cells in layer 4 : %4g (prog. %3.2f)", n4, p4);
Printf("Number of vertical cells   : %4g (prog. %3.2f)", ny, 1.0);

// --------------------------------------------------------------------
// Points
// --------------------------------------------------------------------

Point(1)  = {x1, y1, 0};
Point(2)  = {x2, y1, 0};
Point(3)  = {x3, y1, 0};
Point(4)  = {x4, y1, 0};
Point(5)  = {x5, y1, 0};

Point(6)  = {x5, y2, 0};
Point(7)  = {x4, y2, 0};
Point(8)  = {x3, y2, 0};
Point(9)  = {x2, y2, 0};
Point(10) = {x1, y2, 0};

// --------------------------------------------------------------------
// Lines
// --------------------------------------------------------------------

Line(1) = {1, 2};
Line(2) = {2, 3};
Line(3) = {3, 4};
Line(4) = {4, 5};

Line(5) = {5, 6};
Line(6) = {7, 4};
Line(7) = {8, 3};
Line(8) = {9, 2};
Line(9) = {10, 1};

Line(10) = {6, 7};
Line(11) = {7, 8};
Line(12) = {8, 9};
Line(13) = {9, 10};

// --------------------------------------------------------------------
// Loops and surfaces
// --------------------------------------------------------------------

Curve Loop(1) = {1, -8, 13, 9};
Curve Loop(2) = {2, -7, 12, 8};
Curve Loop(3) = {3, -6, 11, 7};
Curve Loop(4) = {4,  5, 10, 6};

Plane Surface(1) = {1};
Plane Surface(2) = {2};
Plane Surface(3) = {3};
Plane Surface(4) = {4};

// --------------------------------------------------------------------
// Mesh structuring
// --------------------------------------------------------------------

Transfinite Curve{1, -13} = n1 Using Progression p1;
Transfinite Curve{2, -12} = n2 Using Progression p2;
Transfinite Curve{3, -11} = n3 Using Progression p3;
Transfinite Curve{4, -10} = n4 Using Progression p4;
Transfinite Curve{5, 6, 7, 8, 9} = ny;

Transfinite Surface {1};
Transfinite Surface {2};
Transfinite Surface {3};
Transfinite Surface {4};

Recombine Surface{1};
Recombine Surface{2};
Recombine Surface{3};
Recombine Surface{4};

// --------------------------------------------------------------------
// Physics
// --------------------------------------------------------------------

Physical Curve(1) = {9};
Physical Curve(2) = {5};
Physical Curve(3) = {1, 2, 3, 4};
Physical Curve(4) = {10, 11, 12, 13};

Physical Surface(1) = {1};
Physical Surface(2) = {2};
Physical Surface(3) = {3};
Physical Surface(4) = {4};

// --------------------------------------------------------------------
// Meshing
// --------------------------------------------------------------------

Mesh 2;
SetOrder 2;
Save "domain.msh";

// --------------------------------------------------------------------
// EOF
// --------------------------------------------------------------------