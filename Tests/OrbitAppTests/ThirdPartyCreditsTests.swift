import Foundation
import Testing
#if canImport(Orbit)
@testable import Orbit
#else
@testable import OrbitApp
#endif

struct ThirdPartyCreditsTests {
    @Test
    func creditsMatchResolvedPackages() throws {
        let resolved = try loadPackageResolved()
        let credits = ThirdPartyCredits.all
        let creditIDs = credits.map(\.packageID)

        #expect(Set(creditIDs).count == credits.count)
        #expect(resolved.pins.count == credits.count)

        let creditsByID = Dictionary(uniqueKeysWithValues: credits.map { ($0.packageID, $0) })

        for pin in resolved.pins {
            let credit = creditsByID[pin.identity]
            #expect(credit != nil)

            guard let credit else { continue }

            #expect(credit.version == pin.state.version)
            #expect(credit.repositoryURL.absoluteString == normalizedRepositoryURL(from: pin.location))
            #expect(credit.licenseURL.absoluteString.contains("/blob/\(pin.state.revision)/"))
        }
    }

    @Test
    func creditsAreSortedAndUseValidMetadata() {
        let credits = ThirdPartyCredits.all
        let names = credits.map(\.name)
        let allowedLicenses = ["Apache License 2.0", "MIT License"]

        #expect(names == names.sorted(by: creditNameAscending))

        for credit in credits {
            #expect(credit.name.isEmpty == false)
            #expect(credit.licenseName.isEmpty == false)
            #expect(allowedLicenses.contains(credit.licenseName))
            #expect(credit.repositoryURL.scheme == "https")
            #expect(credit.licenseURL.scheme == "https")
            #expect(credit.repositoryURL.host?.isEmpty == false)
            #expect(credit.licenseURL.host == credit.repositoryURL.host)
            #expect(credit.licenseURL.lastPathComponent.isEmpty == false)
        }
    }

    private func loadPackageResolved(filePath: StaticString = #filePath) throws -> ResolvedPackageFile {
        let resolvedURL = URL(fileURLWithPath: "\(filePath)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Package.resolved")

        let data = try Data(contentsOf: resolvedURL)
        return try JSONDecoder().decode(ResolvedPackageFile.self, from: data)
    }

    private func normalizedRepositoryURL(from location: String) -> String {
        if location.hasSuffix(".git") {
            return String(location.dropLast(4))
        }
        return location
    }

    private func creditNameAscending(_ lhs: String, _ rhs: String) -> Bool {
        lhs.lowercased() < rhs.lowercased()
    }
}

private struct ResolvedPackageFile: Decodable {
    let pins: [ResolvedPackagePin]
}

private struct ResolvedPackagePin: Decodable {
    let identity: String
    let location: String
    let state: ResolvedPackageState
}

private struct ResolvedPackageState: Decodable {
    let revision: String
    let version: String
}
