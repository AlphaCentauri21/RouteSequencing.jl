"""
    MinTimeFinal <: AbstractSequencingAlgorithm

The sequence construction proceeds in two stages:

1. Compute an ordering of the zones to be explored based on the spatial distances between
   the polygons obtained by taking the convex hull of the stops of each zone.

2. Once an ordering of the zones has been obtained, we compute the ordering of the stops within each zone.
   The optimization is such that the first stop of the current zone is optimized (to minimize travel time) together
   with all the stops of the next zone.

The function used in step 1 is `minzone`.
The function used in step 2 is `minfunc`.
"""
struct MinTimeFinal{F, Z} <: AbstractSequencingAlgorithm
    minfunc::F
    minzone::Z
end

MinTimeFinal() = MinTimeFinal(_min_length_path_mip, _min_zone)

_travel_times(T::AbstractMatrix) = T
_travel_times(T::TravelTimes) = T.travel_times

function solve(alg::MinTimeFinal, route::AbstractRoute, times;
               optimizer, initial_stop=station(route))

    T = _travel_times(times)
    S = stops(route)
    num_stops = length(S)
    minfunc = alg.minfunc
    minzone = alg.minzone

    # salida
    route_id = name(route)
    zones_list = minzone(route)

    seq = Vector{BareStop}()
    out = Sequence(route_id, seq)

    x = initial_stop |> name
    push!(out, BareStop(x))

    for Z in zones_list
        # FIXME use split_by_zone
        stops_per_zone = stops(route)[findall(x->zone(x)==Z, stops(route))]

        if length(stops_per_zone) == 1
            push!(out, BareStop(name(stops_per_zone[1])))

        else
            insert!(stops_per_zone, 1, stops(route)[findfirst(x->x.id==initial_stop.id, stops(route))])
            stops_str = [name(stops) for stops in stops_per_zone]

            _, result = minfunc(T, stops_per_zone, optimizer=optimizer)

            @inbounds for i in 2:length(result)
                push!(out, BareStop(name(result[i])))
            end

            # la parada inicial de la zona siguiente es aquella donde termine en la zona actual
            initial_stop = result[end] # stops(route)[findfirst(x->x.id==result[length(result)].id, stops(route))]
        end
    end
    return out
end
