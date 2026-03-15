# Elmer Multiphysics

Elmer is a multiphysics finite element method (FEM) solver mainly developed by CSC and maintained at [GitHub](https://github.com/ElmerCSC/elmerfem). Several resources can be found in is [official webpage](https://www.research.csc.fi/web/elmer) and in the [community portal](https://www.elmerfem.org/blog/) and in the [forum](https://www.elmerfem.org/forum/index.php). There is also an [YouTube channel](https://www.youtube.com/@elmerfem) with several tutorials and illustration of the package capabilities.

The goal of this page is not to supersede the [documentation](https://www.research.csc.fi/web/elmer/documentation), but to make it (partially) available as a webpage where search and navigation become more intuitive. *Notice that this will be fed according to my personal projects and learning, so any contribution to accelerate the process is welcome.* Here you find a *user-guide-style* page with more details are provided below in the selected notes of Elmer documentation.

## Quick answers

- [Is Elmer the adequate tool for my projects?](https://www.nic.funet.fi/pub/sci/physics/elmer/doc/ElmerOverview.pdf) In this document you find a short introduction to what Elmer can do and the main executables.

- [How do I start learning Elmer?](https://www.nic.funet.fi/pub/sci/physics/elmer/doc/GetStartedElmer.pdf) Simply put, Elmer does not require basic users to master all the fundamentals of FEM, so following the *getting started* guide seems a good starting point. There you learn how to install, configure, and run the software.

- [Where do I get the binaries of Elmer?](https://www.nic.funet.fi/pub/sci/physics/elmer/) If willing to run in Windows, the previous link provides the compiled binaries; there are also instructions for installing directly in Ubuntu as well as all the documentation and other test and sample cases.

- [I feel alone, where do I find other users?](https://www.elmerfem.org/forum/) The forum seems to be moderately active, so you can go there to chat with other users and developers if you are not in a hurry.

## Limitations and issues

- Currently the GUI is not able to import SIF files generated manually because it stores its state in a XML file; to be able to re-run cases from the GUI users need to create the equivalent case (eventually using the free text fields) in the GUI itself before regenerating a SIF file. Notice that this will overwrite the SIF file, so keep in mind to backup the file in another directory; that is especially required for highly customized cases.

- When exporting meshes from `gmsh`, consider using the extension `.msh` and not `.msh2` as is often seen as a reminder of format 2 mesh; Elmer GUI is unable to render the mesh in this case. Notice that this has apparently no effect if running from command line.

## Ongoing work

- Development of a [VS Code syntax highlight extension](https://github.com/wallytutor/elmer-sif-vscode) with help of data provided in [SOLVER.KEYWORDS](https://github.com/ElmerCSC/elmerfem/blob/devel/fem/src/SOLVER.KEYWORDS).

## Retrieving materials

Because there are plenty of interesting materials in Elmer public directory, it is worth downloading it all and selecting what to keep later. In a Linux terminal one could run the following command. If you also want to retrieve the animations, binaries, and virtual machines, consider removing and/or modifying the `-X` options.

```bash
#!/usr/bin/env bash

URL="https://www.nic.funet.fi/pub/sci/physics/elmer/"

wget -r -l 20 --no-parent           \
    -X /pub/sci/physics/elmer/anim/ \
    -X /pub/sci/physics/elmer/bin/  \
    -R "index.html*"                \
    ${URL}
```
