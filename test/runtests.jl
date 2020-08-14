using Test
using SwapStreams
using Documenter

@test_throws TypeError SwapStream{1}(IOBuffer())

strue = SwapStream(IOBuffer())
sfalse = SwapStream{false}(IOBuffer())

@test !isreadonly(strue)
@test !isreadonly(sfalse)
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
seekend(strue)
seekend(sfalse)
@test eof(strue)
@test eof(sfalse)
seek(strue, 0)
seek(sfalse, 0)
@test read(strue, Int) == 1
@test read(sfalse, Int) == 1

doctest(SwapStreams)


