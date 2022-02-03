# SwapStreams.jl

[![Build Status](https://travis-ci.com/Tokazama/SwapStreams.jl.svg?branch=master)](https://travis-ci.com/Tokazama/SwapStreams.jl)
[![stable-docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://Tokazama.github.io/SwapStreams.jl/stable)
[![dev-docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://Tokazama.github.io/SwapStreams.jl/dev)
[![codecov](https://codecov.io/gh/Tokazama/SwapStreams.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/Tokazama/SwapStreams.jl)

From the documentation of `read(io::IO, T)` in the Base Julia library...

> Note that Julia does not convert the endianness for you. Use `ntoh` or `ltoh for this purpose.

...but `SwapStreams` does!

`SwapStreams` exports a simple type (`SwapStream`) that wraps any I/O stream.
Once constructed, a `SwapStream` will byte swap any read/write operation if appropriate.

```julia
julia> using SwapStreams

julia> s = SwapStream(IOBuffer());  # assume byte swapping is necessary

julia> write(s, [1:10...]);         # byte swap each element before writing to buffer

julia> seek(s, 0);

julia> read!(s.io, Vector{Int}(undef, 10))  # raw data from buffer
10-element Vector{Int64}:
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
10-element Vector{Int64}:
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

One can directly tell a `SwapStream` to byte swap or not by specifying `true` or `false` at the time of its construction.
Alternatively, one may specify whether the stream is big or little endian with the exported constants `BigEndian` and `LittleEndian`.
```julia
julia> using SwapStreams

julia> io = IOBuffer();

julia> SwapStream(true, io) == SwapStream(io)  # does byte swap
true

julia> SwapStream(false, io) ==    # explicitly do not byte swap
       SwapStream(ifelse(ENDIAN_BOM == BigEndian, BigEndian, LittleEndian), io)  # since stream has same endian type as system no swap
true
```

Note that we set the stream's endianness to the same as the system's so that it wouldn't perform byte swapping.

