---
jupytext:
  main_language: python
  cell_metadata_filter: -all
  text_representation:
    extension: .md
    format_name: myst
    format_version: 0.13
    jupytext_version: 1.18.1
  formats: md:myst
kernelspec:
  name: python3
  display_name: Python 3 (ipykernel)
  language: python
---

# Cantera all-in-one

+++

## Import Cantera

**Note:** importing Cantera from Julia can be made through [PythonCall](https://juliapy.github.io/PythonCall.jl/stable/) module. Generally speaking the interaction between Julia and Python works smoothly but the user is expected to know how to convert values between the two languages (especially when retrieving results from Cantera to use in Julia). Just import Cantera using the alias `ct` (as one would do from Python) as follows:

```julia
using PythonCall

const ct = pyimport("cantera");
```

```{code-cell} ipython3
import cantera as ct
```

## Basics of *Solution*

+++

## Adiabatic combustion

+++

## Working with mixtures

+++

## Tabulating properties

+++

## Case studies

+++

### Methane combustion

+++

### Hydrogen combustion
