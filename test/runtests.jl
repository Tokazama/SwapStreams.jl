
using Test
using SwapStreams
using Documenter

@test_throws TypeError SwapStream{1}(IOBuffer())

strue = SwapStream(IOBuffer())
sfalse = SwapStream{false}(IOBuffer())

@test !isreadonly(strue)
@test !isreadonly(sfalse)
@test iswritable(strue)
@test isopen(strue)
@test isopen(sfalse)
@test isreadable(strue)
@test isreadable(sfalse)
@test position(strue) == 0
@test position(sfalse) == 0
write(strue, 1)
write(sfalse, 1)
@test position(strue) == 8
@test position(sfalse) == 8
mark(strue)
mark(sfalse)
@test ismarked(strue)
@test ismarked(sfalse)
write(strue, [2, 3])
write(sfalse, [2, 3])
@test position(strue) == 24
@test position(sfalse) == 24
reset(strue)
reset(sfalse)
@test position(strue) == 8
@test position(sfalse) == 8
@test !ismarked(strue)
@test !ismarked(sfalse)

mark(strue)
@test ismarked(strue)
unmark(strue)
@test !ismarked(strue)

seekend(strue)
seekend(sfalse)
@test eof(strue)
@test eof(sfalse)
seek(strue, 0)
seek(sfalse, 0)
@test read(strue, Int) == 1
@test read(sfalse, Int) == 1


close(strue)
@test !iswritable(strue)


@test SwapStreams.is_swapping(SwapStream(ifelse(ENDIAN_BOM == BigEndian, LittleEndian, BigEndian), IOBuffer()))
@test SwapStreams.is_swapping(typeof(SwapStream(ifelse(ENDIAN_BOM == BigEndian, LittleEndian, BigEndian), IOBuffer())))
@test !SwapStreams.is_swapping(SwapStream(ifelse(ENDIAN_BOM == BigEndian, BigEndian, LittleEndian), IOBuffer()))


x = UInt8[1,2,3]
s = SwapStream(IOBuffer())
write(s, x)
seek(s, 0)
@test read(s, UInt8) === UInt8(1)
@test read!(s, Vector{UInt8}(undef, 2)) == x[2:3]

x = Int8[1,2,3]
s = SwapStream(IOBuffer())
write(s, x)
seek(s, 0)
@test read(s, Int8) === Int8(1)
@test read!(s, Vector{Int8}(undef, 2)) == x[2:3]

seek(s, 0)
@test read(s, 1) == [Int8(1)]
skip(s, 1)
@test read(s, 1) == [Int8(3)]

###
### does it work with abstract arrays
###
@testset "AbstractArray I/O" begin

    struct IntVector <: AbstractVector{Int}
        data::Vector{Int}
    end

    Base.length(x::IntVector) = length(x.data)
    Base.size(x::IntVector) = size(x.data)
    Base.getindex(x::IntVector, i::Int) = x.data[i]

    Base.iterate(x::IntVector) = iterate(x.data)
    Base.iterate(x::IntVector, state) = iterate(x.data, state)

    s = SwapStream(IOBuffer())
    x = IntVector([1,2,3]);
    write(s, x)
    seek(s, 0)
    @test read!(s, Vector{Int}(undef, 3)) == [1, 2, 3]

    s = SwapStream{false}(IOBuffer())
    x = IntVector([1,2,3]);
    write(s, x)
    seek(s, 0)
    @test read!(s, Vector{Int}(undef, 3)) == [1, 2, 3]
end

@testset "NTuple I/O" begin
    s = SwapStream{false}(IOBuffer())
    write(s, [1, 2, 3])
    seek(s, 0)
    r = Ref{NTuple{3,Int}}()
    read!(s, r) === (1, 2, 3)

    s = SwapStream{true}(IOBuffer())
    write(s, [1, 2, 3])
    seek(s, 0)
    r = Ref{NTuple{3,Int}}()
    read!(s, r) === (1, 2, 3)
end

@test stat(SwapStream{false}(open("runtests.jl"))).mode == 0x00000000000081a4

doctest(SwapStreams)

