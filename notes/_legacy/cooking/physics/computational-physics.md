# Computational Physics

The goal of these notes are to keep track of molecular dynamics (MD) and density functional theory (DFT) studies, especially in what concerns applications to Materials Science. The [Materials Project](https://next-gen.materialsproject.org/) has many interesting for those working on MD and especially DFT. Theoretical basis can be found in the work by [Hinchliffe](https://www.wiley.com/en-us/Molecular+Modelling+for+Beginners%2C+2nd+Edition-p-9781119964810) which maybe will require some refreshing on the [The Feynman Lectures on Physics](https://www.feynmanlectures.caltech.edu/) to be followed.

## Molecular Dynamics (MD)

Since molecular dynamics is a field essentially related to simulation (there is no MD without simulation!), it is worth listing the major open source projects related to the field:

- [LAMMPS](https://www.lammps.org)
- [ESPReSo](https://espressomd.org/wordpress/)
- [Gromacs](https://www.gromacs.org/)

Other interesting projects include [HOOMD](http://glotzerlab.engin.umich.edu/hoomd-blue/) and the popular [NAMD](https://www.ks.uiuc.edu/Research/namd/); I have personally refrained from the last given its greedy licensing scheme. Focus here is given to LAMMPS because its broad fields of application and system portability.

## Density Functional Theory (DFT)

Non-exhaustive list of open source applications:

- [Abinit webpage](https://www.abinit.org/)
- [BigDFT](https://l_sim.gitlab.io/bigdft-doc/)
- [CP2K](https://www.cp2k.org/)
- [Dalton/LSDalton](https://daltonprogram.org/)
- [DFTK.jl](https://docs.dftk.org/stable/)
- [DIRAC](http://www.diracprogram.org/doku.php/)
- [FLEUR](https://www.flapw.de/MaX-6.0/)
- [Quantum Espresso](https://www.quantum-espresso.org/)
- [Siesta](https://siesta-project.org/siesta/)
- [Yambo](http://www.yambo-code.org/)

Furthermore, it is worth mentioning [Libxc - a library of exchange-correlation functionals for density-functional theory](https://libxc.gitlab.io/), as these functionals are portable and may be used from the selected tool for DFT here, [DFTK.jl](https://docs.dftk.org/stable/). It is chosen given its cross-system portability, relying only on Julia programming language, and partial GPU support.

- [Density Functional Theory - (Vincent Meunier)](https://www.youtube.com/playlist?list=PLDDCux6-RwmX5ffJedljH3gAbNdM8hvZz)

Things to learn:

- [ ] Types of DFT (plane wave, ...)
- [ ] Models (LDA, GGA, meta-GGA)

Review solid state physics concepts:

- [ ] Brillouin zones
- [ ] Bloch waves
