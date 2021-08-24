# ========================================================
# Methods to solve the minimum time Hamiltonian problem
# ========================================================

abstract type HamiltonianSolver end

include("brute_force.jl")
include("ford_fulkerson.jl")
include("local.jl")
