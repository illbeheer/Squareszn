import Foundation

// Logic tests for Engine.swift. Run on a Mac (or in CI) with:
//   swiftc Squareszn/Engine.swift Tests/main.swift -o enginetests && ./enginetests

var failures = 0
func check(_ cond: @autoclosure () -> Bool, _ msg: String, line: Int = #line) {
    if !cond() { failures += 1; print("FAIL (line \(line)): \(msg)") }
}

func emptyBoard() -> [[Block?]] {
    [[Block?]](repeating: [Block?](repeating: nil, count: boardSize), count: boardSize)
}
let stone = Block(color: 0, motif: 0, tier: 0)

// Shapes
check(PieceShape(["XX"]).variants(rotate: true, mirror: false).count == 2, "duo has 2 orientations")
check(PieceShape(["XX", "XX"]).variants(rotate: true, mirror: true).count == 1, "square has 1 orientation")
check(PieceShape(["X.", "X.", "XX"]).variants(rotate: true, mirror: true).count == 8, "L has 8 orientations")
check(ShapeCatalog.groups(forTier: 0).count < ShapeCatalog.groups(forTier: 4).count, "board clears unlock shapes")
for g in ShapeCatalog.groups { check(!g.variants.isEmpty, "\(g.name) has variants") }

// Placing and clearing a row
do {
    var s = GameState(level: nil, seed: 1)
    s.board = emptyBoard()
    for c in 0..<7 { s.board[0][c] = stone }
    s.board[5][5] = stone
    s.tray = [Piece(shape: PieceShape(["X"]), color: 0, motif: 0, tier: 0), nil, nil]
    let res = s.place(trayIndex: 0, at: GridPoint(r: 0, c: 7))
    check(res != nil, "single fits")
    check(res?.clearedRows == [0], "row 0 cleared")
    check(res?.boardCleared == false, "board not cleared (stone left)")
    check(s.board[0].allSatisfy { $0 == nil }, "row emptied")
    check(s.tray.compactMap { $0 }.count == 3, "tray refilled after last piece")
    check(s.score == 1 + 10, "score = 1 cell + 10 for one line")
    check(s.goldEarned == 2, "2 gold per line")
}

// Clearing the whole board moves to the next tier
do {
    var s = GameState(level: nil, seed: 2)
    s.board = emptyBoard()
    for c in 0..<7 { s.board[3][c] = stone }
    s.tray = [Piece(shape: PieceShape(["X"]), color: 0, motif: 0, tier: 0),
              Piece(shape: PieceShape(["XX"]), color: 0, motif: 0, tier: 0), nil]
    let res = s.place(trayIndex: 0, at: GridPoint(r: 3, c: 7))
    check(res?.boardCleared == true, "board cleared")
    check(s.tier == 1, "tier advanced")
    check(s.tray[1]?.tier == 1, "waiting pieces switch to the new block set")
    check(s.score >= 300, "board clear bonus")
}

// Can't place on top of blocks or off the board
do {
    var s = GameState(level: nil, seed: 3)
    s.board = emptyBoard()
    s.board[0][0] = stone
    check(!s.canPlace(PieceShape(["XX"]), at: GridPoint(r: 0, c: 0)), "occupied")
    check(!s.canPlace(PieceShape(["XX"]), at: GridPoint(r: 0, c: 7)), "off board")
    check(s.canPlace(PieceShape(["XX"]), at: GridPoint(r: 0, c: 1)), "free")
}

// Bomb blasts its neighbours, chaining into another row
do {
    var s = GameState(level: nil, seed: 4)
    s.board = emptyBoard()
    for c in 0..<7 { s.board[4][c] = stone }
    s.board[4][3]?.special = .bomb
    s.board[5][3] = stone
    s.board[0][0] = stone
    s.tray = [Piece(shape: PieceShape(["X"]), color: 0, motif: 0, tier: 0), nil, nil]
    let res = s.place(trayIndex: 0, at: GridPoint(r: 4, c: 7))
    check(res?.blasts == 1, "bomb cleared one extra block")
    check(s.board[5][3] == nil, "block under bomb gone")
    check(s.board[0][0] != nil, "far block untouched")
}

