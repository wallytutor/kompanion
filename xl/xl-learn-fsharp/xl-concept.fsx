module Constants =
    type ElementData =
        { Symbol: string; Number: int; MolarMass: float }

    [<Literal>]
    let gasConstant: float = 8.314

    let elementTable =
        {| C  = { Symbol = "C";  Number = 6;    MolarMass = 12.011};
           N  = { Symbol = "N";  Number = 7;    MolarMass = 14.007};
           Si = { Symbol = "Si"; Number = 14;   MolarMass = 28.085};
           Ca = { Symbol = "Ca"; Number = 20;   MolarMass = 40.078};
           V  = { Symbol = "V";  Number = 23;   MolarMass = 50.9415};
           Cr = { Symbol = "Cr"; Number = 24;   MolarMass = 51.9961};
           Mn = { Symbol = "Mn"; Number = 25;   MolarMass = 54.938043};
           Fe = { Symbol = "Fe"; Number = 26;   MolarMass = 55.845};
           Mo = { Symbol = "Mo"; Number = 42;   MolarMass = 95.95};
           W  = { Symbol = "W";  Number = 74;   MolarMass = 183.84}; |}

    let elementNames =
        {| C  = "carbon";
           N  = "nitrogen";
           Si = "silicon";
           Ca = "calcium";
           V  = "vanadium";
           Cr = "chromium";
           Mn = "manganese";
           Fe = "iron";
           Mo = "molybdenum";
           W  = "tungsten"; |}


module Thermophysics =
    let arrheniusFactor (a: float) (e: float) (t: float) : float =
        a * exp(-e / (Constants.gasConstant * t))


module SlyckeModels =
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




let xc = 0.02
let xn = 0.01
let temperature = 1173.0
let carbonDiff = SlyckeModels.carbonDiffusivity xc xn temperature
let nitrogenDiff = SlyckeModels.nitrogenDiffusivity xc xn temperature

printfn $"Carbon diffusivity: {carbonDiff:E}"
printfn $"Nitrogen diffusivity: {nitrogenDiff:E}"
// let factor = data.ArrheniusFactor 1173.0
// printfn $"Arrhenius factor: {factor}"