
"""
IntersectingBoundaries()

Returns
-------
IntVert::Array{Float64, 2}            Contains all the intersecting points between all the boundaries of the simplices. Each row represents some intersecting point. Matrix of size D-by-N, where D = total number of intersecting points. Each row is an intersecting point.
ConvexExpIntVert::Array{Float64, 2}   Dimension D-by-(2N + 2), where D = total number of intersecting points. (2N + 2) corresponds to the number of vertices in each simplex * 2. The first n+1 columns correspond to the convex expansion coefficients of the intersecting points in terms of the vertices generating 's₁'. The remaining n+1 to (2N+2) columns correspond to the convex expansion coefficients of the intersecting points in terms of the vertices generating 's₂'. The faces of each simplex are numbered according to the column labels.
"""
function IntersectionOfBoundaries(s₁::Array{Float64, 2}, s₂::Array{Float64, 2},
                                    convexexp1in2::Array{Float64, 2},
                                    convexexp2in1::Array{Float64, 2},
                                    ordered_vertices1::Vector{Int},
                                    ordered_vertices2::Vector{Int},
                                    num1in2::Int,
                                    num2in1::Int,
                                    Ncomm::Int,
                                    tolerance::Float64)

    n::Int = size(s₁, 1)
    IntVert = Vector{Float64}(0)
    ConvexExpIntVert = Vector{Float64}(0)
    Z = zeros(Float64, 2*n+2, 1)

    if num1in2 <= num2in1
        # The last one is excluded because it corresponds to the whole simplex
        Labels = collect(2^num1in2:(2^(n+1)-2))

        #The one vertex boundaries correspond to the labels 2.^(0:n)
        #but since we discard all labels up to 2^(Nin(1))-1, then the one
        #vertex boundaries we still need to discard correspond to the labels
        #2.^(Nin(1):n), which correspond to the vertices with indices Nin(1)+1:n+1
        OneIndexLabels = (2 .^ (num1in2:n)).' -  2^num1in2 + 1
        Labels[OneIndexLabels] .= 0

        # Now all the boundaries are generated by 2 or more vertices
        # Notice that the first component of BoundaryBinaryLabels corresponds to the label 2^(Nin(1))+1
        BBL₁ = Binary(Labels[find(Labels)], n)
        StartingIndexBound2 = 2^num2in1 - 2^num1in2 + 1 - (num2in1 - num1in2)
        BBL₂ = view(BBL₁, StartingIndexBound2:size(BBL₁, 1), :)
    else
        # The last one is excluded because it corresponds to the whole simplex
        Labels = collect(2^num2in1:(2^(n+1) - 2)).'

        #The one vertex boundaries correspond to the labels 2.^(0:n)
        #but since we discard all labels up to 2^(Nin(1))-1, then the one
        #vertex boundaries we still need to discard correspond to the labels
        #2.^(Nin(1):n), which correspond to the vertices with indices Nin(1)+1:n+1
        OneIndexLabels = transpose(2 .^ (num2in1:n)) -  2^num2in1 + 1
        Labels[OneIndexLabels'] = zeros(size(OneIndexLabels))
        Labels = vec(Labels[find(Labels)])

        # Now all the boundaries are generated by 2 or more vertices. The first component of
        # BoundaryBinaryLabels corresponds to the label 2^(Nin(1))+1
        BBL₂ = Binary(Labels, n)
        StartingIndexBound1 = 2^num1in2 - 2^num2in1 + 1 - (num1in2 - num2in1)
        BBL₁ = view(BBL₂, StartingIndexBound1:size(BBL₂, 1), :)
    end

    N = size(BBL₁, 1) * size(BBL₂, 1)
    N2 = size(BBL₂, 1)

    Indices = 1:n+1

    @inbounds for i = 1:N
        index1 = ceil(Int, i/N2)
        index2 = i - (index1 - 1) * N2
        b1 = view(BBL₁, index1, :) # column vector
        b2 = view(BBL₂, index2, :)# column vector

        num_vert = sum(b1 + b2) # total number of vertices in both boundaries (including repeatitions)
        no_common_vert = true

        #b1[1:Ncomm] + b2[1:Ncomm]   contains, 0,1 or 2
        #If there is any vertex shared by the boundaries, a 2 will appear somewhere
        if Ncomm > 0
            no_common_vert = maximum(b1[1:Ncomm] + b2[1:Ncomm]) < 2
        end

        if num_vert <= n+2 && no_common_vert
            dim1 = sum(b1)
            dim2 = sum(b2)
            if dim1 >= dim2
                r = dim1
                s = dim2
                TargetVertices = view(s₂,:,:)

                refboundary = view(ordered_vertices1, Indices[find(b1)]) # column vec
                targetboundary = view(ordered_vertices2, Indices[find(b2)]) # column vec
                β = view(convexexp2in1, :, :)
                Γ = view(convexexp2in1, setdiff(1:n+1, refboundary), targetboundary)
                Rank= rank(Γ)
                Rank0 = rank([Γ;ones(1, s)])
                no_vanishing_column = minimum(maximum(abs.(Γ), 1))
                switch = 0
            else
                s = dim1
                r = dim2
                TargetVertices = view(s₁, :, :)
                refboundary = view(ordered_vertices2, Indices[find(b2)]) # column vec
                targetboundary = view(ordered_vertices1, Indices[find(b1)]) # column vec
                β = view(convexexp1in2, :, :)
                Γ = view(convexexp1in2, setdiff(1:n+1, refboundary), targetboundary)
                Rank= rank(Γ)
                Rank0 = rank([Γ; ones(1, s)])
                no_vanishing_column = minimum(maximum(abs.(Γ), 1))
                switch = 1
            end

            if Rank0-Rank == 1 && Rank == s-1 && no_vanishing_column > 0
                λ = QR(Γ,tolerance)

                α = [1 - ones(Int, 1, r-1) * view(β, refboundary[2:r], targetboundary);
                        view(β, refboundary[2:r], targetboundary)] * λ
                α[abs.(α) .<= tolerance] = 0

                #if some of these coefficients are negative the boundaries simply do
                #not intersect.
                #if some are zero, then the boundaries are not minimal and the intersecting point has already been
                #computed or will be computed as the intersection of minimal
                #boundaries.
                #This also rules out duplication of points
                if min(minimum(α), minimum(λ)) > 0 && sum(find(α)) > 1
                    # Filtering out non minimal boundaries
                    newpoint = view(TargetVertices, :, targetboundary)*λ
                    Z .= 0.0
                    if switch == 0
                        Z[refboundary] .= view(α, :)
                        Z[targetboundary .+ (n + 1)] .= view(λ, :)
                    else
                        Z[refboundary .+ (n + 1)] .= view(α, :)
                        Z[targetboundary] .= view(λ, :)
                    end
                    append!(IntVert,newpoint)
                    append!(ConvexExpIntVert, Z)
                end
            end
        end
    end


    return reshape(IntVert, n, div(length(IntVert), n)).',
           reshape(ConvexExpIntVert, 2*n+2, div(length(ConvexExpIntVert), 2*n+2)).'
end
