# Solver Input Files (SIF)

Once you get serious with Elmer it is a natural evolution to prefer to work with *SIF* files instead of the GUI most of the time; the GUI remains useful for raw case generation, avoiding writing boilerplate setups and to get default values right. This is also true in a majority of scientific computing software. The documentation of *SIF* is spread over the whole documentation of Elmer and this page tries to summarize it. For the beginner, this [video](https://www.youtube.com/watch?v=iXVEqKTq5TE) is a good starting point, this page being more of a reference manual.

Because syntax highlighting is important for productivity, I am continuously developing a minimalistic extension for VS Code. Its partial development can be found [here](https://github.com/wallytutor/elmer-sif-vscode). You can clone that repository and copy the `sif/` directory under `%USERPROFILE%/.vscode/extensions`  or in the equivalent directory documented [here](https://code.visualstudio.com/docs/editor/extension-marketplace#_where-are-extensions-installed); later it will probably be packaged as a standard VS Code extension.

## Sections

- `Header`

- `Simulation`

- `Constants`

- `Material <n>`

- `Body <n>`

- `Solver <n>`

- `Equation <n>`

- `Initial Condition <n>`

- `Boundary Condition <n>`
