---
jupytext:
  cell_metadata_filter: -all
  formats: md:myst
  text_representation:
    extension: .md
    format_name: myst
    format_version: 0.13
    jupytext_version: 1.18.1
kernelspec:
  display_name: Python 3 (ipykernel)
  language: python
  name: python3
---

# Pseudo-solidification formulation

+++

**TODO:** sorry, I still need to document this case!

```{code-cell} ipython3
from majordome import MajordomePlot
from majordome import ReadTextData
import majordome as mj
import numpy as np
```

```{code-cell} ipython3
# # -*- coding: utf-8 -*-
# using CairoMakie
# using DelimitedFiles
# using DataFrames
# using Taskforce.Elmer


# function workflow()
#     data1 = load_saveline_table("monophase/results")
#     data2 = load_saveline_table("multiphase/results")

#     x1 = 1000data1[:, "coordinate 1"]
#     x2 = 1000data2[:, "coordinate 1"]

#     y1 = data1[:, "temperature"]
#     y2 = data2[:, "temperature"]

#     with_theme() do
#         f = Figure()
#         ax = Axis(f[1, 1])

#         lines!(ax, x1, y1; color = :black, label = "Reference")
#         lines!(ax, x2, y2; color = :red,   label = "Phase change")

#         ax.xlabel = "Position [mm]"
#         ax.ylabel = "Temperature [K]"

#         ax.xticks = 0:10:100
#         # ax.yticks = 0:10:100

#         xlims!(ax, extrema(ax.xticks.val))
#         # ylims!(ax, extrema(ax.yticks.val))

#         f
#     end
# end
```

## Classification

+++

#elmer/domain/cartesian
#elmer/domain/transient
#elmer/models/heat-equation
