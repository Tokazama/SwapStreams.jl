module SwapStreams

@doc let path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    replace(read(path, String), r"^```julia"m => "```jldoctest README")
end SwapStreams

using MappedArrays
using Static

export BigEndian, LittleEndian, SwapStream

const LittleEndian = 0x01020304
const BigEndian = 0x04030201

const Bits = Union{Int16,UInt16,Int32,UInt32,Int64,UInt64,Int128,UInt128,Float16,Float32,Float64}
const BitsType = Union{Type{Float16},Type{Float32},Type{Float64},Type{Int128},Type{Int16},Type{Int32},Type{Int64},Type{UInt128},Type{UInt16},Type{UInt32},Type{UInt64}}
mapswap(x) = mappedarray(ntoh, hton, x)

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
"""
struct SwapStream{B<:Union{Bool,True,False},IOType} <: IO
    swap::B
    io::IOType

    SwapStream(b::B, io::IOType) where {B,IOType} = new{B,IOType}(b, io)
    SwapStream(io::IO) = SwapStream(static(true), io)
    function SwapStream(file_endianness::UInt32, io::IOType) where {IOType}
        SwapStream(file_endianness !== ENDIAN_BOM, io)
    end
end

is_swapping(x::SwapStream) = getfield(x, :swap)

Base.:(==)(x::SwapStream, y::SwapStream) = (is_swapping(x) == is_swapping(y)) && (x.io == y.io)

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

Base.read(s::SwapStream{S}, ::Type{Int8}) where {S} = read(s.io, Int8)
Base.read(s::SwapStream{S}, ::Type{UInt8}) where {S} = read(s.io, UInt8)

function Base.read!(s::SwapStream{S}, a::AbstractArray{T}) where {S,T}
    Static.ifelse(is_swapping(s), bswap!, identity)(read!(s.io, a))
end
function Base.read(s::SwapStream{S}, T::BitsType) where {S}
    Static.ifelse(is_swapping(s), bswap, identity)(read(s.io, T))
end

function Base.write(s::SwapStream{S}, x::Array) where {S}
    write(s.io, Static.ifelse(is_swapping(s), mapswap, identity)(x))
end
function Base.write(s::SwapStream{S}, x::AbstractArray) where {S}
    write(s.io, Static.ifelse(is_swapping(s), mapswap, identity)(x))
end

function Base.write(s::SwapStream{S}, x::Bits) where {S}
    write(s.io, Static.ifelse(is_swapping(s), bswap, identity)(x))
end
function Base.read!(s::SwapStream{S}, ref::Base.RefValue{<:NTuple{N,T}}) where {S,N,T}
    read!(s.io, ref)
    Static.ifelse(is_swapping(s), bswap!, identity)(ref)
    return ref
end

## internals
function bswap!(a::AbstractArray)
    @inbounds for i in eachindex(a)
        a[i] = bswap(a[i])
    end
    return a
end
function bswap!(r::Base.RefValue{T}) where {T}
    GC.@preserve r bswap_ptr!(Base.unsafe_convert(Ptr{UInt8}, pointer_from_objref(r)), T)
end

bswap_ptr!(p::Ptr, ::Type{T}) where {T<:Bits} = bswap_ptr!(p, static(sizeof(T)))
function bswap_ptr!(p::Ptr, t::Type{NTuple{N,T}}) where {N,T}
    for i in 1:N
        bswap_ptr!(p + fieldoffset(t, i), T)
    end
end

function bswap_ptr!(ptrlo::Ptr{UInt8}, ::StaticInt{2})
    ptrhi = ptrlo + 1
    vallo = Base.unsafe_load(ptrlo)
    valhi = Base.unsafe_load(ptrhi)
    Base.unsafe_store!(ptrlo, valhi)
    Base.unsafe_store!(ptrhi, vallo)
    return nothing
end
function bswap_ptr!(ptrlo::Ptr{UInt8}, ::StaticInt{4})
    ptrhi = ptrlo + 3
    vallo = Base.unsafe_load(ptrlo)
    valhi = Base.unsafe_load(ptrhi)
    Base.unsafe_store!(ptrlo, valhi)
    Base.unsafe_store!(ptrhi, vallo)
    bswap_ptr!(ptrlo+1, static(2))
end
function bswap_ptr!(ptrlo::Ptr{UInt8}, ::StaticInt{6})
    ptrhi = ptrlo + 5
    vallo = Base.unsafe_load(ptrlo)
    valhi = Base.unsafe_load(ptrhi)
    Base.unsafe_store!(ptrlo, valhi)
    Base.unsafe_store!(ptrhi, vallo)
    bswap_ptr!(ptrlo+1, static(4))
end
function bswap_ptr!(ptrlo::Ptr{UInt8}, ::StaticInt{8})
    ptrhi = ptrlo + 7
    vallo = Base.unsafe_load(ptrlo)
    valhi = Base.unsafe_load(ptrhi)
    Base.unsafe_store!(ptrlo, valhi)
    Base.unsafe_store!(ptrhi, vallo)
    bswap_ptr!(ptrlo+1, static(6))
end
function bswap_ptr!(ptrlo::Ptr{UInt8}, ::StaticInt{10})
    ptrhi = ptrlo + 9
    vallo = Base.unsafe_load(ptrlo)
    valhi = Base.unsafe_load(ptrhi)
    Base.unsafe_store!(ptrlo, valhi)
    Base.unsafe_store!(ptrhi, vallo)
    bswap_ptr!(ptrlo+1, static(8))
end
function bswap_ptr!(ptrlo::Ptr{UInt8}, ::StaticInt{12})
    ptrhi = ptrlo + 11
    vallo = Base.unsafe_load(ptrlo)
    valhi = Base.unsafe_load(ptrhi)
    Base.unsafe_store!(ptrlo, valhi)
    Base.unsafe_store!(ptrhi, vallo)
    bswap_ptr!(ptrlo+1, static(10))
end
function bswap_ptr!(ptrlo::Ptr{UInt8}, ::StaticInt{14})
    ptrhi = ptrlo + 13
    vallo = Base.unsafe_load(ptrlo)
    valhi = Base.unsafe_load(ptrhi)
    Base.unsafe_store!(ptrlo, valhi)
    Base.unsafe_store!(ptrhi, vallo)
    bswap_ptr!(ptrlo+1, static(12))
end
function bswap_ptr!(ptrlo::Ptr{UInt8}, ::StaticInt{16})
    ptrhi = ptrlo + 15
    vallo = Base.unsafe_load(ptrlo)
    valhi = Base.unsafe_load(ptrhi)
    Base.unsafe_store!(ptrlo, valhi)
    Base.unsafe_store!(ptrhi, vallo)
    bswap_ptr!(ptrlo+1, static(14))
end

end # module

