## Symbols

```python
# Discretization related
τ, δ = symbols("tau delta")

# Cell-based concentrations (c_0 = c_P^0)
c_E, c_P, c_W = symbols("c_E c_P c_W")
c_G, c_B, c_0 = symbols("c_G c_B c_0")

# Cell-based diffusivities
D_E, D_P, D_W, D_G = symbols("D_E D_P D_W D_G")

# Face-based diffusivities
D_e, D_w, D_g, D_b = symbols("D_e D_w D_g D_b")

# Face-based Fourier/Sherwood numbers
Fo_e, Fo_w, Fo_g, Sh_g = symbols("α_e α_w α_g, Sh_g")

# For boundary conditions
h, c_inf = symbols("h c_inf")

# Parameter aliases
β = symbols("beta")
```

Because it will be later useful for coefficient grouping, the following mapping is provided:

```python
Sh_g_expr = h * δ / D_g
map_sherwood = [(Sh_g_expr, Sh_g)]
```





```python
# Convective fluxes by definition:
B_w = +1 * h * (c_B - c_inf)
B_e = -1 * h * (c_B - c_inf)
```

By definition, FVM will evaluate the mean composition in a cell, so in fact we might think that $c_{B}=c_{P}$ might be a good replacement in the above expression. Nonetheless, this is not what we did when deriving type 1 boundary condition. In fact, the boundary composition has to be interpreted as not belonging to the cell itself. Another idea is to _recycle_ what we have done when deriving the type 1 boundary condition and add a _ghost_ cell beyond the boundary, which takes again a composition $c_{B}={\scriptstyle\frac{1}{2}}(c_{G}+c_{P})$.


<div class="alert alert-info">

**Identifying ghost node composition**

</div>


By replacing both $c_{W}$ and $c_{E}$ by $c_{G}$ where applicable, and taking care of sign manipulation (for the aestetics of getting similar equations), we can write

$$
\begin{align*}
\text{(west)}\qquad &
-D_{g}\dfrac{c_{P}-c_{G}}{\delta}=h\left(c_{B} - c_{\infty}\right)
%
\\[12pt]
%
\text{(east)}\qquad &
-D_{g}\dfrac{c_{G}-c_{P}}{\delta}=h\left(c_{B} - c_{\infty}\right)
\end{align*}
$$

```python
# Fluxes computed w.r.t. ghost cell:
J_w = -1 * D_g * (c_P - c_G) / δ
J_e = -1 * D_g * (c_G - c_P) / δ
```

