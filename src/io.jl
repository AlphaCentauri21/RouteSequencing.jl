# =================================
# Parsing package data
# =================================

function _get_dimensions(Pdata)
    Pdim = Pdata["dimensions"]
    depth = Pdim["depth_cm"]
    height = Pdim["height_cm"]
    width = Pdim["width_cm"]
    return Dimensions(depth, height, width)
end

function _get_package_id(Pid)
    return Pid[11:end]
end

function _get_time_utc(time_utc)
    if !isa(time_utc, String) && isnan(time_utc)
        # packages do not have associated time_utc
        date = Date("")
        time = Time("")
    else
        date = Date(split(time_utc, " ")[1], DateFormat("y-m-d"))
        time = Time(split(time_utc, " ")[2])
    end
    return date, time
end

function _get_time_window(Pdata)
    start_time_utc = Pdata["time_window"]["start_time_utc"]
    start_date, start_time = _get_time_utc(start_time_utc)

    end_time_utc = Pdata["time_window"]["end_time_utc"]
    end_date, end_time = _get_time_utc(end_time_utc)

    time_window = TimeWindow(start_date, start_time, end_date, end_time)

    return time_window
end

function _get_scan_status(Pdata)
    status = 0
    if haskey(Pdata, "scan_status")
        val = Pdata["scan_status"]
        if val == "REJECTED"
            status = 1
        elseif val == "DELIVERY_ATTEMPTED"
            status = 2
        elseif val == "DELIVERED"
            status = 3
        end
    end
    return status
end

function _get_service_time(Pdata)
    return Pdata["planned_service_time_seconds"]
end

function parse_package_data(; file=joinpath("..", "data", "model_apply_inputs", "new_package_data.json"))
    package_data = read_json(file)
    return parse_package_data(package_data)
end

# receives a dictionary returned by read_json
function parse_package_data(data::Dict{String, Any})
    m = length(data)

    PT = Package
    ST = Task{BareStop, PT}
    RT = BareRoute{ST}

    routes = Vector{RT}(undef, m)

    i = 1
    for (R, D) in data  # loop over routes
        route_hash = _get_name(R)
        num_stops = length(D)
        stops = Vector{ST}(undef, num_stops)
        k = 1

        for (Sid, Sdata) in D  # loop over stops
            num_packages = length(Sdata) # number of packages in this stop
            packages = Vector{PT}(undef, num_packages)
            j = 1

            for (Pid, Pdata) in Sdata # loop over packages

                package_hash = _get_package_id(Pid)
                time_window = _get_time_window(Pdata)
                planned_service = _get_service_time(Pdata)
                package_dimensions = _get_dimensions(Pdata)
                status = _get_scan_status(Pdata)

                packages[j] = Package(package_hash, time_window, planned_service, package_dimensions, status)
                j += 1
            end
            stops[k] = Task(BareStop(Sid), packages)
            k += 1
        end
        routes[i] = BareRoute(route_hash, stops)
        i += 1
    end
    return routes
end

# =================================
# Parsing route data
# ================================

function _get_name(R)
    return R[9:end] # ignore RouteID
end

function _get_score(R)
    score = 0
    if haskey(R, "route_score")
        val = R["route_score"]
        if val == "Low"
            score = 1
        elseif val == "Medium"
            score = 2
        elseif val == "High"
            score = 3
        end
    end
    return score
end

function _get_zone(S)
    zone_str = S["zone_id"]
    if isa(zone_str, Float64) && isnan(zone_str)
        # stations do not have associated zone_id
        zone_id = Zone('0', "")
    else
        zone_id = Zone(zone_str)
    end
    return zone_id
end

function parse_route_data(; file=joinpath("..", "data", "model_apply_inputs", "new_route_data.json"))
    route_data = read_json(file)
    return parse_route_data(route_data)
end

# receives a dictionary returned by read_json
function parse_route_data(data::Dict{String, Any})
    m = length(data)
    routes = Vector{Route{Stop}}(undef, m)

    i = 1
    for (R, D) in data
        hex_hash = _get_name(R)
        station_code = D["station_code"]
        date = Date(D["date_YYYY_MM_DD"], DateFormat("y-m-d"))
        departure_time = Time(D["departure_time_utc"])
        capacity = D["executor_capacity_cm3"]

        Dstops = D["stops"]
        stops = Vector{Stop}(undef, length(Dstops))
        k = 1
        for (Sid, Sdata) in Dstops
            id = Sid
            lat = Sdata["lat"]
            lng = Sdata["lng"]
            stop_type = Sdata["type"] == "Station" ? 0 : 1
            zone_id = _get_zone(Sdata)
            stops[k] = Stop(id, lat, lng, stop_type, zone_id)
            k += 1
        end
        score = _get_score(D)
        routes[i] = Route(hex_hash, station_code, date, departure_time, capacity, stops, score)
        i += 1
    end
    return routes
