"""
    MinTime <: AbstractSequencingAlgorithm

Algorithm that decides the sequence based on minimizing the time from the current
stop to the next stop.
"""
struct MinTime <: AbstractSequencingAlgorithm end

function solve(alg::MinTime, route::AbstractRoute, times::TravelTimes; initial_stop=station(route))
    T = times.travel_times
    return solve(alg, route, T, initial_stop=initial_stop)
end

function solve(alg::MinTime, route::AbstractRoute, T::AbstractMatrix;
               initial_stop=station(route))

    S = stops(route)
    num_stops = length(S)

    # salida
    route_id = name(route)
    seq = Vector{BareStop}()
    out = Sequence(route_id, seq)

    # encontrar la base y guardarla en el vector de salida
    x = initial_stop |> name
    push!(out, BareStop(x))

    # para cada parada, encontrar la siguiente con el menor tiempo
    while length(out) < num_stops
        s = sort(view(T, x, :))

        i = 2 # ignoro la posicion actual (tiempo = 0)
        y = s.dicts[1].keys[i]
        while (y ∈ out) # iterar hasta encontrar uno que no haya visitado
            i += 1
            i > length(s.dicts[1]) && return out
            y = s.dicts[1].keys[i]
        end
        push!(out, BareStop(y))
        x = y
    end

    return out
end
