import SwiftUI
import MyBossCore

/// A 1080×1080 pixel-styled card summarizing a finished campaign, rendered to
/// an image for sharing. Not shown on screen; drawn off-screen by ImageRenderer.
struct ShareCardView: View {
    let content: ShareCardContent
    let artwork: String

    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: UIImage(named: artwork) ?? UIImage())
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fill)
                .frame(width: 1080, height: 560)
                .clipped()
            VStack(spacing: 26) {
                Text(content.title)
                    .font(Pixel.font(58))
                    .foregroundStyle(Pixel.cream)
                    .multilineTextAlignment(.center)
                Text(content.tagline)
                    .font(Pixel.font(28))
                    .foregroundStyle(Pixel.cream.opacity(0.85))
                    .multilineTextAlignment(.center)
                Text(content.scoreLine)
                    .font(Pixel.font(40))
                    .foregroundStyle(Pixel.cream)
                Spacer(minLength: 0)
                Text("🤖 \(content.footer)")
                    .font(Pixel.font(30))
                    .foregroundStyle(Pixel.ai)
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 1080, height: 1080)
        .background(Pixel.panelDeep)
    }
}
