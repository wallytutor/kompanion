# ---
# jupyter:
#   jupytext:
#     cell_metadata_filter: -all
#     text_representation:
#       extension: .py
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.18.0
#   kernelspec:
#     display_name: Python 3 (ipykernel)
#     language: python
#     name: python3
# ---

# %load_ext autoreload
# %autoreload 2

from majordome import MajordomePlot, bounds
import cantera as ct
import majordome as mj
import numpy as np


# +

def specific_heat_cantera(T, M, s):


def sample_temperature(species):
    T_lims = species.input_data["thermo"]["temperature-ranges"]
    return np.linspace(T_lims[0], T_lims[1], int(round(T_lims[-1])))

@MajordomePlot.new(
    xlabel = "Temperature [K]",
    ylabel = "Specific heat [J/(kg K)]"
)
def plot_specific_heat(T, c, plot=None, **kwargs):
    fig, ax = plot.subplots()
    ax[0].plot(T, c, label="Schieltz, 1964")

def check_species(mineral, data):
    m = mineral.molecular_weight
    
    T = sample_temperature(mineral)
    a = 4.184e3 *  np.array(data)
    c1 = specific_heat_maier_kelley(T, m, a)
    c2 = specific_heat_cantera(T, m, mineral)
    
    plot = plot_specific_heat(T, c1)
    plot.axes[0].plot(T, c2, label="Cantera")
    _ = plot.axes[0].legend(loc=4)


# -

species = ct.Species.list_from_file("materials.yaml", "species")
species

check_species(species[5], [84.22, 20.00e-03, -25.00e+05, -1804000.0, 60.00])

water = species = ct.Species.list_from_file("materials.yaml", "species_water")
check_species(species[1], [7.17, 2.56e-03, 0.08e+05, -57800.0, 45.13])

species[0].thermo.cp(1000) / 1000, species[0].molecular_weight

solids = ct.Solution("materials.yaml", "aszo")
solids.TP = 1000, None

solids.cp_mass * (species[0].molecular_weight / 1000)

solids.mass_fraction_dict()

solids.species_names