end

# =================================
# Parsing travel times data
# =================================

function parse_travel_times(; file=joinpath("..", "data", "model_apply_inputs", "new_travel_times.json"))
    travel_times_data = read_json(file)
    return parse_travel_times(travel_times_data)
end

# receives a dictionary returned by read_json
function parse_travel_times(data::Dict{String, Any})
    m = length(data)
    travel_times = Vector{TravelTimes}(undef, m)

    i = 1
    for (R, O) in data # loop over routes

        hex_hash = _get_name(R)
        stop_names = collect(keys(O))
        num_stops = length(stop_names)

        M = zeros(Float64, num_stops, num_stops)
        times_matrix = NamedArray(M, (stop_names, stop_names))

        for orig in keys(O) # loop over origins
            for dest in keys(O[orig]) # loop over destinations
                times_matrix[orig, dest] = O[orig][dest]
            end
        end
        travel_times[i] = TravelTimes(hex_hash, stop_names, times_matrix)
        i += 1
    end
    return travel_times
end

# =================================
# Reading and writing JSON files
# =================================

"""
    read_json(src)

Read the JSON file in the string `src` and store it in a Julia dictionary.

### Notes

See https://discourse.julialang.org/t/dataframes-best-way-to-import-from-json-format-file/29946/6
"""
function read_json(src)
    # create variable to write the information
    d = Dict()
    open(src, "r") do f
        d = JSON.parse(f)  # parse and transform data
    end
    return d
end

function write_csv(R::Route)
    S = stops(R)

    # cada fila es (name, zone_id, latitud, longitud)
    xval = longitude.(S)
    yval = latitude.(S)
    names = name.(S)
    zones = zone.(S)
    A = hcat(names, zones, yval, xval)

    route_id = name(R)
    CSV.write(route_id * ".csv", DataFrame(A), writeheader=false)
end

# ==============================
# Methods to parse sequences
# ==============================

function parse_sequence(target="actual"; file=joinpath("..", "data", "model_apply_inputs", "new_actual_sequences.json"))
    sequence_data = read_json(file)
    return parse_sequence(sequence_data)
end

# receive a dictionary and return a vector of sequences
# use target="proposed" to parse our own sequences
function parse_sequence(data::Dict{String, Any}, target="actual")
    m = length(data)
    sequences = Vector{Sequence{BareStop}}(undef, m)

    i = 1
    for (R, D) in data
        route_hash = _get_name(R)
        actual_sequence = Vector{BareStop}(undef, length(D[target]))

        for (SeqId, SeqData) in D[target]
            # el vector de actual sequence ya queda ordenado
            actual_sequence[SeqData+1] = BareStop(SeqId)
        end

        sequences[i] = Sequence(route_hash, actual_sequence)
        i += 1
    end

    return sequences
end

function write_json_sequence(data; path=joinpath("..", "data", "model_apply_outputs", "proposed_sequences.json"))
    # dictionary to write
    dict = sequence_to_dict(data)

    # pass data as a json string (how it shall be displayed in a file)
    stringdata = JSON.json(dict)

    # write the file with the stringdata variable information
    open(path, "w") do f
        write(f, stringdata)
    end;
    return nothing
end

function sequence_to_dict(S::Sequence)
    dict = Dict{String, Any}()

    route_id = "RouteID_" * name(S)
    seq = Dict{String, Int}()
    for (i, stop) in enumerate(stops(S)) # loop over stops, assumed that the stops are sorted
        stop_id = name(stop)
        seq[stop_id] = i-1
    end
    dict[route_id] = Dict("proposed"=>seq)
    return dict
end

function sequence_to_dict(data::Vector{<:Sequence})
    dict = Dict{String, Any}()

    for S in data # loop over sequences
        route_id = "RouteID_" * name(S)
        seq = Dict{String, Int}()
        for (i, stop) in enumerate(stops(S)) # loop over stops, assumed that the stops are sorted
            stop_id = name(stop)
            seq[stop_id] = i-1
        end
        dict[route_id] = Dict("proposed"=>seq)
    end
    dict
end

function print_score(S::Sequence; src="evaluar.py")
    # convert the sequence to JSON format
    write_json_sequence(S)

    route_id = "RouteID_" * name(S)
    score = run(`python $src $route_id`)
    return score
end

get_score(S::Vector{<:Sequence}) = get_score.(S)

function get_score(S::Sequence)
    out = IOCapture.capture() do
                 print_score(S)
          end
    out_str = split(out.output[1:end-1], "\n")
    result = [parse(Float64, x) for x in out_str]
    return result[1]
end
