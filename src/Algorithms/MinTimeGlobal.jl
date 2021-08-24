"""
    MinTimeGlobal <: AbstractSequencingAlgorithm

Algorithm that decides the sequence based on minimizing the time from the current
stop to the next stop.
"""
struct MinTimeGlobal{F} <: AbstractSequencingAlgorithm
    minfunc::F
end

MinTimeGlobal() = MinTimeGlobal(_min_length_path_exhaustive)

function solve(alg::MinTimeGlobal, route::AbstractRoute, times::TravelTimes; initial_stop=station(route))
    T = times.travel_times
    return solve(alg, route, T, initial_stop=initial_stop)
end

function solve(alg::MinTimeGlobal, route::AbstractRoute, T::AbstractMatrix;
               initial_stop=station(route))

    S = stops(route)
    num_stops = length(S)

    # salida
    route_id = name(route)
    seq = Vector{BareStop}()
    out = Sequence(route_id, seq)

    # para cada parada, encontrar la siguiente con el menor tiempo global
    if length(S) == 1
        push!(out, BareStop(name(S[1])))
        return out
    end

    _, result = alg.minfunc(T, S)
    for r in result
        push!(out, BareStop(name(r)))
    end
    return out
end
