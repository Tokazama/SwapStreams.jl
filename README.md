# SwapStreams.jl

[![Build Status](https://travis-ci.com/Tokazama/SwapStreams.jl.svg?branch=master)](https://travis-ci.com/Tokazama/SwapStreams.jl)
[![stable-docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://Tokazama.github.io/SwapStreams.jl/stable)
[![dev-docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://Tokazama.github.io/SwapStreams.jl/dev)

```julia
julia> using SwapStreams

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

julia> io = IOBuffer();

julia> SwapStream{true}(io) == SwapStream(io)  # does byte swap
true

julia> SwapStream{false}(io) ==    # explicitly do not byte swap
       SwapStream(ENDIAN_BOM, io)  # since stream has same endian type as system no swap
true
```
