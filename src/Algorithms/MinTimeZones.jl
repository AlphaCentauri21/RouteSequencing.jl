"""
    MinTimeZones <: AbstractSequencingAlgorithm

Algorithm that decides the sequence based on minimizing the time from the current
stop to the next stop.
"""
struct MinTimeZones <: AbstractSequencingAlgorithm end


function get_waiting_list(route, seq)
    zones_list = Vector{String}(undef, length(route.stops))
    i = 1
    for S_seq in seq.stops 
        zones_list[i] = zone(route.stops[findfirst(x->x.id==S_seq.id, route.stops)])    
        i += 1
    end
    zones_list_small = filter(x->x!="0", zones_list)
    zones_array = [(i,count(x->x==i,zones_list_small)) for i in unique(zones_list_small)]
    return zones_array
end

function filter_travel_times(route, T, stop, waiting_list, zone_num)
    stops_per_zone = name.(filter(x->zone(x)==waiting_list[zone_num][1], route.stops))
    println("STOPSPERZONE :"*string(stops_per_zone))
    println("STOP: "*string(stop))
    #is_stop_involved = (findfirst((x,_)->x==stop,stops_per_zone)!=nothing)
    is_stop_involved = (findfirst(x->x==stop,stops_per_zone)!=nothing)
    println("STOPINVOLVED: "*string(is_stop_involved))
    if(is_stop_involved)
        travel_times_out = stops_per_zone
    else
        current_stop_name = [stop]
        travel_times_out = [current_stop_name; stops_per_zone]
    end
    return T[travel_times_out, stops_per_zone]
end

function solve(alg::MinTimeZones, route::AbstractRoute, times::TravelTimes; seq::Sequence, initial_stop=station(route))
    T = times.travel_times
    return solve_zones(alg, route, T, seq, initial_stop=initial_stop)
end

function solve_zones(alg::MinTimeZones, route::AbstractRoute, T::AbstractMatrix, Q::Sequence;
               initial_stop=station(route))

    S = stops(route)
    num_stops = length(S)

    # salida
    route_id = name(route)
    seq = Vector{BareStop}()
    out = Sequence(route_id, seq)
    
    # orden de zonas
    waiting_list = get_waiting_list(route, Q)
    #println(waiting_list)
    stops_per_zone = 0
    zone_num = 1

    # encontrar la base y guardarla en el vector de salida
    x = initial_stop |> name
    push!(out, BareStop(x))
    
    isFirstStop = true
    
    T_mod = T

    # para cada parada, encontrar la siguiente con el menor tiempo
    while length(out) < num_stops
        if(isFirstStop)
            s = sort(view(T, x, :))
            i = 2
        else
            s = sort(view(T_mod, x, :))
            i = 1
        end
            
        y = s.dicts[1].keys[i]
        while (y ∈ out) # iterar hasta encontrar uno que ya visite
            i += 1
            i == length(s.dicts[1]) && return out
            if(i<=length(s.dicts[1].keys))
                y = s.dicts[1].keys[i]  
            else
                break
            end
        end
        push!(out, BareStop(y))
        x = y
        stops_per_zone += 1
        if(stops_per_zone == waiting_list[zone_num][2])
            print(stops_per_zone)
            print(waiting_list[zone_num])
            zone_num += 1
            T_mod = filter_travel_times(route, T, x, waiting_list, zone_num)
            stops_per_zone = 0
            isFirstStop = false
        end
    end
    println("OUT:")
    println(out)
    return out
end
