module PrettifyLaTeX

using LaTeXStrings
using Symbolics: Num, Equation
using SymbolicUtils: BasicSymbolic

import Symbolics
import SymbolicUtils

const BlocksSymbolic = Union{Num, BasicSymbolic, Number, Rational}

const LATEX_NAMES = IdDict{BasicSymbolic, LaTeXString}()

function register_latex!(x::Num, name::String;
                         verbose::Bool = false,
                         force::Bool = false)::Nothing
    if SymbolicUtils.istree(Symbolics.value(x))
        error("Expression `x` should be of atomic type, got $x")
    end

    key = Symbolics.value(x)

    if haskey(LATEX_NAMES, key) && !force
        verbose && @warn("Object already in map! " *
                         "Please use `force=true` for modifying `$x`...")
        return
    elseif haskey(LATEX_NAMES, key) && force
        verbose && @warn("Object already in map! " *
                         "Overwriting `$x` because `force=true`...")
    end

    LATEX_NAMES[key] = LaTeXString(name)
    return nothing
end

function handle_numbers(bs)
    if bs isa Rational
        num = numerator(bs)
        den = denominator(bs)
        return den == 1 ? string(num) : string(num, "/", den)
    end

    return string(bs)
end

function replace_bs(bs::BlocksSymbolic)
    if !SymbolicUtils.istree(bs)
        bs isa Number && return handle_numbers(bs)

        # Leaf (atomic variable or literal)
        return get(LATEX_NAMES, bs, string(bs))
    end

    # Composite expression: get op and args using the public API
    op   = SymbolicUtils.operation(bs)
    args = SymbolicUtils.arguments(bs)

    # Recursively process children
    new_args = map(replace_bs, args)

    # Componse expression with replacements:
    return SymbolicUtils.term(op, new_args...)
end

function replace_atoms(x::Union{Num, Equation})

    # Handle equations
    if x isa Equation
        lhs = replace_bs(Symbolics.value(x.lhs))
        rhs = replace_bs(Symbolics.value(x.rhs))
        return SymbolicUtils.term(:(==), lhs, rhs)
    end

    # Handle general symbolic expressions
    # if x isa BasicSymbolic
    #     return replace_bs(x)
    # end

    # Handle normal expressions
    return replace_bs(Symbolics.value(x))
end

end # module PrettifyLaTeX