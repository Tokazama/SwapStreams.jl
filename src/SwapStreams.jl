module SwapStreams

@doc let path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    replace(read(path, String), r"^```julia"m => "```jldoctest README")
end SwapStreams

using MappedArrays
using Static
using IfElse

export BigEndian, LittleEndian, SwapStream

const LittleEndian = 0x01020304
const BigEndian = 0x04030201
const BoolType = Union{Bool,True,False}

bswap_array(x) = mappedarray(ntoh, hton, x)
function bswap_array!(x)
    @inbounds for i in eachindex(x)
        x[i] = bswap(x[i])
    end
end


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
struct SwapStream{S<:BoolType,IOType} <: IO
    swap::S
    io::IOType

    SwapStream(s::BoolType, io::IOType) where {IOType<:IO} = new{typeof(s),IOType}(s, io)
    SwapStream(io::IO) = SwapStream(true, io)
    SwapStream(file_endianness::UInt32, io) = SwapStream(file_endianness !== ENDIAN_BOM, io)
end

Base.seek(s::SwapStream, n::Integer) = seek(getfield(s, :io), n)
Base.position(s::SwapStream)  = position(getfield(s, :io))
Base.skip(s::SwapStream, n::Integer) = skip(getfield(s, :io), n)
Base.eof(s::SwapStream) = eof(getfield(s, :io))
Base.isreadonly(s::SwapStream) = isreadonly(getfield(s, :io))
Base.isreadable(s::SwapStream) = isreadable(getfield(s, :io))
Base.iswritable(s::SwapStream) = iswritable(getfield(s, :io))
Base.stat(s::SwapStream) = stat(getfield(s, :io))
Base.close(s::SwapStream) = close(getfield(s, :io))
Base.isopen(s::SwapStream) = isopen(getfield(s, :io))
Base.ismarked(s::SwapStream) = ismarked(getfield(s, :io))
Base.mark(s::SwapStream) = mark(getfield(s, :io))
Base.unmark(s::SwapStream) = unmark(getfield(s, :io))
Base.reset(s::SwapStream) = reset(getfield(s, :io))
Base.seekend(s::SwapStream) = seekend(getfield(s, :io))

Base.read(s::SwapStream, n::Int) = read(getfield(s, :io), n)

Base.read!(s::SwapStream, a::Array{Int8}) = read!(getfield(s, :io), a)
Base.read!(s::SwapStream, a::Array{UInt8}) = read!(getfield(s, :io), a)



function Base.read!(s::SwapStream, a::AbstractArray{T}) where {T}
    read!(getfield(s, :io), a)
    IfElse.ifelse(getfield(s, :swap), bswap_array!, identity)(a)
    return a
end

Base.read(s::SwapStream, ::Type{Int8}) = read(s.io, Int8)
Base.read(s::SwapStream, ::Type{UInt8}) = read(s.io, UInt8)

function Base.read(s::SwapStream, T::Union{Type{Float16}, Type{Float32}, Type{Float64}, Type{Int128}, Type{Int16}, Type{Int32}, Type{Int64}, Type{UInt128}, Type{UInt16}, Type{UInt32}, Type{UInt64}})
    IfElse.ifelse(s.swap, bswap, identity)(read(getfield(s, :io), T))
end

function Base.write(s::SwapStream, x::Array)
    write(getfield(s, :io), IfElse.ifelse(s.swap, bswap_array, identity)(x))
end
function Base.write(s::SwapStream, x::AbstractArray)
    write(getfield(s, :io), IfElse.ifelse(s.swap, bswap_array, identity)(x))
end
function Base.write(s::SwapStream, x::Union{Int16,UInt16,Int32,UInt32,Int64,UInt64,Int128,UInt128,Float16,Float32,Float64})
    write(getfield(s, :io), IfElse.ifelse(s.swap, bswap, identity)(x))
end

function Base.read!(s::SwapStream, r::Ref{T}) where {T}
    IfElse.ifelse(s.swap, _read_bswap!, _read_noswap!)(getfield(s, :io), r)
end

_read_noswap!(io, r::Ref{T}) where {T} = unsafe_read(io, r, UInt(sizeof(T)))
@generated function _read_bswap!(io, r::Ref{T}) where {T}
    e = Expr(:block)
    _bswap_expr!(e, T, zero(UInt))
    quote
        GC.@preserve r begin
            p = Base.unsafe_convert(Ptr{UInt8}, pointer_from_objref(r))
            unsafe_read(io, p, $(UInt(sizeof(T))))
            $e
        end
    end
end

function _bswap_expr!(e::Expr, ::Type{T}, offset::UInt) where {T}
    if Base.issingletontype(T)
        return nothing
    elseif isbitstype(T)
        if !(T <: UInt8)
            sz = sizeof(T)
            for i = 0:div(sz-1,2)
                push!(e.args, :(ptr_hi = p + $(offset + sz - i - 1)))
                push!(e.args, :(ptr_lo = p + $(offset + i)))
                push!(e.args, :(val_hi = unsafe_load(ptr_hi)))
                push!(e.args, :(val_lo = unsafe_load(ptr_lo)))
                push!(e.args, :(unsafe_store!(ptr_hi, val_lo)))
                push!(e.args, :(unsafe_store!(ptr_lo, val_hi)))
            end
        end
    else
        for i in 1:fieldcount(T)
            _bswap_expr!(e, fieldtype(T, i), fieldoffset(T, i) + offset)
        end
    end
end

end # module

