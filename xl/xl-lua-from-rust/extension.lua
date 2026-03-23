function just_something_else()
    print("This is just something else.")
end

function diffusion_coefficient(T)
    -- globals.just_something_else = just_something_else

    if not gas_constant then
        print("\x1b[31mgas_constant is not defined\x1b[0m")
    end

	local A = 4.84e-05
    local E = 155e+03
    local R = gas_constant

    -- just_something_else()
    return utils.arrhenius_factor(A, E, R, T)
end

return diffusion_coefficient