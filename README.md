# SwapStreams.jl


```julia
julia> using SwapStream

julia> s = SwapStream(IOBuffer());  # assume byte swapping is necessary

julia> write(s, [1:10...]);         # byte swap each element before writing to buffer

julia> seek(s, 0);

julia> read!(s.io, Vector{Int}(undef, 10))  # raw data from buffer
10-element Array{Int64,1}:
  72057594037927936
 144115188075855872
 216172782113783808
 288230376151711744
 360287970189639680
 432345564227567616
 504403158265495552
 576460752303423488
 648518346341351424
 720575940379279360

julia> seek(s, 0);

julia> read!(s, Vector{Int}(undef, 10))  # byte swapped data from buffer
10-element Array{Int64,1}:
  1
  2
  3
  4
  5
  6
  7
  8
  9
 10

```

A `SwapStream` can be constructed as follows
```julia
julia> using SwapStreams

julia> io = IOBuffer()

julia> SwapStream{true}(io) == SwapStream(io)  # does byte swap
true

julia> SwapStream{false}(io) == SwapStream(ENDIAN_BOM, io)  # doesn't byte swap
true
```