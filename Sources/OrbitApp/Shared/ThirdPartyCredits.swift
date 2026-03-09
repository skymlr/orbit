import Foundation

struct ThirdPartyCredit: Identifiable, Equatable, Hashable, Sendable {
    let packageID: String
    let name: String
    let version: String
    let licenseName: String
    let repositoryURL: URL
    let licenseURL: URL

    var id: String { packageID }
}

enum ThirdPartyCredits {
    static let all: [ThirdPartyCredit] = [
        ThirdPartyCredit(
            packageID: "combine-schedulers",
            name: "Combine Schedulers",
            version: "1.1.0",
            licenseName: "MIT License",
            repository: "https://github.com/pointfreeco/combine-schedulers",
            revision: "fd16d76fd8b9a976d88bfb6cacc05ca8d19c91b6",
            licenseFile: "LICENSE"
        ),
        ThirdPartyCredit(
            packageID: "grdb.swift",
            name: "GRDB.swift",
            version: "7.10.0",
            licenseName: "MIT License",
            repository: "https://github.com/groue/GRDB.swift",
            revision: "36e30a6f1ef10e4194f6af0cff90888526f0c115",
            licenseFile: "LICENSE"
        ),
        ThirdPartyCredit(
            packageID: "sqlite-data",
            name: "SQLiteData",
            version: "1.6.0",
            licenseName: "MIT License",
            repository: "https://github.com/pointfreeco/sqlite-data",
            revision: "65502acdb033ec8025a0bcc443abf2f4ca0598f9",
            licenseFile: "LICENSE"
        ),
        ThirdPartyCredit(
            packageID: "swift-case-paths",
            name: "Case Paths",
            version: "1.7.2",
            licenseName: "MIT License",
            repository: "https://github.com/pointfreeco/swift-case-paths",
            revision: "6989976265be3f8d2b5802c722f9ba168e227c71",
            licenseFile: "LICENSE"
        ),
        ThirdPartyCredit(
            packageID: "swift-clocks",
            name: "Clocks",
            version: "1.0.6",
            licenseName: "MIT License",
            repository: "https://github.com/pointfreeco/swift-clocks",
            revision: "cc46202b53476d64e824e0b6612da09d84ffde8e",
            licenseFile: "LICENSE"
        ),
        ThirdPartyCredit(
            packageID: "swift-collections",
            name: "Swift Collections",
            version: "1.3.0",
            licenseName: "Apache License 2.0",
            repository: "https://github.com/apple/swift-collections",
            revision: "7b847a3b7008b2dc2f47ca3110d8c782fb2e5c7e",
            licenseFile: "LICENSE.txt"
        ),
        ThirdPartyCredit(
            packageID: "swift-composable-architecture",
            name: "Composable Architecture",
            version: "1.24.1",
            licenseName: "MIT License",
            repository: "https://github.com/pointfreeco/swift-composable-architecture",
            revision: "74a5fa0d02b17ba5bbd9743dc49b4d7f3bbbed96",
            licenseFile: "LICENSE"
        ),
        ThirdPartyCredit(
            packageID: "swift-concurrency-extras",
            name: "Concurrency Extras",
            version: "1.3.2",
            licenseName: "MIT License",
            repository: "https://github.com/pointfreeco/swift-concurrency-extras",
            revision: "5a3825302b1a0d744183200915a47b508c828e6f",
            licenseFile: "LICENSE"
        ),
        ThirdPartyCredit(
            packageID: "swift-custom-dump",
            name: "CustomDump",
            version: "1.4.1",
            licenseName: "MIT License",
            repository: "https://github.com/pointfreeco/swift-custom-dump",
            revision: "2a2a938798236b8fa0bc57c453ee9de9f9ec3ab0",
            licenseFile: "LICENSE"
        ),
        ThirdPartyCredit(
            packageID: "swift-dependencies",
            name: "Dependencies",
            version: "1.11.0",
            licenseName: "MIT License",
            repository: "https://github.com/pointfreeco/swift-dependencies",
            revision: "c79f72b3e67a1eb64f66f76704c22ed6a5c1ed84",
            licenseFile: "LICENSE"
        ),
        ThirdPartyCredit(
            packageID: "swift-identified-collections",
            name: "Identified Collections",
            version: "1.1.1",
            licenseName: "MIT License",
            repository: "https://github.com/pointfreeco/swift-identified-collections",
            revision: "322d9ffeeba85c9f7c4984b39422ec7cc3c56597",
            licenseFile: "LICENSE"
        ),
        ThirdPartyCredit(
            packageID: "swift-navigation",
            name: "Swift Navigation",
            version: "2.7.0",
            licenseName: "MIT License",
            repository: "https://github.com/pointfreeco/swift-navigation",
            revision: "e7441dc4dfec6a4ae929e614e3c1e67c6639d164",
            licenseFile: "LICENSE"
        ),
        ThirdPartyCredit(
            packageID: "swift-perception",
            name: "Perception",
            version: "2.0.9",
            licenseName: "MIT License",
            repository: "https://github.com/pointfreeco/swift-perception",
            revision: "4f47ebafed5f0b0172cf5c661454fa8e28fb2ac4",
            licenseFile: "LICENSE"
        ),
        ThirdPartyCredit(
            packageID: "swift-sharing",
            name: "Sharing",
            version: "2.7.4",
            licenseName: "MIT License",
            repository: "https://github.com/pointfreeco/swift-sharing",
            revision: "3bfc408cc2d0bee2287c174da6b1c76768377818",
            licenseFile: "LICENSE"
        ),
        ThirdPartyCredit(
            packageID: "swift-snapshot-testing",
            name: "SnapshotTesting",
            version: "1.18.9",
            licenseName: "MIT License",
            repository: "https://github.com/pointfreeco/swift-snapshot-testing",
            revision: "bf8d8c27f0f0c6d5e77bff0db76ab68f2050d15d",
            licenseFile: "LICENSE"
        ),
        ThirdPartyCredit(
            packageID: "swift-structured-queries",
            name: "Structured Queries",
            version: "0.31.0",
            licenseName: "MIT License",
            repository: "https://github.com/pointfreeco/swift-structured-queries",
            revision: "20db4a2a446f51e67e1207d54a23ad0a03471a7b",
            licenseFile: "LICENSE"
        ),
        ThirdPartyCredit(
            packageID: "swift-syntax",
            name: "Swift Syntax",
            version: "602.0.0",
            licenseName: "Apache License 2.0",
            repository: "https://github.com/swiftlang/swift-syntax",
            revision: "4799286537280063c85a32f09884cfbca301b1a1",
            licenseFile: "LICENSE.txt"
        ),
        ThirdPartyCredit(
            packageID: "swiftui-flow",
            name: "SwiftUI-Flow",
            version: "3.1.1",
            licenseName: "MIT License",
            repository: "https://github.com/tevelee/SwiftUI-Flow",
            revision: "d227f999b2894ab737ef5786d9b14d02d3e5362e",
            licenseFile: "LICENSE.txt"
        ),
        ThirdPartyCredit(
            packageID: "xctest-dynamic-overlay",
            name: "XCTest Dynamic Overlay",
            version: "1.9.0",
            licenseName: "MIT License",
            repository: "https://github.com/pointfreeco/xctest-dynamic-overlay",
            revision: "dfd70507def84cb5fb821278448a262c6ff2bbad",
            licenseFile: "LICENSE"
        ),
    ]
    .sorted { lhs, rhs in
        lhs.name.lowercased() < rhs.name.lowercased()
    }
}

private extension ThirdPartyCredit {
    init(
        packageID: String,
        name: String,
        version: String,
        licenseName: String,
        repository: String,
        revision: String,
        licenseFile: String
    ) {
        let repositoryURL = URL(string: repository)!

        self.init(
            packageID: packageID,
            name: name,
            version: version,
            licenseName: licenseName,
            repositoryURL: repositoryURL,
            licenseURL: repositoryURL
                .appendingPathComponent("blob")
                .appendingPathComponent(revision)
                .appendingPathComponent(licenseFile)
        )
    }
}
