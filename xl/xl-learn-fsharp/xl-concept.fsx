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
            Array.map2 (fun yk wk -> m * (yk / wk)) y w

    let makeMoleFractionToMassFractionConverter (elements: string list) =
        let w = Elements.getMolarMassArray elements
        let meanMolarMass = makeMeanMolarMassFromMole w

        fun (x: float array) ->
            validateComposition "x" x w
            let m = meanMolarMass x
            Array.map2 (fun xk wk -> (xk * wk) / m) x w

module Thermophysics =
    let arrheniusFactor (a: float) (e: float) (t: float) : float =
        a * exp(-e / (Constants.gasConstant * t))

module SlyckeModels =
    let elements = ["C"; "N"]

    [<Literal>]
    let carbonInfDiffusivity: float = 4.85e-05

    [<Literal>]
    let nitrogenInfDiffusivity: float = 9.10e-05

    [<Literal>]
    let carbonActivationEnergy: float = 155_000.0

    [<Literal>]
    let nitrogenActivationEnergy: float = 168_600.0

    [<Literal>]
    let coefCarbon: float = 1.0

    [<Literal>]
    let coefNitrogen: float = 0.72

    [<Literal>]
    let activationEnergyBase: float = 570_000.0

    [<Literal>]
    let coefPreExtFactor: float = 320.0

    let compositionModifier (xc: float) (xn: float) =
        coefCarbon * xc + coefNitrogen * xn

    let activationModifier (xc: float) (xn: float) =
        activationEnergyBase * (compositionModifier xc xn)

    let siteOccupancy (xc: float) (xn: float) =
        1.0 - 5.0 * (xc + xn)

    let preExponentialFactor (xc: float) (xn: float) =
        let b = -coefPreExtFactor / Constants.gasConstant
        (exp (b * (compositionModifier xc xn))) / (siteOccupancy xc xn)

    let carbonDiffusivity (xc: float) (xn: float) (t: float) =
        let a = (1.0 - xn) * preExponentialFactor xc xn
        let e = carbonActivationEnergy - activationModifier xc xn
        carbonInfDiffusivity * Thermophysics.arrheniusFactor a e t

    let nitrogenDiffusivity (xc: float) (xn: float) (t: float) =
        let a = (1.0 - xc) * preExponentialFactor xc xn
        let e = nitrogenActivationEnergy - activationModifier xc xn
        nitrogenInfDiffusivity * Thermophysics.arrheniusFactor a e t

    let getMassFractionToMolarFractionConverter () =
        let massToMole = Mixtures.makeMassFractionToMoleFractionConverter elements
        fun (y: float array) -> massToMole y

    let getMolarFractionToMassFractionConverter () =
        let moleToMass = Mixtures.makeMoleFractionToMassFractionConverter elements
        fun (x: float array) -> moleToMass x

// module Main =
let xc = 0.02
let xn = 0.01
let temperature = 1173.0
let carbonDiff = SlyckeModels.carbonDiffusivity xc xn temperature
let nitrogenDiff = SlyckeModels.nitrogenDiffusivity xc xn temperature

let mass2Mole = SlyckeModels.getMassFractionToMolarFractionConverter ()
let mole2Mass = SlyckeModels.getMolarFractionToMassFractionConverter ()

printfn $"Carbon diffusivity .... {carbonDiff:E}"
printfn $"Nitrogen diffusivity .. {nitrogenDiff:E}"
// let factor = data.ArrheniusFactor 1173.0
// printfn $"Arrhenius factor: {factor}"