// Stuck detection and revive
do {
    var s = GameState(level: nil, seed: 5)
    s.board = emptyBoard()
    for r in 0..<boardSize { for c in 0..<boardSize where (r + c) % 2 == 0 { s.board[r][c] = stone } }
    s.tray = [Piece(shape: PieceShape(["XX"]), color: 0, motif: 0, tier: 0), nil, nil]
    check(s.isStuck, "checkerboard blocks a duo")
    s.revive(withAd: true)
    check(s.adReviveUsed, "ad revive recorded")
    check(!s.isStuck, "revive leaves a playable tray")
    check(s.traySolvable, "revive deal can all be placed")
}

// Solver
do {
    // Empty: (0,7) and column 3 rows 1-4. A 5-long line only fits once a
    // single at (0,7) clears row 0 and opens (0,3).
    var b = emptyBoard()
    for r in 0..<boardSize { for c in 0..<boardSize { b[r][c] = stone } }
    b[0][7] = nil
    for r in 1...4 { b[r][3] = nil }
    let bb = BitBoard(b)
    let line5 = PieceShape(["X", "X", "X", "X", "X"])
    let single = PieceShape(["X"])
    check(bb.placements(line5).isEmpty, "line doesn't fit yet")
    check(BitBoard.solvable(bb, [line5, single]), "fits after the single clears row 0")
    check(!BitBoard.solvable(bb, [line5]), "line alone doesn't fit")
    check(BitBoard.solvable(BitBoard(emptyBoard()), [PieceShape(["XXX", "XXX", "XXX"]), PieceShape(["XXX", "XXX", "XXX"]), PieceShape(["XXXXX"])]), "empty board takes big pieces")
}

// Season levels
for n in 0..<Seasons.totalLevels {
    let level = Seasons.level(number: n)
    let board = Seasons.startingBoard(for: level)
    for r in 0..<boardSize { check(board[r].contains { $0 == nil }, "level \(n) row \(r) not full") }
    for c in 0..<boardSize { check((0..<boardSize).contains { board[$0][c] == nil }, "level \(n) col \(c) not full") }
    let gems = board.joined().filter { $0?.special == .gem }.count
    check(gems == level.gems, "level \(n) has \(level.gems) gems (got \(gems))")
    check(level.isGemGoal || level.targetScore > 0, "level \(n) has a goal")
    let s = GameState(level: level, seed: UInt64(n))
    check(!s.isStuck, "level \(n) starts playable")
    check(s.traySolvable, "level \(n) first deal can all be placed")
    check(!s.isWon, "level \(n) not won at start")
}

// Random play never crashes, and every deal can be fully placed
do {
    var games = 0, moves = 0, maxTier = 0, deals = 0, badDeals = 0
    for seed in 0..<200 {
        var s = GameState(level: nil, seed: UInt64(seed))
        var guardCount = 0
        while !s.isStuck && guardCount < 500 {
            guardCount += 1
            var moved = false
            for i in 0..<3 {
                guard let p = s.tray[i] else { continue }
                outer: for r in 0..<boardSize {
                    for c in 0..<boardSize where s.canPlace(p.shape, at: GridPoint(r: r, c: c)) {
                        s.place(trayIndex: i, at: GridPoint(r: r, c: c))
                        if s.tray.allSatisfy({ $0 != nil }) {
                            deals += 1
                            if !s.traySolvable { badDeals += 1 }
                        }
                        moved = true
                        break outer
                    }
                }
                if moved { break }
            }
            if !moved { break }
            moves += 1
        }
        maxTier = max(maxTier, s.tier)
        games += 1
    }
    print("random play: \(games) games, \(moves) moves, \(deals) deals, highest tier \(maxTier)")
    check(badDeals == 0, "\(badDeals) deals could not all be placed")
}

if failures == 0 {
    print("All engine tests passed")
} else {
    print("\(failures) failure(s)")
    exit(1)
}
