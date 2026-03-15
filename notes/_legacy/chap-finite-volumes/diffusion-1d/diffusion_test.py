# ---
# jupyter:
#   jupytext:
#     cell_metadata_filter: -all
#     formats: py:percent
#     text_representation:
#       extension: .py
#       format_name: percent
#       format_version: '1.3'
#       jupytext_version: 1.18.1
#   kernelspec:
#     display_name: Python 3 (ipykernel)
#     language: python
#     name: python3
# ---

# %% [markdown]
# # Diffusion in Solids

# %%
from majordome import constants
from majordome import _diffusion as md
import numpy as np

# %% [markdown]
# ## Carburizing of steel

# %%
def pre_exponential(x, _T, R=constants.GAS_CONSTANT):
    return 4.84e-05 * np.exp(-320 * x[0] / R) / (1 - 5 * x[0])

def activation_energy(x, _T):
    return 155_000 - 570_000 * x[0]

Ac = md.PreExponentialFactor(pre_exponential)
Ec = md.ActivationEnergy(activation_energy)

# %%
D1 = md.ArrheniusModifiedDiffusivity(
    pre_exponential_factor = Ac,
    activation_energy      = Ec
)
D2 = md.ArrheniusModifiedDiffusivity(
    pre_exponential_func   = pre_exponential,
    activation_energy_func = activation_energy,
)
D3 = md.ArrheniusModifiedDiffusivity(
    pre_exponential_factor = Ac,
    activation_energy_func = activation_energy,
)
D4 = md.ArrheniusModifiedDiffusivity(
    pre_exponential_func   = pre_exponential,
    activation_energy      = Ec,
)

# %%
for i, Di in enumerate([D1, D2, D3, D4], start=1):
    print(f"D{i}: {Di([0.01], 1000):.6e} m^2/s")

# %% [markdown]
# ## Carbonitriding of steel

# %%
def f(x):
    return x[0] + 0.72 * x[1]

def A(x, R=constants.GAS_CONSTANT):
    return np.exp(-320 * f(x) / R) / (1 - 5 * sum(x))

def E(x):
    return 570_000 * f(x)

Dc = md.ArrheniusModifiedDiffusivity(
    pre_exponential_func   = lambda x, _: 4.84e-05 * (1 - 5 * x[1]) * A(x),
    activation_energy_func = lambda x, _: 155_000 - E(x),
)
Dn = md.ArrheniusModifiedDiffusivity(
    pre_exponential_func   = lambda x, _: 9.10e-05 * (1 - 5 * x[0]) * A(x),
    activation_energy_func = lambda x, _: 168_600 - E(x),
)

Dc_rust = md.slycke.create_carbon_diffusivity()
Dn_rust = md.slycke.create_nitrogen_diffusivity()

# %%
Y = [0.01, 0.01]
m = [12.01, 14.01]

M = 1 / ((1-sum(Y)) / 55.85 + sum(y / mi for y, mi in zip(Y, m)))
X = [y * M / mi for y, mi in zip(Y, m)]

T = 1173

print(f"D_C: {Dc(X, T):.6e} | {Dc_rust(X, T):.6e} m²/s")
print(f"D_N: {Dn(X, T):.6e} | {Dn_rust(X, T):.6e} m²/s")
