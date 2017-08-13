# implementation of `An Efficient Clustering Algorithm for Market Baskt Data Based
# on Small Large Ratios`


# lets start with generating some basic example Data

type Transactions
    ids::Vector{Int}
    items::Vector{Vector{Symbol}}
    labels::Vector{Int}
    item_set::Set{Symbol}
end


function Transactions(ids::Vector{Int}, items::Vector{Vector{Symbol}}, labels::Vector{Int})
    _item_set = Set{Symbol}()
    for item_list in items
        union!(_item_set, item_list)
    end
    Transactions(ids, items, labels, _item_set)
end


Base.getindex(transactions::Transactions, index::Int) = transactions.items[index]
Base.length(transactions::Transactions) = length(transactions.ids)

type Cluster
    inds::Vector{Int}
end

Base.length(cluster::Cluster) = length(cluster.inds)
Base.endof(cluster::Cluster) = cluster[length(cluster)]
Base.getindex(cluster::Cluster, index::Int) = cluster.inds[index]


# FIXME: rewrite method in a clearer way
""" Collect the set of items in the cluster of transaction """
items(cluster::Cluster, transactions::Transactions) = Set([i for t in transactions.items[cluster.inds] for i in t])
Base.push!(cluster::Cluster, idx::Int) = push!(cluster.inds, idx)
Base.pop!(cluster::Cluster) = pop!(cluster.inds)
Base.size(cluster::Cluster) = length(cluster.inds)
Base.deleteat!(cluster::Cluster, index::Int) = deleteat!(cluster.inds, index)
Base.isempty(cluster::Cluster) = isempty(cluster.inds)
function Base.show(cluster::Cluster, transactions::Transactions)
    for i in cluster.inds
        println(transactions[i])
    end
end

# function move!(idx::Int, from_cluster::Cluster, to_cluster::Cluster)
#     deleteat!(from_cluster.inds, findin(from_cluster.inds, idx))
#     push!(to_cluster.inds, idx)
# end


function counts(cluster::Cluster, transactions::Transactions)
    _counts = Dict{Symbol, Float64}()
    for item in items(cluster, transactions)
        for i in cluster.inds
            if (item in transactions.items[i])
                if haskey(_counts, item)
                    _counts[item] += 1.0
                else
                    _counts[item] = 1.0
                end
            end
        end
    end
    _counts
end

function support(cluster::Cluster, transactions::Transactions)
    N = float(size(cluster))
    _support = counts(cluster, transactions)
    for (item, f) in _support
        _support[item] = f/N
    end
    _support
end


function small_items(cluster::Cluster, max_ceiling::AbstractFloat, transactions::Transactions)
    _support = support(cluster, transactions)
    Set([item for (item, sup) in _support if sup <= max_ceiling])
end


function large_items(cluster::Cluster, min_support::AbstractFloat, transactions::Transactions)
    _support = support(cluster, transactions)
    Set([item for (item, sup) in _support if sup >= min_support])
end


function slr{I <: Integer, T <: AbstractFloat}(idx::I, cluster::Cluster, max_ceiling::T, min_support::T, transactions::Transactions)
    S = length(intersect(transactions[idx], small_items(cluster, max_ceiling, transactions)))
    L = length(intersect(transactions[idx], large_items(cluster, min_support, transactions)))
    if L == 0
        return Inf
    else
        return float(S)/float(L)
    end
end

function slr{T <: AbstractFloat}(cluster::Cluster, max_ceiling::T, min_support::T, transactions::Transactions)
    [slr(i, cluster, max_ceiling, min_support, transactions) for i in cluster.inds]
end

function intra_cluster_cost{C<:Cluster}(clusters::Vector{C}, max_ceiling::AbstractFloat, transactions::Transactions)
    intra_set = Set()
    for cluster in clusters
        _small_items = small_items(cluster, max_ceiling, transactions)
        union!(intra_set, _small_items)
    end
    length(intra_set)
end


function inter_cluster_cost{C<:Cluster}(clusters::Vector{C}, min_support::AbstractFloat, transactions::Transactions)
    inter_set = Set()
    tot_large_clusters_size = 0
    for cluster in clusters
        _large_items = large_items(cluster, min_support, transactions)
        union!(inter_set, _large_items)
        tot_large_clusters_size += length(_large_items)
    end
    tot_large_clusters_size - length(inter_set)
end


function total_cost{C<:Cluster, F<:AbstractFloat}(clusters::Vector{C}, max_ceiling::F, min_support::F, transactions::Transactions, weight=1.0)
    weight*intra_cluster_cost(clusters, max_ceiling, transactions) + inter_cluster_cost(clusters, min_support, transactions)
end

