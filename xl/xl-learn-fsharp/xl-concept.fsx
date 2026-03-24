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


module SlyckeModels =
    let compositionModifier (xc: float) (xn: float) =
        xc + 0.75 * xn

    let activationModifier (xc: float) (xn: float) =
        570_000.0 * (compositionModifier xc xn)

    let preExponentialFactor (xc: float) (xn: float) =
        let b = -320.0 / Constants.gasConstant
        let c = b * (compositionModifier xc xn)
        (exp c) / (1.0 - 5.0 * (xc + xn))

    // let arrheniusFactor (a: float) (e: float) (t: float) : float =
    //     a * exp(-e / (Constants.gasConstant * t))

    // type ArrheniusData =
    //     { A: float; E: float}

    //     member this.ArrheniusFactor (t: float) : float =
    //         arrheniusFactor this.A this.E t

// open Models
// let data = { A = 1.0e-05; E = 50.0e+03 }

// let data: Models.ArrheniusData = { A = 1.0e-05; E = 50.0e+03 }
// let factor = data.ArrheniusFactor 1173.0
// printfn $"Arrhenius factor: {factor}"