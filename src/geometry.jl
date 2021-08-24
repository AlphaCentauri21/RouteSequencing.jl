function point_cloud(R::AbstractRoute; remove_station=true)
    zone_idx, _, _ = split_by_zone(R, remove_station=remove_station)
    S = stops(R, remove_station=remove_station)

    lat = latitude.(S)
    long = longitude.(S)

    points = [Singleton([x, y]) for (x, y) in zip(long, lat)]

    out = [points[idx] for idx in zone_idx]

    return out
end

function path(R::AbstractRoute; remove_station=true)
    P = point_cloud(R, remove_station=remove_station)

    num_zones = length(P)
    out = [Vector{LineSegment{Float64, Vector{Float64}}}() for _ in 1:num_zones]

    for (k, points) in enumerate(P) # loop over zones
        m = length(points)
        X = Vector{LineSegment{Float64, Vector{Float64}}}()
        for i in 1:m-1 # loop over points for the current zone
            L = LineSegment(element(points[i]), element(points[i+1]))
            push!(out[k], L)
        end

        # add last segment
        if k < num_zones
            push!(out[k], LineSegment(element(points[m]), element(P[k+1][1])))
        end
    end
    return out
end

#=
FIXME add plot recipe

function plot_sequence(R; kwargs...)
    fig = plot()
    plot_sequence!(fig, R; kwargs...)
end

function plot_sequence!(fig, R; path_color=:black, path_style=:solid, path_width=1.0)
    vertices = point_cloud(R, remove_station=true);
    edges = path(R, remove_station=true)

    colores = Vector{String}()
    i = 1
    for (k, v) in Colors.color_names
        if mod(i, 10) == 0
            push!(colores, k)
        end
        i += 1
    end

    for i in 1:length(edges)
        plot!(fig, edges[i], marker=:none, seriestype=:path, lw=path_width, alpha=1., c=path_color, ls=path_style)
        plot!(fig, vertices[i], alpha=1, color=colores[i])

        #for (k, vi) in enumerate(vertices[i])
        #    s = vi.element
        #    annotate!(s[1], s[2], "$k", :black)
        #end
    end
    fig
end
=#
