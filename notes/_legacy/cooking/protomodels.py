# -*- coding: utf-8 -*-
from cantera import ExtensibleConstPressureReactor
from majordome import MajordomePlot
import cantera as ct
import majordome as mj
import numpy as np


class WaterReactor(ExtensibleConstPressureReactor):
    __slots__ = (
        "y",
        "_vapor",
        "_rate_const",
        "_heat_rate",
        "_var_names",
        "_mass_tol",
        "_table",
    )

    def __init__(self, solution, mass_liq, vapor, heat_rate,  **kwargs):
        # One cannot directly modify the mass of the reactor through
        # self.mass; one workaround this is to compute the volume
        # before creating the super() instance.
        kwargs["volume"] = mass_liq / solution.density

        super().__init__(solution, **kwargs)

        self._vapor = vapor
        self._heat_rate = heat_rate
        self._rate_const = ct.ArrheniusRate(5.0e+07, 0, 78.0e+06)
        self._mass_tol = kwargs.get("mass_tol", 0.01 * mass_liq)

    def replace_eval(self, t, LHS, RHS) -> None:
        """ Evaluate problem equations for mass, enthalpy, composition. """
        m = self.mass
        h = self.thermo.enthalpy_mass
        Y = self.thermo.Y

        if m < self._mass_tol:
            raise StopIteration()

        # Get provided heat [W]:
        Q = self._heat_rate

        # Evaluate current reaction rate [kg/s]:
        rr = self._rate_const(self.T) * m * Y[0]

        # Heat of reactions [J/kg * kg/s = W]:
        self._vapor.TP = self.thermo.T, None
        delta_h = (h - self._vapor.enthalpy_mass)
        Q += delta_h * rr

        RHS[0] = -rr
        RHS[1] = Q #- h * rr
        RHS[2] = 0.0

    @property
    def variable_names(self) -> list[str]:
        """ Provides access to the names of internal variables. """
        if not hasattr(self, "_var_names"):
            f = self.component_name
            n = range(self.n_vars)
            self._var_names = list(map(f, n))
        return self._var_names

    def state_dict(self) -> dict[str, np.float64]:
        """ Provides access to the current state dictionary. """
        return dict(zip(self.variable_names, self.get_state()))

    def simulate(self, n_pts, t_end):
        times = np.linspace(0, t_end, n_pts)
        results = ct.SolutionArray(self.thermo, shape=(n_pts,),
                                   extra={"t": 0.0, "m": self.mass})

        network = ct.ReactorNet([self])
        network.initialize()
        
        for i, t in enumerate(times[1:], 1):
            try:
                network.advance(t)
                results[i].TPY = self.thermo.TPY
                results[i].t = t
                results[i].m = self.mass
            except:
                break
    
        self._table = results.to_pandas().iloc[:i].copy()
        return self._table

    @MajordomePlot.new(shape=(2, 1), size=(10, 8), xlabel="Time [s]",
                       ylabel=["Mass [kg]", "Temperature [K]"])
    def plot(self, plot=None):
        _, ax = plot.subplots()

        t = self._table["t"].to_numpy()
        m = self._table["m"].to_numpy()
        T = self._table["T"].to_numpy()
        
        ax[0].plot(t, m)
        ax[1].plot(t, T)
        