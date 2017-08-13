using MarketBasket
using Base.Test

function _transactions()
      Vector{Symbol}[[:b,:d], [:a,:b,:d], [:b,:c,:d], [:d,:f,:h], [:b,:g,:i],
                    [:b,:i], [:a,:b,:i], [:b,:e,:i], [:b,:c,:e,:i], [:c,:i],
                    [:d,:h], [:d,:h,:f], [:b,:c,:d,:f], [:h], [:d,:g,:h]]
end

function _clusters()
    c1 = Cluster([1,2,3,4,5])
    c2 = Cluster([6,7,8,9,10])
    c3 = Cluster([11,12,13,14,15])
    [c1,c2,c3]
end

import Base: ==
==(c1::Cluster, c2::Cluster) = sort(c1.inds) == sort(c2.inds)

@testset "Clustering" begin
    n_transactions = length(_transactions())
    transactions = Transactions(collect(1:n_transactions), _transactions(), zeros(Int, n_transactions))
    @test length(transactions) == 15

    @test transactions[6] == [:b,:i] 

    min_support = 0.6
    max_ceiling = 0.3
    slr_threshold = 1.5
    clusters = _clusters()
    refine!(clusters, max_ceiling, min_support, transactions, slr_threshold)
    @test clusters[1] == Cluster([1,2,3,13])
    @test clusters[2] == Cluster([6,7,8,9,10,5])
    @test clusters[3] == Cluster([11,12,15,14,4])
end
