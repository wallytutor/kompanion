module SteadyHeatConduction

using CairoMakie
using LinearAlgebra
using AuChimiste: STEFAN_BOLTZMANN
using Taskforce.Common: MAKIETHEME

export SteadyHeatConduction1D, solve
export make_thermal_conductivity
export plot_temperature

"Discrete cell in domain with properties attached."
struct GridCell
    "Coordinate of cell."
    z::Float64

    "Thermal conductivity function."
    k::Function
end

"Discretization of 1D domain with equally spaced cells."
struct HomogeneousDomainGrid1D
    "Ordered cells over domain length."
    cells::Vector{GridCell}

    "Density of cells per meter in domain."
    ρ::Float64

    function HomogeneousDomainGrid1D(zs, ze, k; ρ = 1000.0)
    	# Thickness of region:
    	ΔL = ze - zs
    
    	# Number of cells in region:
    	n = convert(Int64, round(ρ * ΔL, RoundUp))
    
    	# Width of cell (after rounding count):
    	δ = ΔL / n

        ##
        # XXX: check if zs-1/2δ is not the right way! Otherwise
        # interpolations at interfaces will not be right!
        ##
        
    	# *n* points missing half cell on end:
    	centers = LinRange(zs, ze - 0.5δ, n)

        # Assembly array of cells
    	cells = map((z)->GridCell(z, k), centers)

        return new(cells, ρ)
    end

    function HomogeneousDomainGrid1D(layers::NTuple; ρ = 1000.0)
    	zs = 0
    	domain = []
    
    	for (L, k) in layers
    		ze = zs + L
    		grid = HomogeneousDomainGrid1D(zs, ze, k; ρ)
    		append!(domain, grid.cells)
    		zs = ze
    	end
    
    	# Add one last cell to close the FD domain.
    	push!(domain, GridCell(zs, layers[end][2]))
    
        cells = vcat(domain...)
        
    	return new(cells, ρ)
    end
end

"Model data structure and configuration."
struct SteadyHeatConduction1D
    "Thermal conductivity functions over the domain."
	k::Vector{Function}

    "Coordinates of cells over the domain."
	z::Vector{Float64}

    "Temperature field over the domain."
	T::Vector{Float64}

    "Cells sizes"
	δ::Vector{Float64}

    "External convective heat transfer coefficient."
	h::Float64

    "External wall emissivity."
	ε::Float64

    "Fixed temperature of internal wall."
	Tm::Float64

    "Fixed temperature of convection."
	Tc::Float64
    
    "Fixed temperature of radiation."
	Tr::Float64
	
	function SteadyHeatConduction1D(layers, Tm, Tc, Tr; h, ε, ρ = 1000.0)
		domain = HomogeneousDomainGrid1D(layers; ρ)
		
		# Decompose domain:
		z = map(o->o.z, domain.cells)
		k = map(o->o.k, domain.cells)

		# Compute cell distances:
		δ = diff(z)
		
		# T[2:end] = M \ b
		T = zeros(length(z))

		# Apply initial guess as *hot* temperature:
		T[1:end] .= Tm

		return new(k, z, T, δ, h, ε, Tm, Tc, Tr)
	end
end

"Evaluate thermal conductivity over the model domain."
function thermal_conductivity(obj::SteadyHeatConduction1D)
    return map((f, T)->f(T), obj.k, obj.T)
end

"Global linearized heat transfer coefficient."
function global_heat_transfer_coef(obj::SteadyHeatConduction1D, τ::Float64)
	return obj.h + obj.ε * STEFAN_BOLTZMANN * (τ + obj.Tr) * (τ^2 + obj.Tr^2)
end

"Evaluation of boundary flux on right wall."
function surface_boundary_condition(obj::SteadyHeatConduction1D, U::Float64)
	return (obj.h - U) * obj.Tr - obj.h * obj.Tc
end

