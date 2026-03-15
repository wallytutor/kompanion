# -*- coding: utf-8 -*-
using CairoMakie
using DelimitedFiles
using Random

Random.seed!(42)

function newton_cooling(;
        tau = 900.0,     # Physical time-scale
        T_ini = 298.15,  # Initial temperature
        T_inf = 413.15,  # Environment temperature
        n_samples = 601, # Number of samples
        sigma = 0.02,    # Noise scale
    )
    # Generate ideal solution data
    t = LinRange(0.0, 3600.0, n_samples)
    T = @. T_inf + (T_ini - T_inf) * exp(-t/tau)

    # Add scaled noise to data
    T_noisy = T .+ sigma * T .* randn(n_samples)

    return t, T, T_noisy
end

function plot_newton(t, T_ideal, T_noisy)
    fig = with_theme() do
        f = Figure()
        
        ax = Axis(f[1, 1])
        ax.xgridstyle = :dot
        ax.ygridstyle = :dot
        ax.xlabel = "Time [s]"
        ax.ylabel = "Temperature [K]"
        ax.xticks = 0:600:3600
        ax.yticks = 280:20:420
    
        lines!(ax, t, T_ideal; color = :black)
        scatter!(ax, t, T_noisy; color = :red, markersize = 5)
        xlims!(ax, extrema(ax.xticks.val))
        ylims!(ax, extrema(ax.yticks.val))
    
        f
    end

    return fig
end

function datagen()
    t, T_ideal, T_noisy = newton_cooling()
    fig = plot_newton(t, T_ideal, T_noisy)
    save("newton_cooling.png", fig)

    open("sandbox.dat", "w") do io
        writedlm(io, [t T_noisy])
    end
end

