module Constants =
    type ElementData =
        { Symbol: string; Number: int; MolarMass: float }

    [<Literal>]
    let gasConstant: float = 8.314

module Elements =
    type private ElementSymbol = C | N | Si | Ca | V | Cr | Mn | Fe | Mo | W

    type private ElementData =
        { Symbol: ElementSymbol; Number: int; Name: string; MolarMass: float }

    let private tryParse = function
        | "C"  -> Some C
        | "N"  -> Some N
        | "Si" -> Some Si
        | "Ca" -> Some Ca
        | "V"  -> Some V
        | "Cr" -> Some Cr
        | "Mn" -> Some Mn
        | "Fe" -> Some Fe
        | "Mo" -> Some Mo
        | "W"  -> Some W
        | _ -> None

    let private elementTable : Map<ElementSymbol, ElementData> =
        [ C,  { Symbol = C;  Number = 6;  Name = "carbon";     MolarMass = 12.011 }
          N,  { Symbol = N;  Number = 7;  Name = "nitrogen";   MolarMass = 14.007 }
          Si, { Symbol = Si; Number = 14; Name = "silicon";    MolarMass = 28.085 }
          Ca, { Symbol = Ca; Number = 20; Name = "calcium";    MolarMass = 40.078 }
          V,  { Symbol = V;  Number = 23; Name = "vanadium";   MolarMass = 50.9415 }
          Cr, { Symbol = Cr; Number = 24; Name = "chromium";   MolarMass = 51.9961 }
          Mn, { Symbol = Mn; Number = 25; Name = "manganese";  MolarMass = 54.938043 }
          Fe, { Symbol = Fe; Number = 26; Name = "iron";       MolarMass = 55.845 }
          Mo, { Symbol = Mo; Number = 42; Name = "molybdenum"; MolarMass = 95.95 }
          W,  { Symbol = W;  Number = 74; Name = "tungsten";   MolarMass = 183.84 } ]
        |> Map.ofList

    let private tryGetByString (sym: string) =
        tryParse sym
        |> Option.bind (fun key -> Map.tryFind key elementTable)

    let getMolarMassArray (elements: string list) =
        elements
        |> List.choose (fun sym -> tryGetByString sym)
        |> List.map (fun elemData -> elemData.MolarMass)
        |> List.toArray

module Numerical =
    let tdma (a: float array) (b: float array) (c: float array) (d: float array) : float array =
        let n = Array.length d
        let cPrime = Array.zeroCreate n
        let dPrime = Array.zeroCreate n

        cPrime.[0] <- c.[0] / b.[0]
        dPrime.[0] <- d.[0] / b.[0]

        for i in 1 .. n - 1 do
            let m = b.[i] - a.[i] * cPrime.[i - 1]
            cPrime.[i] <- c.[i] / m
            dPrime.[i] <- (d.[i] - a.[i] * dPrime.[i - 1]) / m

        let x = Array.zeroCreate n
        x.[n - 1] <- dPrime.[n - 1]

        for i in n - 2 .. -1 .. 0 do
            x.[i] <- dPrime.[i] - cPrime.[i] * x.[i + 1]

        x

    /// Verify TDMA by solving the 1D discrete Poisson equation
    /// -u'' = 1, u(0) = u(1) = 0  on n interior nodes.
    /// Exact solution: u(x) = x(1 - x) / 2  (quadratic).
    let testTdmaQuadratic (n: int) (tol: float) : bool =
        let h   = 1.0 / float (n + 1)
        let nodes = Array.init n (fun i -> float (i + 1) * h)

        // Second-difference stencil: -u[i-1] + 2*u[i] - u[i+1] = h²
        let a = Array.create n -1.0
        let b = Array.create n  2.0
        let c = Array.create n -1.0
        let d = Array.create n (h * h)   // f * h²  with  f = 1

        let u      = tdma a b c d
        let uExact = Array.map (fun x -> x * (1.0 - x) / 2.0) nodes

        let maxErr =
            Array.map2 (fun ui ei -> abs (ui - ei)) u uExact
            |> Array.max

        maxErr < tol

module Mixtures =
    let private validateComposition (name: string) (comp: float array) (mass: float array) =
        if Array.length comp <> Array.length mass then
            invalidArg name $"Length of {name} must match number of valid elements."

    let private meanMolarMassFromMass (w: float array) (y: float array) : float =
        1.0 / Array.sum (Array.map2 (fun yk wk -> yk / wk) y w)

    let private meanMolarMassFromMole (w: float array) (x: float array)  : float =
        Array.sum (Array.map2 (fun xk wk -> xk * wk) x w)

    let private makeMeanMolarMassFromMass (w: float array) =
        fun (y: float array) ->
            validateComposition "y" y w
            meanMolarMassFromMass w y

    let private makeMeanMolarMassFromMole (w: float array) =
        fun (x: float array) ->
            validateComposition "x" x w
            meanMolarMassFromMole w x

    let makeMassFractionToMoleFractionConverter (elements: string list) =
        let w = Elements.getMolarMassArray elements
        let meanMolarMass = makeMeanMolarMassFromMass w

        fun (y: float array) ->
            validateComposition "y" y w
            let m = meanMolarMass y
            Array.map2 (fun yk wk -> m * yk / wk) y w

    let makeMoleFractionToMassFractionConverter (elements: string list) =
        let w = Elements.getMolarMassArray elements
        let meanMolarMass = makeMeanMolarMassFromMole w

        fun (x: float array) ->
            validateComposition "x" x w
            let m = meanMolarMass x
            Array.map2 (fun xk wk -> xk * wk / m) x w

