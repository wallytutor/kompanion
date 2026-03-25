module Constants =
    type ElementData =
        { Symbol: string; Number: int; MolarMass: float }

    [<Literal>]
    let gasConstant: float = 8.314

module Elements =
    type ElementSymbol = C | N | Si | Ca | V | Cr | Mn | Fe | Mo | W

    type ElementData =
        { Symbol: ElementSymbol; Number: int; Name: string; MolarMass: float }

    let tryParse = function
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

    let elementTable : Map<ElementSymbol, ElementData> =
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

    let tryGetByString (sym: string) =
        tryParse sym
        |> Option.bind (fun key -> Map.tryFind key elementTable)

    let getMolarMassArray (elements: string list) =
        elements
        |> List.choose (fun sym -> tryGetByString sym)
        |> List.map (fun elemData -> elemData.MolarMass)
        |> List.toArray

module Mixtures =
    let meanMolarMassFromMass (w: array<float>) (y: array<float>) : float =
        1.0 / Array.sum (Array.map2 (fun yk wk -> yk / wk) y w)

    let meanMolarMassFromMole (w: array<float>) (x: array<float>)  : float =
        Array.sum (Array.map2 (fun xk wk -> xk * wk) x w)

    let makeMeanMolarMassFromMass (w: array<float>) =
        fun (y: float array) ->
            if Array.length y <> Array.length w then
                invalidArg "y" "Length of y must match number of valid elements."

            meanMolarMassFromMass w y

    let makeMeanMolarMassFromMole (w: array<float>) =
        fun (x: float array) ->
            if Array.length x <> Array.length w then
                invalidArg "x" "Length of x must match number of valid elements."

            meanMolarMassFromMole w x

    let makeMassFractionToMoleFractionConverter (elements: string list) =
        let w = Elements.getMolarMassArray elements
        let meanMolarMass = makeMeanMolarMassFromMass w

        fun (y: float array) ->
            if Array.length y <> Array.length w then
                invalidArg "y" "Length of y must match number of valid elements."

            let m = meanMolarMass y
            Array.map2 (fun yk wk -> m * (yk / wk)) y w

    let makeMoleFractionToMassFractionConverter (elements: string list) =
        let w = Elements.getMolarMassArray elements
        let meanMolarMass = makeMeanMolarMassFromMole w

        fun (x: float array) ->
            if Array.length x <> Array.length w then
                invalidArg "x" "Length of x must match number of valid elements."

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

printfn $"Carbon diffusivity: {carbonDiff:E}"
printfn $"Nitrogen diffusivity: {nitrogenDiff:E}"
// let factor = data.ArrheniusFactor 1173.0
// printfn $"Arrhenius factor: {factor}"