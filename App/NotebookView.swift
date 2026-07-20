import SwiftUI
import MyBossCore

/// The player's collection: endings discovered, comebacks learned, and a few
/// fun lifetime records. Reached from the title screen.
struct NotebookView: View {
    @Environment(\.dismiss) private var dismiss
    private let endings = (try? EndingCatalog.loadDefault()) ?? []
    private var found: Set<String> { Set(UserDefaults.standard.stringArray(forKey: "endingsFound") ?? []) }
    private var learned: Int { (UserDefaults.standard.stringArray(forKey: "learnedProvocations") ?? []).count }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("📓 NOTEBOOK")
                    .font(Pixel.font(20))
                    .foregroundStyle(Pixel.cream)

                let rows = NotebookContent.endings(endings, found: found)
                Text("ENDINGS \(rows.filter(\.found).count)/\(rows.count)")
                    .font(Pixel.font(12))
                    .foregroundStyle(Pixel.creamDim)
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(rows) { row in endingCard(row) }
                }

                statsPanel
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Pixel.panelDeep)
        .overlay(alignment: .topTrailing) {
            Button("✕") { dismiss() }
                .font(Pixel.font(16))
                .foregroundStyle(Pixel.cream)
                .padding(16)
        }
    }

    private func endingCard(_ row: NotebookEnding) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Image(uiImage: UIImage(named: artwork(row.id)) ?? UIImage())
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 90)
                    .frame(maxWidth: .infinity)
                    .clipped()
                if !row.found {
                    Pixel.bg.opacity(0.82)
                    Text("？")
                        .font(Pixel.font(28))
                        .foregroundStyle(Pixel.cream)
                }
            }
            .frame(height: 90)
            .clipped()
            .border(Pixel.border, width: 3)
            Text(row.found ? row.title.uppercased() : "LOCKED")
                .font(Pixel.font(9))
                .foregroundStyle(row.found ? Pixel.cream : Pixel.creamDim)
                .multilineTextAlignment(.center)
        }
    }

    private func artwork(_ id: String) -> String {
        EndingArt.image(for: endings.first { $0.id == id } ?? endings[0])
    }

    private var statsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OFFICE RECORDS").font(Pixel.font(12)).foregroundStyle(Pixel.creamDim)
            statLine("Campaigns survived", Stats.value(.campaignsCompleted))
            statLine("Meeting duels won", Stats.value(.duelsWonTotal))
            statLine("Printers persuaded", Stats.value(.microGamesWon))
            statLine("Comebacks learned ★", learned)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Pixel.panel)
        .border(Pixel.border, width: 3)
    }

    private func statLine(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label).font(Pixel.font(11)).foregroundStyle(Pixel.cream)
            Spacer()
            Text("\(value)").font(Pixel.font(13)).foregroundStyle(Pixel.human)
        }
    }
}