"""
    allocate!(clusters::Vector{Cluster}, transactions::Transactions, max_ceiling::Float64, min_support::Float64) -> nothing

Alollocate transactions to clusters
"""
function allocate!{C<:Cluster, F<:AbstractFloat}(clusters::Vector{C}, transactions::Transactions, max_ceiling::F, min_support::F)
    for i in transactions.ids
        println("transaction $i with items $(transactions[i])")
        new_cluster = Cluster([i])
        # start by creating a new cluster the the transaction
        if length(clusters) < 1
            push!(clusters, new_cluster)
            continue
        end

        costs_i = zeros(length(clusters))
        additional_cluster_cost = total_cost([clusters; new_cluster], max_ceiling, min_support, transactions)
        println("The cost of a new cluster for transaction $i is $additional_cluster_cost")
        for j in 1:length(clusters)
            println( "trying to add transaction $i to cluster $j")
            push!(clusters[j], i)
            println( "cost $(total_cost(clusters, max_ceiling, min_support, transactions))")
            costs_i[j] = total_cost(clusters, max_ceiling, min_support, transactions)
            pop!(clusters[j])
        end
        min_cost, j_min = findmin(costs_i)
        if min_cost <= additional_cluster_cost
            push!(clusters[j_min], i)
            println("Added transaction $i to cluster $j_min")
        else
            push!(clusters, Cluster([i]))
            println("Transaction $i is a new cluster $(length(clusters)))")
        end
    end
end

function best_cluster(slrs)
    min_inds = find(slrs .== minimum(slrs))

    for i in min_inds
        total_cost(clusters, max_ceiling, min_support, transactions)
    end
end


"""
    refine!(clusters::Vector{Cluster}, max_ceiling::Float64, min_support::Float64, transactions::Transactions, slr_threshold::Float64) -> nothing

Refine existing clusters according to small large ratio
"""
function refine!(clusters, max_ceiling, min_support, transactions, slr_threshold)
    excess_pool, clusters = get_excess_pool(clusters, max_ceiling, min_support, transactions, slr_threshold)
    while !isempty(excess_pool)
        transaction = pop!(excess_pool)
        slrs = [slr(transaction, cluster, max_ceiling, min_support, transactions) for cluster in clusters]
        @show transaction, slrs


        min_inds = find(slrs .== minimum(slrs))
        @show min_inds
        min_slr = slrs[1]
        @show min_slr
        if min_slr > slr_threshold
            push!(excess_pool,transaction)
        else
            _costs = zeros(length(min_inds))
            for (i, best_cluster_idx) in enumerate(min_inds)
                push!(clusters[best_cluster_idx], transaction)
                _costs[i] = total_cost(clusters, max_ceiling, min_support, transactions)
                pop!(clusters[best_cluster_idx])
            end
            @show _costs
            min_cost, min_cost_inds = findmin(_costs)
            println("add transaction $transaction to cluster $(min_inds[min_cost_inds])")
            push!(clusters[min_inds[min_cost_inds]], transaction)
        end

    end
    println("cost after refinement $(total_cost(clusters, max_ceiling, min_support, transactions))")
end

function get_excess_pool(clusters, max_ceiling, min_support, transactions, slr_threshold)
    excess_pool = Cluster([])
    for cluster in clusters
        for_deletion = []
        for (i, idx) in enumerate(cluster.inds)
            if slr(idx, cluster, max_ceiling, min_support, transactions) > slr_threshold
                push!(for_deletion, i)
                push!(excess_pool, idx)
            end
        end
        deleteat!(cluster.inds, for_deletion)
    end
    clusters = [cluster for cluster in clusters if !isempty(cluster)]
    excess_pool, clusters
end
#
#
# function cluster_transactions{F<:AbstractFloat}(transactions::Transactions, max_ceiling::F, min_support::F, α)
#     # start with one cluster
#     clusters = Cluster[transactions.inds]
#     refine!{C<:Cluster}(clusters::Vector{C})
# end


################## tests
# these are all of the transactions
# _transactions = Vector{Symbol}[[:b,:d], [:a,:b,:d], [:b,:c,:d], [:d,:f,:h], [:b,:g,:i],
#                 [:b,:i], [:a,:b,:i], [:b,:e,:i], [:b,:c,:e,:i], [:c,:i],
#                 [:d,:h], [:d,:h,:f], [:b,:c,:d,:f], [:h], [:d,:g,:h]]
#
# n_transactions = length(_transactions)
# transactions = Transactions(collect(1:n_transactions), _transactions, zeros(Int, n_transactions))
# @assert length(transactions) == 15
#
# # transactions.labels[1:5] = 1
# # transactions.labels[6:10] = 2
# # transactions.labels[11:15] = 3
#
# clusters = _clusters()
# refine!(clusters, max_ceiling, min_support, transactions, slr_threshold)

#
# c1 = Cluster([1,2,3,4,5])
# c2 = Cluster([6,7,8,9,10])
# c3 = Cluster([11,12,13,14,15])
#
# _counts_1 = counts(c1, transactions)
# _counts_2 = counts(c2, transactions)
# _counts_3 = counts(c3, transactions)
#
#
# supp_1 = support(c1, transactions)
# supp_2 = support(c2, transactions)
# supp_3 = support(c3, transactions)
#
# clusters = [c1, c2, c3]
# min_support = 0.6
# max_ceiling = 0.3
#
# @show intra_cluster_cost(clusters, max_ceiling, transactions)
# @show inter_cluster_cost(clusters, min_support, transactions)
# @show total_cost(clusters, max_ceiling, min_support, transactions)
