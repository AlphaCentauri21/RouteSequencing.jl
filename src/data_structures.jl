# ============================
# Structs to define a zone
# ============================

"""
    Zone

Struct that defines a zone.

### Notes

The `zone_id` is a unique identifier denoting the geographical planning area
into which the stop falls. The numeral before the dash denotes a high-level
planning zone. The text after the dash denotes the subzone within the high-level zone.

### Examples

For example, "D-16.2C" corresponds to "D" = high-level planning zone
and "16.2C" a subzone.

```julia
julia> Z = Zone('D', "16.2C")
Zone('D', "16.2C")

julia> convert(String, Z)
"D16.2C"

julia> Zone("D16.2C")
Zone('D', "6.2C")
```

Other examples: "D-16.2C", "D-17.1C".
"""
struct Zone
    high::Char
    subzone::String
end

# assume that Z is of the correct form eg. "D-16.2C"
Zone(Z::String) = Zone(Z[1], Z[3:end])

Base.convert(::Type{String}, Z::Zone) = Z.high * Z.subzone;

# ============================
# Structs to define a package
# ============================

struct TravelTimes{MT}
    route_id::String
    stop_names::Vector{String}
    travel_times::MT
end

name(t::TravelTimes) = t.route_id
stop_names(t::TravelTimes) = t.stop_names
times_matrix(t::TravelTimes) = t.travel_times

# dimensions of a package
struct Dimensions
    depth::Float64
    height::Float64
    width::Float64
end

# expected time window for delivery of a package
struct TimeWindow
    start_date::Date
    start_time::Time
    end_date::Date
    end_time::Time
end

function is_defined(x::TimeWindow)
    got_start_date = x.start_date != Date("")
    got_end_date = x.end_date != Date("")
    got_start_time = x.start_time != Time("")
    got_end_time = x.end_time != Time("")

    return got_start_date && got_end_date && got_start_time && got_end_time
end

#=
abstract type AbstractScanStatus end

struct Delivered end <: AbstractScanStatus
struct Rejected end <: AbstractScanStatus
struct DeliveryAttempted end <: AbstractScanStatus
struct Unknown end <: AbstractScanStatus
=#

abstract type AbstractPackage end

struct Package <: AbstractPackage
    hex_hash::String
    time_window::TimeWindow
    planned_service::Float64 # UInt32 tiempo en entregar el paquete una vez llegado a la parada
    dimensions::Dimensions
    scan_status::Int64  # 0 = unknown, 1 = rejected, 2 = attempted, 3 = delivered
end

# by default the scan status is unknown (= 0)
Package(hex_hash::String, time_window::TimeWindow, planned_service::Float64, dimensions::Dimensions) = Package(hex_hash, time_window, planned_service, dimensions, 0)

name(P::Package) = P.hex_hash
time_window(P::Package) = P.time_window
has_time_window(P::Package) =  is_defined(P.time_window)

planned_service(P::Package) = P.planned_service
dimensions(P::Package) = P.dimensions

is_unknown(P::Package) = P.scan_status == 0
is_rejected(P::Package) = P.scan_status == 1
is_attempted(P::Package) = P.scan_status == 2
is_delivered(P::Package) = P.scan_status == 3

function volume(P::Package)
    d = P.dimensions
    return d.depth * d.height * d.width
end

# ============================
# Structs to define a stop
# ============================

abstract type AbstractStop end

# parada que solo contiene el nombre
struct BareStop <: AbstractStop
    id::String
end

name(x::BareStop) = x.id

"""
    Stop

Struct to store the information relative to a given stop.
"""
struct Stop <: AbstractStop
    id::String
    lat::Float64
    lng::Float64
    stop_type::Bool # 0 if Station, 1 if Dropoff
    zone_id::Zone
end

# constructor overloads
Stop(id::String, lat::Float64, lng::Float64, stop_type::Bool, zone_id::String) = Stop(id, lat, lng, stop_type, Zone(zone_id))
Stop(id::String, lat::Float64, lng::Float64, stop_type::Int, zone_id::String) = Stop(id, lat, lng, Bool(stop_type), Zone(zone_id))

