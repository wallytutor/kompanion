# Thermomechanical simulation

## Prepare case

```bash
gmsh - "domain/domain.geo"
```

```bash
ElmerGrid 14 2 "domain/domain.msh" -autoclean -merge 1.0e-05 -out "domain"
```

```bash
ElmerSolver > log.solver
```

```bash
ElmerGrid 2 2 domain/ -partdual -metiskway 8
ElmerGrid 2 2 domain/ -partdual -metisrec 8
ElmerGrid 2 2 domain/ -partition 4 2 1

mpiexec -n 8 ElmerSolver_mpi > log.solver
```

## Classification

#elmer/domain/cartesian
#elmer/domain/transient 
#elmer/models/heat-equation 
#elmer/models/stress-solver