module Thermophysics =
    let arrheniusFactor (a: float) (e: float) (t: float) : float =
        a * exp(-e / (Constants.gasConstant * t))

module CarbonitridingData =
    type Data =
        { CarbonInfDiffusivity: float
          NitrogenInfDiffusivity: float
          CarbonActivationEnergy: float
          NitrogenActivationEnergy: float
          CoefCarbon: float
          CoefNitrogen: float
          ActivationEnergyBase: float
          CoefPreExpFactor: float }

    let getSlyckeData () =
        { CarbonInfDiffusivity = 4.85e-05
          NitrogenInfDiffusivity = 9.10e-05
          CarbonActivationEnergy = 155_000.0
          NitrogenActivationEnergy = 168_600.0
          CoefCarbon = 1.0
          CoefNitrogen = 0.72
          ActivationEnergyBase = 570_000.0
          CoefPreExpFactor = 320.0 }

module SlyckeModels =
    let private elements = ["C"; "N"; "Fe"]

    let getMassFractionToMolarFractionConverter () =
        let massToMole = Mixtures.makeMassFractionToMoleFractionConverter elements
        fun (y: float array) ->
            match y with
            | [| yc; yn |] -> massToMole [| yc; yn; 1.0 - yc - yn |]
            | _ -> invalidArg "y" "Expected [| yC; yN |] mass fractions."

    let getMolarFractionToMassFractionConverter () =
        let moleToMass = Mixtures.makeMoleFractionToMassFractionConverter elements
        fun (x: float array) ->
            match x with
            | [| xc; xn |] -> moleToMass [| xc; xn; 1.0 - xc - xn |]
            | _ -> invalidArg "x" "Expected [| xC; xN |] mole fractions."

    type Model =
        { Data: CarbonitridingData.Data }

        static member private geometricExclusionFactor (xa: float) (xb: float) =
           (1.0 - xb) / (1.0 - 5.0 * (xa + xb))

        member private self.compositionModifier (xc: float) (xn: float) =
            self.Data.CoefCarbon * xc + self.Data.CoefNitrogen * xn

        member private self.preExponentialFactor (xc: float) (xn: float) =
            let b = self.Data.CoefPreExpFactor * self.compositionModifier xc xn
            exp (-b / Constants.gasConstant)

        member private self.activationEnergy (Ea: float) (xc: float) (xn: float) =
            Ea - self.Data.ActivationEnergyBase * self.compositionModifier xc xn

        member self.carbonDiffusivity (xc: float) (xn: float) (t: float) =
            let a = Model.geometricExclusionFactor xc xn * self.preExponentialFactor xc xn
            let e = self.activationEnergy self.Data.CarbonActivationEnergy xc xn
            self.Data.CarbonInfDiffusivity * Thermophysics.arrheniusFactor a e t

        member self.nitrogenDiffusivity (xc: float) (xn: float) (t: float) =
            let a = Model.geometricExclusionFactor xn xc * self.preExponentialFactor xc xn
            let e = self.activationEnergy self.Data.NitrogenActivationEnergy xc xn
            self.Data.NitrogenInfDiffusivity * Thermophysics.arrheniusFactor a e t

    let getModel () = { Data = CarbonitridingData.getSlyckeData () }

module Main =
    let yc = 0.0023
    let yn = 0.0000
    let temperature = 1173.0

    let model = SlyckeModels.getModel ()

    let mass2Mole = SlyckeModels.getMassFractionToMolarFractionConverter ()
    let mole2Mass = SlyckeModels.getMolarFractionToMassFractionConverter ()

    let x = mass2Mole [| yc; yn |]
    let y = mole2Mass [| x.[0]; x.[1] |]

    let xc = x.[0]
    let xn = x.[1]

    let carbonDiff = model.carbonDiffusivity xc xn temperature
    let nitrogenDiff = model.nitrogenDiffusivity xc xn temperature

    printfn $"Mass fractions ........ C = {y.[0]:F4}, N = {y.[1]:F4}"
    printfn $"Mole fractions ........ C = {x.[0]:F4}, N = {x.[1]:F4}"
    printfn $"Carbon diffusivity .... {carbonDiff:E} m²/s"
    printfn $"Nitrogen diffusivity .. {nitrogenDiff:E} m²/s"

    // --- TDMA test ---
    let tdmaPassed = Numerical.testTdmaQuadratic 100 1.0e-12
    let tdmaStatus = if tdmaPassed then "PASSED" else "FAILED"
    printfn $"TDMA test (quadratic) .. {tdmaStatus}"


let P = 101325.0
let M = 0.02896
let T = 873.15

let rho = P * M / (Constants.gasConstant * T)
let U = 10.0
let d = 0.06

let mu0 = 1.716E-5
let Tr = 273.15
let S = 110.4

let getSutherlandMu mu0 Tr S =
    fun T -> mu0 * (T / Tr)**(3.0/2.0) * (Tr + S)/(T + S)

let sutherlandMu = getSutherlandMu mu0 Tr S

let mu = sutherlandMu T

let Re = rho * U * d / mu