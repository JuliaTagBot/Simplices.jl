
function delaunaytest(n::Int, dim::Int, reps::Int)
    for i = 1:reps
        pts = rand(n, dim)
        Simplices.Delaunay.delaunayn(pts)
    end

    return true
end
