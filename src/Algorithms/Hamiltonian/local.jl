struct Local <: HamiltonianSolver end

min_path(T, stops, ::Local; kwargs...) = _min_length_path_local(T, stops; kwargs...)

function _min_length_path_local(T::TravelTimes, stops::Vector{<:AbstractStop}; kwargs...)
    _min_length_path_local(T.travel_Times, stops; kwargs...)
end

function _min_length_path_local(T::AbstractMatrix, stops::Vector{<:AbstractStop}; initial_stop=nothing)
    # initial stop
    x = isnothing(initial_stop) ? stops[1] : initial_stop
    x = BareStop(name(x))
    num_stops = length(stops)

    # prellocate output
    out = Vector{BareStop}()

    # store first stop in the output sequence
    push!(out, x)

    while length(out) < num_stops
        s = sort(view(T, name(x), :))

        i = 2 # ignore current position
        y = s.dicts[1].keys[i] |> BareStop
        while y ∈ out # iterate until finding a stop that hasn't been visited
            i += 1
            i > length(s.dicts[1]) && return out
            y = s.dicts[1].keys[i] |> BareStop
        end
        push!(out, y)
        x = y
    end
    return out
end