"Standardized reporting of heat fluxes."
function heat_fluxes(obj::SteadyHeatConduction1D)
	Ts = obj.T[end]
    Tc = obj.Tc
    Tr = obj.Tr
    h = obj.h
    ε = obj.ε

    qc = h * (Ts - Tc) / 1000
    qr = ε * STEFAN_BOLTZMANN * (Ts^4 - Tr^4) / 1000
    qt = qc + qr

    @info("""

    Total heat loss ............ $(round(qt; digits = 3)) kW/m²
    - convection ............... $(round(qc; digits = 3)) kW/m²
    - radiation ................ $(round(qr; digits = 3)) kW/m²
    """)
end

"Surface heat flux crossing system right wall."
function surface_flux(obj::SteadyHeatConduction1D)
    U = global_heat_transfer_coef(obj, obj.T[end])
	return obj.h * (obj.Tr - obj.Tc) + U * (obj.T[end] - obj.Tr)
end

"Iterative solution of steady-state heat conduction problem."
function solve(obj::SteadyHeatConduction1D; 
        β       = 0.45,
        maxiter = 100,
        atol    = 1.0e-06
    )
	# Initialize array of iteration:
	T_new = zeros(size(obj.T))
	T_new[1] = obj.T[1]

	# Solution data:
	n = length(obj.T) - 1
	b = zeros(n)
	M = Tridiagonal(zeros(n-1), zeros(n), zeros(n-1))
	
	for niter in range(1, maxiter)
		# Update thermal conductivity with latest values:
		k_full = thermal_conductivity(obj)
	
		# Evaluate cell-interface thermal conductivities:
		k_eval = harmonic_mean.(k_full[1:end-1], k_full[2:end])
	
		# Compute model coefficients:
		α = -k_eval ./ obj.δ
		U = global_heat_transfer_coef(obj, obj.T[end])
		
		# Update problem matrix:
		M.du[1:end] = -α[2:end]
		M.dl[1:end] = -α[2:end]
	
		M.d[1:end] = α[1:end]
		M.d[1:end-1] += α[2:end]
		M.d[end] -= U
		
		# Update problem forcing function:
		b[1] = α[1] * obj.T[1]
		b[end] = surface_boundary_condition(obj, U)

		# Solve for initial guess:
		T_new[2:end] = M \ b

		# Compute residual and swap solution:
		residual = maximum(abs.(obj.T .- T_new))
		obj.T[2:end] = β * T_new[2:end] + (1-β) * obj.T[2:end]
		
		if residual < atol
			@info("Converged after $(niter) iterations")
			break
		end
	end

	heat_fluxes(obj)
	
	return obj
end

"Interpolation of function through pairwise harmonic mean."
function harmonic_mean(ki, kj)
    return 2ki * kj / (ki + kj)
end

"Wrap a constant thermal conductivity as a temperature function."
function make_thermal_conductivity(k::Float64)
    return (_T) -> k
end

"Display problem solution as a plot."
function plot_temperature(obj::SteadyHeatConduction1D, layers)
	F = round(surface_flux(obj) / 1000; digits = 1)
	τ = round(obj.T[end]; digits = 1)
    interfaces = vcat(0, accumulate(+, map(g->g[1], layers))...)
    
	with_theme(MAKIETHEME) do
		f = Figure(size = (680, 400))
	    ax = Axis(f[1, 1])
		ax.title = "Surface flux $(F) kW/m² at $(τ) K"
	    ax.ylabel = "Temperature [K]"
	    ax.xlabel = "Position [cm]"
		
		lines!(ax, 100obj.z, obj.T)
    	vlines!(ax, 100interfaces[2]; color = :red, linestyle = :dash)
    	vlines!(ax, 100interfaces[3]; color = :red, linestyle = :dash)
    	vlines!(ax, 100interfaces[4]; color = :red, linestyle = :dash)
    	vlines!(ax, 100interfaces[5]; color = :red, linestyle = :dash)
	
		ax.xticks = 0:5:30
		xlims!(ax, 0, 30)

		ax.yticks = 600:200:2000
		ylims!(ax, 600, 2000)
		
	    f, ax
	end
end

end # (SteadyHeatConduction)