# OpenFOAM

_Updated and biased towards OpenFOAM 13._

## Environment variables

Whenever starting a working session in OpenFOAM, it is required to source its environment variables; under bash, for the current version that simply means running `source /opt/openfoam13/etc/bashrc` if you have installed the toolkit at the _default_ location. If you are using a single version of OpenFOAM, it is worth automating this in your own `~/.bashrc` file with:

```bash
if [ -f "/opt/openfoam13/etc/bashrc" ]; then
    source /opt/openfoam13/etc/bashrc
fi
```

After sourcing this file, several environment variables are made available; a quick inspection can be made with `env | grep -E '^(FOAM|WM_)' | sort`. Among these, you are invited to check the contents of the folders pointed by the following. Under `FOAM_ETC` you find several templates and default files that may be complementary to software documentation. It is often a good idea to make a full copy of `FOAM_TUTORIALS` in your workspace for exploring all the available samples.
```bash
FOAM_ETC=/opt/openfoam13/etc
FOAM_TUTORIALS=/opt/openfoam13/tutorials
```

Please, also notice that by default OpenFOAM expects one to work under `WM_PROJECT_USER_DIR`, with cases being located under `FOAM_RUN`. You are not obliged to do so, but it is generally a good idea to create a Git repository at this location, especially when developping new applications that are compiled and linked from the `FOAM_USER_*` directories listed below.

```bash
WM_PROJECT_USER_DIR=/home/walter/OpenFOAM/walter-13
FOAM_RUN=/home/walter/OpenFOAM/walter-13/run
FOAM_USER_APPBIN=/home/walter/OpenFOAM/walter-13/platforms/linux64GccDPInt32Opt/bin
FOAM_USER_LIBBIN=/home/walter/OpenFOAM/walter-13/platforms/linux64GccDPInt32Opt/lib
```

## Mesh manipulation

### Conversion from Fluent (3D)

- Base documentation is found at [OpenFOAM v13 User Guide - 5.7 Mesh conversion](https://doc.cfd.direct/openfoam/user-guide-v13/mesh-conversion); before going further, make sure that the exported mesh file is in ASCII format (which is not Fluent's default), as the available converters do not support binary formats, since these are in proprietary format.

- Create an empty case with at least a `system/controlDict` file and place you mesh file somewhere in the case; a good option for keeping track of the case is `constant/<mesh-file>.msh`, as it will live along the generated `polyMesh` directory created by converter. Run `fluent3DMeshToFoam constant/<mesh-file>.msh` to perform the base conversion.

- If Fluent mesh has boundaries that are split or you need to merge patches, consider using `createPatch`; example files can be found with `find /opt/openfoam13/ -iname createPatchDict`.

- After reaching the desired goal, run `renumberMesh` to manipulate cell ordering; this is required for performance reasons. The default dictionary is found at `/opt/openfoam13/etc/caseDicts/annotated/renumberMeshDict`, which you should copy and edit under you case's `system/`.

- It is a good idea to run `checkMesh` after each mesh manipulation step.
