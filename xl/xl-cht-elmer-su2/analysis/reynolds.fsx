open Thermophysics

let U = 10.0
let d = 0.06
let P = 101325.0
let T = 873.15

let M = 0.02896
let mu0 = 1.716E-5
let Tr = 273.15
let S = 110.4

let sutherlandMu = Thermophysics.makeSutherlandMu mu0 Tr S

let mu = sutherlandMu T
let rho = Thermophysics.idealGasDensity P T M
let Re = Thermophysics.reynoldsNumber rho U d mu
