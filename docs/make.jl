using Documenter
using SwapStreams

makedocs(
    modules=[SwapStreams],
    format=Documenter.HTML(),
    repo="https://github.com/Tokazama/SwapStreams.jl/blob/{commit}{path}#L{line}",
    sitename="SwapStreams.jl",
    authors="Zachary P. Christensen",
)
