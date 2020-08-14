module SwapStreams

@doc let path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    replace(read(path, String), r"^```julia"m => "```jldoctest README")
end SwapStreams

using MappedArrays

export
    BigEndian,
    LittleEndian,
    SwapStream

const LittleEndian = 0x01020304
const BigEndian = 0x04030201

"""
    SwapStream([file_endianness],  io)

Given a file endian type and an IO stream returns a type that automatically byte
swaps to and from the appropriate endian type.

## Examples
```jldoctest
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
"""
struct SwapStream{S,IOType} <: IO
    io::IOType

    function SwapStream{S}(io::IOType) where {S,IOType<:IO}
        if S isa Bool
            return new{S,IOType}(io)
        else
            throw(TypeError(:SwapStream, Bool, S))
        end
    end

    SwapStream(io::IO) = SwapStream{true}(io)

    function SwapStream(file_endianness::UInt32, io::IOType) where {IOType}
        if file_endianness === ENDIAN_BOM
            return new{false,IOType}(io)
        else
            return new{true,IOType}(io)
        end
    end
end


Base.seek(s::SwapStream, n::Integer) = seek(s.io, n)
Base.position(s::SwapStream)  = position(s.io)
Base.skip(s::SwapStream, n::Integer) = skip(s.io, n)
Base.eof(s::SwapStream) = eof(s.io)
Base.isreadonly(s::SwapStream) = isreadonly(s.io)
Base.isreadable(s::SwapStream) = isreadable(s.io)
Base.iswritable(s::SwapStream) = iswritable(s.io)
Base.stat(s::SwapStream) = stat(s.io)
Base.close(s::SwapStream) = close(s.io)
Base.isopen(s::SwapStream) = isopen(s.io)
Base.ismarked(s::SwapStream) = ismarked(s.io)
Base.mark(s::SwapStream) = mark(s.io)
Base.unmark(s::SwapStream) = unmark(s.io)
Base.reset(s::SwapStream) = reset(s.io)
Base.seekend(s::SwapStream) = seekend(s.io)

Base.read(s::SwapStream, n::Int) = read(s.io, n)

Base.read!(s::SwapStream{S}, a::Array{Int8}) where {S} = read!(s.io, a)
Base.read!(s::SwapStream{S}, a::Array{UInt8}) where {S} = read!(s.io, a)

# TODO should this use ArrayInterface.ismutable?
function Base.read!(s::SwapStream{S}, a::AbstractArray{T}) where {S,T}
    read!(s.io, a)
    if S
        @inbounds for i in eachindex(a)
            a[i] = bswap(a[i])
        end
    end
    return a
end

Base.read(s::SwapStream, ::Type{Int8}) = read(s.io, Int8)

function Base.read(
    s::SwapStream{S},
    T::Union{Type{Float16}, Type{Float32}, Type{Float64}, Type{Int128}, Type{Int16}, Type{Int32}, Type{Int64}, Type{UInt128}, Type{UInt16}, Type{UInt32}, Type{UInt64}}
) where {S}

    if S
        return bswap(Base.read!(s.io, Ref{T}(0))[]::T)
    else
        return Base.read!(s.io, Ref{T}(0))[]::T
    end
end

function Base.read!(s::SwapStream{S}, ref::Base.RefValue{<:NTuple{N,T}}) where {S,N,T}
    if S
        return map(bswap, read!(s.io, ref)[])
    else
        return read!(s.io, ref)[]
    end
end

function Base.write(s::SwapStream{S}, x::Array) where {S}
    if S
        return write(s.io, mappedarray(ntoh, hton, x))
    else
        return write(s.io, x)
    end
end


function Base.write(s::SwapStream{S}, x::AbstractArray) where {S}
    if S
        return write(s.io, mappedarray(ntoh, hton, x))
    else
        return write(s.io, x)
    end
end

function Base.write(s::SwapStream{S}, x::T) where {S,T}
    if S
        return write(s.io, map(bswap, x))
    else
        return write(s.io, x)
    end
end

function Base.write(
    s::SwapStream{S},
    x::Union{Int16,UInt16,Int32,UInt32,Int64,UInt64,Int128,UInt128,Float16,Float32,Float64}
) where {S}

    if S
        return write(s.io, bswap(x))
    else
        return write(s.io, x)
    end
end

end # module
