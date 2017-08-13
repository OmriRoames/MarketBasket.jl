module MarketBasket

export  Transactions,
        Cluster,
        getindex,
        length,
        items,
        refine!


include("clustering.jl")

end # module
