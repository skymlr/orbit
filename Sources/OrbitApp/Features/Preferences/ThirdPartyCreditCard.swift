import SwiftUI

struct ThirdPartyCreditCard: View {
    let credit: ThirdPartyCredit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(credit.name)
                        .orbitFont(.headline, weight: .semibold)

                    Text(credit.packageID)
                        .orbitFont(.caption, monospaced: true)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                CreditMetadataChip(title: "v\(credit.version)", usesMonospacedDigits: true)

            }

            HStack(spacing: 8) {
                Link(destination: credit.repositoryURL) {
                    Label("Project", systemImage: "link")
                }
                .buttonStyle(.orbitQuiet)

                Link(destination: credit.licenseURL) {
                    Label("License", systemImage: "doc.text")
                }
                .buttonStyle(.orbitQuiet)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: OrbitTheme.Radius.card, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OrbitTheme.Radius.card, style: .continuous)
                .stroke(OrbitTheme.Palette.glassBorder, lineWidth: 1)
        )
    }
}