# 0 if Station, 1 if Dropoff
is_station(x::Stop) = x.stop_type == 0
is_dropoff(x::Stop) = x.stop_type == 1;

latitude(x::Stop) = x.lat
longitude(x::Stop) = x.lng

zone(x::Stop) = convert(String, x.zone_id)
name(S::Stop) = S.id

function distance(X::AbstractStop, Y::AbstractStop)
    latX = latitude(X)
    latY = latitude(Y)
    lonX = longitude(X)
    lonY = longitude(Y)
    out = (latX - latY)^2 + (lonX - lonY)^2
    return sqrt(out)
end

# parada asociada a un vector de paquetes para entregar
struct Task{ST<:AbstractStop, PT<:AbstractPackage} <: AbstractStop
    stop::ST
    packages::Vector{PT}
end

packages(x::Task) = x.packages

# 0 if Station, 1 if Dropoff
is_station(x::Task) = is_station(x.stop)
is_dropoff(x::Task) = is_dropoff(x.stop)

latitude(x::Task) = latitude(x.stop)
longitude(x::Task) = longitude(x.stop)

zone(x::Task) = zone(x.stop)
name(x::Task) = name(x.stop)

# ================================
# Structs to define routes
# ================================

"""
    AbstractRoute

Abstract supertype for all route types.

### Notes

Requires to define the following fields:

`stops` -- vector of stops for the route
"""
abstract type AbstractRoute end

function station(R::AbstractRoute)
    S = R.stops
    idx = findall(is_station, S)
    if length(idx) == 0
        throw(ArgumentError("no station found"))
    elseif length(idx) > 1
        throw(ArgumentError("got more than one station"))
    end
    return S[idx[1]]
end

function stops(R::AbstractRoute; remove_station=false)
    S = R.stops
    if remove_station
        return filter(!is_station, S)
    else
        return S
    end
end

function zones(R::AbstractRoute; remove_station=false)
    Z = unique(zone.(R.stops))
    if remove_station
        return filter(x -> x != "0", Z)
    else
        return Z
    end
end

"""
    split_by_zone(R::AbstractRoute)

Return the set of stop indices associated to each zone.
"""
function split_by_zone(R::AbstractRoute; remove_station=true)

    S = stops(R, remove_station=remove_station)
    num_stops = length(S)

    zone_names = unique(zone.(S))
    num_zones = length(zone_names)

    # preallocate output vectors
    zone_idx = [Vector{Int}() for _ in 1:num_zones]
    stop_names = [Vector{String}() for _ in 1:num_zones]

    for i in 1:num_stops
        idx = findfirst(x -> x == zone(S[i]), zone_names)
        push!(zone_idx[idx], i)
        push!(stop_names[idx], name(S[i]))
    end
    return zone_idx, zone_names, stop_names
end

"""
    is_sorted_by_zone(R::AbstractRoute)

Return whether the stops in this route are sorted according to the zone.
"""
function is_sorted_by_zone(R::AbstractRoute)
    # TODO
end

"""
    Route

Struct to store the information relative to a given route.
"""
struct Route{ST<:AbstractStop} <: AbstractRoute
    hex_hash::String
    station_code::String
    date::Date
    departure_time::Time
    capacity::Float64 # UInt32
    stops::Vector{ST}
    score::Int64 # = 0 if the score has not been assigned, 1 = low, 2 = medium, 3 = high
end

# default constructor without score assigned
Route(hex_hash, station_code, date, departure_time, capacity, stops) = Route(hex_hash, station_code, date, departure_time, capacity, stops, 0)
name(R::Route) = R.hex_hash
capacity(R::Route) = R.capacity
score(R::Route) = R.score

is_score_unknown(R::Route) = R.score == 0
is_score_low(R::Route) = R.score == 1
is_score_medium(R::Route) = R.score == 2
is_score_high(R::Route) = R.score == 3

struct BareRoute{ST<:AbstractStop} <: AbstractRoute
    hex_hash::String
    stops::Vector{ST}
    score::Int64 # = 0 if the score has not been assigned, 1 = low, 2 = medium, 3 = high
end

BareRoute(hex_hash, stops) = BareRoute(hex_hash, stops, 0)

name(R::BareRoute) = R.hex_hash
score(R::BareRoute) = R.score
