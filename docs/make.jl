using Documenter
using SwapStreams

makedocs(
    modules=[SwapStreams],
    format=Documenter.HTML(),
    repo="https://github.com/JuliaNeuroscience/NeuroCore.jl/blob/{commit}{path}#L{line}",
    sitename="NeuroCore.jl",
    authors="Zachary P. Christensen",
)