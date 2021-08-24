"""
    MinTimeZ <: AbstractSequencingAlgorithm

Algorithm that decides the sequence based on minimizing the time from the current
stop to the next stop, but subject to the additional constraint that in the final
sequence all zones are performed in order.
"""
struct MinTimeZ{T} <: AbstractSequencingAlgorithm
    algz::T
end

MinTimeZ() = MinTimeZ(MinTime())

function solve(alg::MinTimeZ, route::AbstractRoute, times::TravelTimes;
               initial_zone=zone(route.stops[1]),
               zones_list=zones(route, remove_station=false))

    route_id = name(route)
    T = times.travel_times

    algz = alg.algz

    # zonas que quedan por recorrer
    waiting_list = zones_list

    idx = findfirst(x -> x == initial_zone, waiting_list)

    sequence = Sequence(route_id, Vector{BareStop}())

    while length(waiting_list) > 0
        # filtrar solo las paradas de la zona actual
        actual_zone = waiting_list[idx]
        idx_stops = findall(s -> zone(s) == actual_zone, route.stops)

        # obtener las paradas y la matriz de tiempos asociada a esa zona
        subroute = BareRoute(route_id, route.stops[idx_stops])

        # indexamos la matriz de tiempos por nombres de parada
        name_stops = [name(s) for s in route.stops[idx_stops]]
        subtimes = view(T, name_stops, name_stops)

        # calcular la secuencia de acuerdo a los tiempos minimos
        initial_stop = _next_stop(alg, subroute)
        subsequence = solve(algz, subroute, subtimes, initial_stop=initial_stop)

        # append stops to the result
        for s in subsequence.stops
            push!(sequence, s)
        end

        deleteat!(waiting_list, idx)
    end

    return sequence
end

# simply return the first element of the list
function _next_stop(::MinTimeZ, subroute)
    return subroute.stops[1]
end
