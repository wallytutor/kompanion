---
jupyter:
  jupytext:
    cell_metadata_filter: -all
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
      jupytext_version: 1.18.0
  kernelspec:
    display_name: Python 3 (ipykernel)
    language: python
    name: python3
---

# Water evaporation kinetics


In this tutorial we make use of Cantera's `ExtensibleReactor` model as described [here](https://cantera.org/stable/userguide/extensible-reactor.html) to simulate the evaporation of water in an open system.

This aims at representing a first step towards a thermogravimetry analysis (TGA) simulation using Cantera.


## Model statement


Our goal is to model the following reaction while tracking the state of the condensed matter as in TGA; we need nonetheless to track the mass transfer rate to be able to couple with gas phase in more complex systems.

$$
\text{H}_2\text{O}_{(l)} \rightarrow \text{H}_2\text{O}_{(g)}
\qquad\text{where}\qquad\Delta{}H>0
$$


The rate is assumed proportional to the remaining mass of liquid water $m_{(l)}=Y_{(l)}m$ at any given instant, where $k(T)$ assumes an Arrhenius representation.

$$
\dot{r} = k(T) m_{(l)}
$$


As liquid water is the sole species in the system, it is worthless solving for species conservation equation and overall mass balances simplifies to:

$$
\dfrac{dm}{dt}=-\dot{r}
\qquad\text{or}\qquad
\dfrac{dm}{dt}=-k(T)m_{(l)}
$$


## Preparing toolbox


Selecting the base class based on:

- `ExtensibleReactor` will solve for volume and internal energy
- `ExtensibleConstPressureReactor` will solve for enthalpy

Relevant references:

- [API docs: ExtensibleReactor](https://cantera.org/stable/python/zerodim.html#extensiblereactor)
- [User guide: ExtensibleReactor](https://cantera.org/stable/userguide/extensible-reactor.html)
- [Examples: implementing wall inertia](https://cantera.org/stable/examples/python/reactors/custom2.html)
- [Examples: porous media burner](https://cantera.org/stable/examples/python/reactors/PorousMediaBurner.html)

```python
%load_ext autoreload
%autoreload 2
```

```python
from protomodels import WaterReactor
import cantera as ct
```

```python
water_liq = ct.Solution("materials.yaml", "water_liq")
water_gas = ct.Solution("materials.yaml", "water_gas")

# Heat rate [W]
rate = 10_000

n_pts = 1001
t_end = 2000

reactor = WaterReactor(water_liq, mass_liq=1.0, heat_rate=rate, vapor=water_gas)
reactor.simulate(n_pts, t_end)
plot = reactor.plot()
```

```python

```
