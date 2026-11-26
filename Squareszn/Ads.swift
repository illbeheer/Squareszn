import SwiftUI

// Rewarded ad used for the free revive.
//
// This is a stand-in that plays a short countdown, so the revive flow works
// with no ad account. To show real ads, add an ad SDK (for example Google
// Mobile Ads / AdMob), load a rewarded ad, and call `onFinish(true)` from its
// "user earned reward" callback and `onFinish(false)` if it's dismissed early.

struct RewardedAdView: View {
    /// true = watched to the end (grant the reward), false = skipped.
    let onFinish: (Bool) -> Void

    init(onFinish: @escaping (Bool) -> Void) { self.onFinish = onFinish }

    private static let length = 5
    @State private var remaining = RewardedAdView.length
    @State private var spin = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1D2B64), Color(hex: 0xF8CDDA)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                HStack {
                    Text("AD")
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.yellow, in: Capsule())
                        .foregroundColor(.black)
                    Spacer()
                    if remaining > 0 {
                        Button("Skip (no revive)") { onFinish(false) }
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal)

                Spacer()

                ZStack {
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 10)
                            .fill(TierPalette.color(i * 2))
                            .frame(width: 44, height: 44)
                            .offset(x: i % 2 == 0 ? -26 : 26, y: i < 2 ? -26 : 26)
                    }
                }
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: spin)

                Text("Your ad here")
                    .font(.title.bold())
                    .foregroundColor(.white)
                Text("Placeholder rewarded ad")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                if remaining > 0 {
                    Text("Revive in \(remaining)…")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.bottom, 40)
                } else {
                    Button {
                        onFinish(true)
                    } label: {
                        Label("Claim revive", systemImage: "heart.fill")
                            .font(.title3.bold())
                            .padding(.horizontal, 30).padding(.vertical, 14)
                            .background(Color.green, in: Capsule())
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 40)
                }
            }
            .padding(.top, 20)
        }
        .onAppear { spin = true }
        .onReceive(timer) { _ in
            if remaining > 0 { remaining -= 1 }
        }
    }
}
