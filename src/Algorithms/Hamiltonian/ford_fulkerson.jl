# solve the minimum length Hamiltonian problem; in this algorithm, the
# initial and final stops are *fixed* and the feasible region consists of alternating
# intermediate stops
struct MIP_IF <: HamiltonianSolver end

min_path(T, stops, ::MIP_IF) = _min_length_path_mip(T, stops)

function _min_length_path_mip(T::AbstractMatrix, stops::Vector{<:AbstractStop}; optimizer)
     stop_names = [name(s) for s in stops]
     _min_length_path_mip(T, stop_names, optimizer=optimizer)
end

# solve the minimum length Hamiltonian problem using a MIP formulation
# *where the first and last stops are fixed*
function _min_length_path_mip(T::AbstractMatrix, stops::Vector{<:String}; optimizer)
    M = view(T, stops, stops)

    model = Model(optimizer)

    # number of stops
    N = length(stops)

    # binary decision variables: 1 if x_{st} stop s goes to stop t and 0 otherwise
    @variable(model, x[1:N, 1:N], Bin)

    # cost function
    @objective(model, Min, sum(x[s, t] * M[s, t] for s=1:N, t=1:N))

    for s = 1:N  # loop over source stop
        # no edge reaches the initial stop
        @constraint(model, x[s, 1] == 0)

        # no self-loops
        @constraint(model, x[s, s] == 0)

        # each stop arrives to one and only one stop (unless the last one)
        if s < N
            @constraint(model, sum(x[s, t] for t in 2:N) == 1)
        end
    end

    # can't jump directly from first to last stop
    @constraint(model, x[1, N] == 0)

    for t = 1:N  # loop over target stop
        # no edge after the final stop
        @constraint(model, x[N, t] == 0)

        # each stop receives one and only one edge (unless the first stop)
        if t > 1
           @constraint(model, sum(x[s, t] for s in 1:N) == 1)
        end
    end

    # no repetitions (not required in ppple)
    for  s= 1:N, t = 1:N
        @constraint(model, x[s, t] + x[t, s] <= 1)
    end

    optimize!(model)

    while !is_mip_solved(model, x)
        optimize!(model)
    end

    minvalue = JuMP.objective_value(model)
    Mpath = JuMP.getvalue.(x)

    result = similar(stops)
    result[1] = stops[1]
    row = 1
    for i in 1:N-1
        idx = findfirst(==(1,), view(Mpath, row, :))
        @assert !isnothing(idx)
        result[i+1] = stops[idx]
        row = idx
    end
    return minvalue, result
end

# Check whether the Hamiltonian problem is solved,
# which requires that there is a unique chain of length N
# if there is no such chain => we add it as a constraint to the problem
#
# For instance, if there are 5 stops we may find a chain of length 3:
#
# 3 -> 4 -> 3
# 1 -> 2 -> 5 : x[1, 2] + x[2, 5] = 2
# The idea is to add a new constraint that excludes the chain 1 -> 2 -> 5
function is_mip_solved(model, x)
    minvalue = JuMP.objective_value(model)
    Mpath = JuMP.getvalue.(x)

    # check if the problem is solved <=> the path starting at 1 covers all stops
    N = size(Mpath, 1)
    chain_idx = Vector{Int}()
    push!(chain_idx, 1)
    while true
        idx = findfirst(==(1,), view(Mpath, chain_idx[end], :))
        push!(chain_idx, idx)
        idx == N && break
    end

    if length(chain_idx) < N
        @constraint(model, sum(x[chain_idx, chain_idx]) <= length(chain_idx) - 2)
        return false
    end
    return true
end

# solve the minimum length Hamiltonian problem; in this algorithm, the
# initial stop is *fixed*, and optimization is based on the remaining m-1 stops
struct MIP_I <: HamiltonianSolver end

# TODO add MIP_I naive implementation is to iteratively call MIP_IF for each
# of the remaining n - 1 stops
