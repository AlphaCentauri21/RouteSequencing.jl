# =====================
# Utility functions
# =====================

# given an nxn matrix, return an (n+m)×(n+m) matrix with m new zero rows
# and m new zero columns
function _add_dimension(A::AbstractMatrix, m=1)
    n = size(A, 1)
    return vcat(hcat(A, zeros(n, m)), zeros(m, n+m))
end
