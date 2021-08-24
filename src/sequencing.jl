# =============================
# Structs to define a sequence
# =============================

abstract type AbstractSequence end

# "result" of the algorithm
struct Sequence{ST<:AbstractStop} <: AbstractSequence
    hex_id::String
    stops::Vector{ST}
end

name(S::Sequence) = S.hex_id
stop_names(S::Sequence) = name.(S.stops)
stops(S::Sequence) = S.stops

function Base.:∈(stop_id::String, S::Sequence)
    return stop_id ∈ stop_names(S)
end

function Base.push!(S::Sequence, stop)
    push!(S.stops, stop)
end

function Base.length(S::Sequence)
    length(S.stops)
end

# ===================================
# Sequencing algorithms interface
# ===================================

abstract type AbstractSequencingAlgorithm end

# sort a route given by sequence
# we assume that the stops in R and in Q are equal if they
# have the same name
function apply_sequence!(R::AbstractRoute, Q::Sequence)
    S = R.stops
    aux = similar(S)

    for (i, qi) in enumerate(Q.stops)
        idx = findfirst(x -> name(x) == name(qi), S)
        aux[i] = S[idx]
    end
    S .= aux
    return S
end

function _min_zone(R::AbstractRoute; initial_zone=zone(R.stops[2]), tol=1e-4)
    
    # split stops by zone
    points = point_cloud(R)
    zone_names = zones(R, remove_station=true)
    num_zones = length(zone_names)

    # overapproximate with convex polygons
    P = [overapproximate(ConvexHullArray(pi), HPolygon, 1e-3) for pi in points]
    
    # preallocate output array
    out = Vector{String}() # FIXME use Vector{Zone} ??
    push!(out, initial_zone)

    # compute cost matrix
    M = Matrix{Float64}(undef, num_zones, num_zones)
    for i in 1:num_zones
        for j in 1:num_zones
            M[i, j] = hausdorff_distance(P[i], P[j], ε=tol)
        end
    end
    T = NamedArray(M, (zone_names, zone_names))
    
    # for each zone, find the next one that we didn't visit and that is closer
    x = initial_zone    #  convert(String, R.stops[2].zone_id)

    # iterate over zones
    while length(out) < num_zones
        s = sort(view(T, x, :))

        i = 2 # ignoro la posicion actual (tiempo = 0)
        y = s.dicts[1].keys[i]
        while (y ∈ out) # iterar hasta encontrar uno que no haya visitado
            i += 1
            i > length(s.dicts[1]) && return out
            y = s.dicts[1].keys[i]
        end
        push!(out, y)
        x = y
    end 
    
    return out
end