It is worth introducing here $\mathcal{Sh}$, the [Sherwood number](https://en.wikipedia.org/wiki/Sherwood_number) (at least some sort of, as the length $\delta$ does not correspond to the actual length that should be used as per its definition); $\beta$ is just a placeholder variable introduced here to simplify the later equations as we shall see. It is given by

$$
\mathcal{Sh}=\dfrac{h\delta}{D_{g}}=2\beta
$$


In both cases we can rearrange equations to be written as

$$
\begin{align*}
\text{(west)}\qquad &
c_{G}-c_{P}=\mathcal{Sh}\left(c_{B} - c_{\infty}\right)
%
\\[12pt]
%
\text{(east)}\qquad &
c_{P}-c_{G}=\mathcal{Sh}\left(c_{B} - c_{\infty}\right)
\end{align*}
$$


We can now substitute $c_{B}$ to get:

$$
\begin{align*}
\text{(west)}\qquad &
c_{G} = \dfrac{2\beta{}c_{\infty} - (\beta + 1)c_{P}}{(\beta - 1)}
%
\\[12pt]
%
\text{(east)}\qquad &
c_{G} = \dfrac{2\beta{}c_{\infty} - (\beta - 1)c_{P}}{(\beta + 1)}
\end{align*}
$$

```python
def manipulate_robin(eq, fix_sh=True, solve_ghost=True):
    """ Manipulate Robin boundary condition equation. """
    # Isolate c_B from expr_B:
    mapping = [(c_B, solve(expr_B, c_B)[0])]

    # Manipulate to get Sherwood number:
    eq = eq * δ / D_g

    # Substitute interpolated c_B:
    eq = expand(eq.subs(mapping))

    # Use Sherwood number to get a simpler format:
    if fix_sh:
        eq = eq.subs(map_sherwood).subs(Sh_g, 2*β)

    # Do not solve expression for ghost cell:
    if not solve_ghost:
        return eq

    # Identify c_G compatible with boundary fluxes:
    return expand(solve(eq, c_G)[0])
```

```python
# TODO: check the signs! As if all at LHS!
c_G_sym_w = manipulate_robin(+J_w - B_w)
c_G_sym_e = manipulate_robin(-J_e - B_e)

display(c_G_sym_w)
display(c_G_sym_e)
```

```python
coefs = get_fv_coefficients(c_G_sym_w, [c_P, c_inf], op=factor)
coefs
```

```python
coefs = get_fv_coefficients(c_G_sym_e, [c_P, c_inf], op=factor)
coefs
```

<div class="alert alert-info">

**Extended system formulation**

In the above formulation we solved for $c_G$, but in fact that may not be desirable. Solving for this variable means we should add a non-linear solution for each boundary condition before each system iteration. Since we are dealing with an already iterative problem (because coefficients are non-constant), it is worth adding the solution of $c_G$ in the same matrix as the main problem, strongly simplifying the code. This may slow down the first iterations until a first value of $c_G$ is found, but should not be a problem later (at least in 1-D).

</div>

```python
# TODO: check the signs! As if all at LHS!
eq_w = manipulate_robin(+J_w - B_w, solve_ghost=False)
eq_e = manipulate_robin(-J_e - B_e, solve_ghost=False)

display(eq_w)
display(eq_e)
```

```python
tabulate_coefs(eq_w, [c_G, c_P, c_inf])
```

```python
tabulate_coefs(eq_e, [c_G, c_P, c_inf])
```

The above equation tells us something interesting: we can use an extended system including a _ghost_ node to replace the convective equation by an equivalent diffusive flux term. That could already be expected from the original statement of type 3 boundary condition. The problem with this approach is that $c_{G}$ non-linearly depends on itself through the Sherwood number, and an additional equation needs to be solved to find its value (and the associated diffusivity) ahead of each solution iteration.

Now we are faced with a design choice: (1) we could introduce the previous equations for $c_{G}$ in boundary equations and workout the coefficients or (2) inser directly the corresponding value into the equation. The later approach leads to significantly simpler equations and is preferred here. After replacing $c_{B}$ in the boundary equation manipulate the expression to get

**TODO: fix these, incompatible with the above tables**

$$
\begin{align*}
\text{(west)}\qquad &
(\beta - 1)c_{G} + (\beta + 1)c_{P} = 2\beta{}c_{\infty}
%
\\[12pt]
%
\text{(east)}\qquad &
(\beta + 1)c_{G} + (\beta - 1)c_{P}= 2\beta{}c_{\infty}
\end{align*}
$$

and the first internal equation (second row of the matrix) gets the trivial form:

$$
\begin{align*}
\text{(west)}\qquad &
%
\left(c_{P}^{\tau}-c_{P}^{0}\right)\dfrac{\delta}{\tau}=
D_{e}\dfrac{c_{E}-c_{P}}{\delta} -
D_{g}\dfrac{c_{P}-c_{G}}{\delta}
%
\\[12pt]
%
\text{(east)}\qquad &
%
\left(c_{P}^{\tau}-c_{P}^{0}\right)\dfrac{\delta}{\tau}=
D_{g}\dfrac{c_{e}-c_{P}}{\delta} -
D_{w}\dfrac{c_{P}-c_{W}}{\delta}
\end{align*}
$$

```python
subs_w = [(c_W, c_G), (D_w, D_g)]
subs_e = [(c_E, c_G), (D_e, D_g)]

eq_w = get_problem_eq_zero(subs_rhs=subs_w).subs(map_fourier)
eq_e = get_problem_eq_zero(subs_rhs=subs_e).subs(map_fourier)

display(eq_w)
display(eq_e)
```

```python
tabulate_coefs(eq_w, variables=[c_P, c_E, c_W, c_0])
```

```python
tabulate_coefs(eq_e, variables=[c_P, c_W, c_E, c_0])
```

Reorganizing to get the linear formulation:

$$
\begin{align*}
\text{(west)}\qquad &
%
-\alpha_{g}^{\tau}c_{G}^{\tau}+
(1+\alpha_{e}^{\tau}+\alpha_{g}^{\tau})c_{P}^{\tau}
-\alpha_{e}^{\tau}c_{E}^{\tau}=c_{P}^{0}
%
\\[12pt]
%
\text{(east)}\qquad &
%
-\alpha_{w}^{\tau}c_{W}^{\tau}+
(1 + \alpha_{g}^{\tau}+\alpha_{w}^{\tau})c_{P}^{\tau}
-\alpha_{g}^{\tau}c_{G}^{\tau}=c_{P}^{0}
\end{align*}
$$


or in final coefficient mode as before

$$
\begin{align*}
\text{(west)}\qquad &
%
A_{G}c_{G}^{\tau}+A_{(0)}c_{P}^{\tau}+A_{E}c_{E}^{\tau}=c_{P}^{0}
%
\\[12pt]
%
\text{(east)}\qquad &
%
A_{W}c_{W}^{\tau}+A_{(n)}c_{P}^{\tau}+A_{G}c_{G}^{\tau}=c_{P}^{0}
\end{align*}
$$


In the above equation one may notice a preliminary introduction of cell numbering, we will come in detail to this point in the next section. For now simply notice that the following provides the coefficients mapping, where care has been taken to differentiate at what location _ghost_ cell values are evaluated when not self-evident.

$$
\begin{align*}
A_{(0)} &= 1 + \alpha_{e}^{\tau}+\alpha_{g}^{\tau}
\\[6pt]
A_{(n)} &= 1 + \alpha_{g}^{\tau}+\alpha_{w}^{\tau}
\\[6pt]
A_{G} &= -\alpha_{g}^{\tau}
\\[6pt]
A_{W} &= -\alpha_{w}^{\tau}
\\[6pt]
A_{E} &= -\alpha_{e}^{\tau}
\end{align*}
$$

With this we have gone through the full derivation of 1-D diffusion in solids. This enables the more convenient formulation of the problem as an iterative linear solution for time advancement.


<div class="alert alert-info">

**What if we used an immersed node?**

</div>

```python
# Define discrete BC equation:
J_w = D_b * (c_P - c_B) / (δ / 2)
B_w = h * (c_B - c_inf)
expr = Eq(J_w, B_w)

# Identify immersed node composition:
c_B_sol = solve(expr, c_B)[0]

# Reinject compatible c_B into flux:
J_w_use = expand(J_w.subs(c_B, c_B_sol))
J_w_use
```

```python
# Get full equation for the problem boundary:
eq_w = get_problem_eq_zero(J_w=J_w_use).subs(map_fourier)
eq_w
```

```python
eq_w.free_symbols
```

```python
coefs = get_fv_coefficients(eq_w, [c_P, c_E, c_0, c_inf], op=factor)
coefs
```
