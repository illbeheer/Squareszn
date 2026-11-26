import SwiftUI
import UIKit

struct Burst: Identifiable {
    let id = UUID()
    let point: GridPoint
    let block: Block
}

struct Popup: Identifiable {
    let id = UUID()
    let text: String
    let detail: String?
}

/// Runs one game (an Infinite run or one Season level) on top of GameState.
final class GameController: ObservableObject {
    enum Phase: Equatable { case playing, revive, ad, over, won }

    @Published var state: GameState
    @Published var phase: Phase = .playing
    @Published var ending = false
    @Published var bursts: [Burst] = []
    @Published var popup: Popup?
    @Published var tierBanner: Int?
    @Published var newBest = false
    @Published var levelReward = 0

    let store: PlayerStore
    let level: SeasonLevel?

    init(level: SeasonLevel?, store: PlayerStore) {
        self.level = level
        self.store = store
        self.state = GameState(level: level)
    }

    var inputLocked: Bool { phase != .playing || ending }

    /// Gold revive price doubles each time in the same run: 150, 300, 600…
    var reviveCost: Int { 150 << min(state.goldRevivesUsed, 6) }

    func restart() {
        state = GameState(level: level)
        phase = .playing
        ending = false
        bursts = []
        popup = nil
        tierBanner = nil
        newBest = false
        levelReward = 0
    }

    // MARK: Moves

    @discardableResult
    func drop(trayIndex: Int, at origin: GridPoint) -> Bool {
        guard !inputLocked, let res = state.place(trayIndex: trayIndex, at: origin) else { return false }
        store.addGold(res.gold)
        haptic(res.lines > 0 ? .medium : .light)

        if !res.cleared.isEmpty {
            let new = res.cleared.map { Burst(point: $0.0, block: $0.1) }
            bursts.append(contentsOf: new)
            let ids = Set(new.map(\.id))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                withAnimation(.easeOut(duration: 0.45)) {
                    self.bursts.removeAll { ids.contains($0.id) }
                }
            }
        }

        if res.lines > 0 {
            var detail: [String] = []
            if res.streak >= 2 { detail.append("Combo ×\(res.streak)") }
            if res.gemsCollected > 0 { detail.append("💎 ×\(res.gemsCollected)") }
            if res.starsCollected > 0 { detail.append("⭐ +\(5 * res.starsCollected) gold") }
            let words = ["", "", "Great!", "Amazing!", "Incredible!"]
            let title = res.lines >= 2 ? "\(words[min(res.lines, 4)]) +\(res.points)" : "+\(res.points)"
            showPopup(Popup(text: title, detail: detail.isEmpty ? nil : detail.joined(separator: "  ")))
        }

        if res.boardCleared {
            store.data.totalBoardClears += 1
            haptic(.heavy)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { tierBanner = res.newTier }
            let tier = res.newTier
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                if self.tierBanner == tier {
                    withAnimation(.easeOut(duration: 0.3)) { self.tierBanner = nil }
                }
            }
        }

        checkEnd()
        return true
    }

    private func showPopup(_ p: Popup) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { popup = p }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            if self.popup?.id == p.id {
                withAnimation(.easeOut(duration: 0.3)) { self.popup = nil }
            }
        }
    }

    private func checkEnd() {
        if state.isWon, let level {
            ending = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                self.levelReward = self.store.completeLevel(level)
                self.haptic(.heavy)
                withAnimation(.spring()) {
                    self.phase = .won
                    self.ending = false
                }
            }
        } else if state.isStuck {
            ending = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring()) {
                    self.phase = .revive
                    self.ending = false
                }
            }
        }
    }

    // MARK: Revive

    func reviveWithGold() {
        let cost = reviveCost
        guard phase == .revive, store.spend(cost) else { return }
        state.revive(withAd: false)
        withAnimation(.spring()) { phase = .playing }
    }

    func watchAd() {
        guard phase == .revive, !state.adReviveUsed else { return }
        phase = .ad
    }

    func adFinished(rewarded: Bool) {
        if rewarded {
            state.revive(withAd: true)
            withAnimation(.spring()) { phase = .playing }
        } else {
            phase = .revive
        }
    }

    func giveUp() {
        if level == nil { newBest = store.recordScore(state.score) }
        withAnimation(.spring()) { phase = .over }
    }

    /// Called when leaving mid-run, so an Infinite score still counts.
    func leave() {
        if level == nil { _ = store.recordScore(state.score) }
    }

    func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
