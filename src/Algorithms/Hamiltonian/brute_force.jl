struct BruteForce <: HamiltonianSolver end

min_path(T, stops, ::BruteForce) = _min_length_path_exhaustive(T, stops)

function _min_length_path_exhaustive(T::TravelTimes, stops::Vector{<:AbstractStop})
    _min_length_path_exhaustive(T.travel_Times, stops)
end

# sdlve the minimum length hamiltonian path by brute-force search
# computes the minimum path of the given stops, starting from the first stop given
# in `stops` and finishing in any other other stops
function _min_length_path_exhaustive(T::AbstractMatrix, stops::Vector{<:AbstractStop})
    p0 = stops[1]

    # FIXME refactor
    stop_names = [name(s) for s in stops]
    M = view(T, stop_names, stop_names)

    perm = permutations(stops[2:end])

    num_stops = length(stops)

    minvalue = Inf
    local result
    for p in perm
        value = M[name(p0), name(p[1])]
        for i in 1:num_stops-2
            value += M[name(p[i]), name(p[i+1])]
        end

        if value < minvalue
            minvalue = value
            result = vcat(p0, p)
        end
    end

    return (minvalue, result)
end
