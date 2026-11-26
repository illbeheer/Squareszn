import SwiftUI

/// Draws one block: the player's skin for base blocks, or the block set of the
/// current board-clear tier.
struct BlockView: View {
    let block: Block
    let size: CGFloat
    let skin: Skin

    var body: some View {
        ZStack {
            base
            specialIcon
        }
        .frame(width: size, height: size)
    }

    private var radius: CGFloat { size * 0.18 }

    @ViewBuilder private var base: some View {
        if block.tier < 0 {
            stone
        } else {
            switch Tiers.style(block.tier) {
            case 0: skinBlock
            case 1: crystal
            case 2: jelly
            case 3: neon
            case 4: lava
            case 5: gold
            default: galaxy
            }
        }
    }

    // MARK: Skin (base blocks)

    private var skinBlock: some View {
        let m = skin.motif(block.color &+ block.motif)
        return ZStack {
            RoundedRectangle(cornerRadius: radius)
                .fill(LinearGradient(colors: [m.top, m.bottom], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(Color.white.opacity(0.45), lineWidth: max(1, size * 0.06))
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(Color.black.opacity(0.18), lineWidth: max(1, size * 0.05))
                .mask(LinearGradient(colors: [.clear, .white], startPoint: .top, endPoint: .bottom))
            if !m.emoji.isEmpty && block.special == .none {
                Text(m.emoji)
                    .font(.system(size: size * 0.6))
                    .minimumScaleFactor(0.3)
            }
        }
    }

    // MARK: Stone (Season obstacles)

    private var stone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius)
                .fill(LinearGradient(colors: [Color(hex: 0x9AA3B2), Color(hex: 0x5E6675)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: max(1, size * 0.05))
            Path { p in
                p.move(to: CGPoint(x: size * 0.25, y: size * 0.3))
                p.addLine(to: CGPoint(x: size * 0.45, y: size * 0.5))
                p.addLine(to: CGPoint(x: size * 0.4, y: size * 0.72))
            }
            .stroke(Color.black.opacity(0.2), lineWidth: max(1, size * 0.04))
        }
    }

    // MARK: Block sets

    private var tint: Color { TierPalette.color(block.color) }

    private var crystal: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.1)
                .fill(LinearGradient(colors: [Color.white.opacity(0.95), tint.opacity(0.75), tint],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Path { p in
                p.move(to: CGPoint(x: size * 0.5, y: size * 0.12))
                p.addLine(to: CGPoint(x: size * 0.85, y: size * 0.5))
                p.addLine(to: CGPoint(x: size * 0.5, y: size * 0.88))
                p.addLine(to: CGPoint(x: size * 0.15, y: size * 0.5))
                p.closeSubpath()
            }
            .stroke(Color.white.opacity(0.8), lineWidth: max(1, size * 0.04))
            RoundedRectangle(cornerRadius: size * 0.1)
                .strokeBorder(Color.white.opacity(0.9), lineWidth: max(1, size * 0.05))
        }
    }

    private var jelly: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.34)
                .fill(LinearGradient(colors: [tint.opacity(0.65), tint], startPoint: .top, endPoint: .bottom))
            Ellipse()
                .fill(Color.white.opacity(0.55))
                .frame(width: size * 0.42, height: size * 0.22)
                .offset(x: -size * 0.14, y: -size * 0.22)
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: size * 0.1)
                .offset(x: size * 0.18, y: -size * 0.24)
        }
    }

    private var neon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius)
                .fill(Color.black.opacity(0.85))
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(tint, lineWidth: max(1.5, size * 0.09))
                .shadow(color: tint, radius: size * 0.12)
            RoundedRectangle(cornerRadius: radius * 0.6)
                .fill(tint.opacity(0.3))
                .padding(size * 0.28)
        }
    }

    private var lava: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius)
                .fill(LinearGradient(colors: [Color(hex: 0xFFE14D), Color(hex: 0xFF7A1A), Color(hex: 0xD62A1A)],
                                     startPoint: .top, endPoint: .bottom))
            Path { p in
                p.move(to: CGPoint(x: size * 0.15, y: size * 0.35))
                p.addLine(to: CGPoint(x: size * 0.4, y: size * 0.45))
                p.addLine(to: CGPoint(x: size * 0.55, y: size * 0.3))
                p.addLine(to: CGPoint(x: size * 0.85, y: size * 0.4))
                p.move(to: CGPoint(x: size * 0.4, y: size * 0.45))
                p.addLine(to: CGPoint(x: size * 0.45, y: size * 0.8))
            }
            .stroke(Color(hex: 0x5A1408).opacity(0.75), lineWidth: max(1, size * 0.05))
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(tint.opacity(0.6), lineWidth: max(1, size * 0.05))
        }
    }

    private var gold: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius)
                .fill(LinearGradient(colors: [Color(hex: 0xFFF3B0), Color(hex: 0xF2C14E), Color(hex: 0xB07A1A)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: radius * 0.6)
                .strokeBorder(Color.white.opacity(0.6), lineWidth: max(1, size * 0.04))
                .padding(size * 0.16)
            Circle()
                .fill(tint)
                .frame(width: size * 0.18)
        }
    }

    private static let starX: [CGFloat] = [-0.2, 0.22, 0.05, -0.05]
    private static let starY: [CGFloat] = [-0.18, -0.05, 0.22, 0.02]

    private var galaxy: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius)
                .fill(LinearGradient(colors: [tint, Color(hex: 0x2A0F5A), Color(hex: 0x0A0626)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: size * (i == 0 ? 0.1 : 0.06))
                    .offset(x: size * Self.starX[i], y: size * Self.starY[i])
            }
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: max(1, size * 0.04))
        }
    }

    // MARK: Specials

    @ViewBuilder private var specialIcon: some View {
        switch block.special {
        case .none:
            EmptyView()
        case .bomb:
            Text("💣").font(.system(size: size * 0.6))
        case .star:
            Text("⭐").font(.system(size: size * 0.6))
        case .zap:
            Text("⚡").font(.system(size: size * 0.6))
        case .gem:
            Text("💎").font(.system(size: size * 0.62))
        }
    }
}

/// A whole piece drawn at a given cell size.
struct PieceView: View {
    let piece: Piece
    let cell: CGFloat
    let skin: Skin
    var gap: CGFloat = 2

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(piece.shape.cells.enumerated()), id: \.offset) { i, p in
                BlockView(block: piece.block(i), size: cell - gap, skin: skin)
                    .position(x: (CGFloat(p.c) + 0.5) * cell, y: (CGFloat(p.r) + 0.5) * cell)
            }
        }
        .frame(width: CGFloat(piece.shape.width) * cell, height: CGFloat(piece.shape.height) * cell)
    }
}
