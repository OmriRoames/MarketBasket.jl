using Documenter, MarketBasket

makedocs(modules=[MarketBasket],
        doctest=true)

deploydocs(deps   = Deps.pip("mkdocs", "python-markdown-math"),
    repo = "git@github.com:OmriRoames/MarketBasket.jl.git",
    julia  = "0.5.2",
    osname = "linux")
