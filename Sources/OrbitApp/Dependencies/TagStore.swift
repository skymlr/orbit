import Dependencies
import Foundation

enum TagStoreError: Error, Equatable, Sendable {
    case directoryUnavailable
    case readFailed(String)
    case writeFailed(String)
}

struct TagStore: Sendable {
    var loadCatalog: @Sendable () async throws -> [SessionTag]
    var saveCatalog: @Sendable ([SessionTag]) async throws -> Void
}

extension TagStore: DependencyKey {
    static var liveValue: TagStore {
        let fileStore = TagFileStore()
        return TagStore(
            loadCatalog: {
                try await fileStore.loadCatalog()
            },
            saveCatalog: { tags in
                try await fileStore.saveCatalog(tags)
            }
        )
    }

    static var testValue: TagStore {
        TagStore(
            loadCatalog: { SessionTag.builtIns },
            saveCatalog: { _ in }
        )
    }
}

extension DependencyValues {
    var tagStore: TagStore {
        get { self[TagStore.self] }
        set { self[TagStore.self] = newValue }
    }
}

private actor TagFileStore {
    private let fileManager = FileManager.default

    func loadCatalog() throws -> [SessionTag] {
        let fileURL = try tagsFileURL()
        guard fileManager.fileExists(atPath: fileURL.path) else {
            let seeded = normalizedCatalog(SessionTag.builtIns)
            try saveCatalog(seeded)
            return seeded
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([SessionTag].self, from: data)
            let catalog = normalizedCatalog(decoded)
            if catalog != decoded {
                try saveCatalog(catalog)
            }
            return catalog
        } catch {
            throw TagStoreError.readFailed(error.localizedDescription)
        }
    }

    func saveCatalog(_ tags: [SessionTag]) throws {
        let fileURL = try tagsFileURL()
        let catalog = normalizedCatalog(tags)

        do {
            let data = try JSONEncoder().encode(catalog)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw TagStoreError.writeFailed(error.localizedDescription)
        }
    }

    private func normalizedCatalog(_ tags: [SessionTag]) -> [SessionTag] {
        let builtInByName = Dictionary(uniqueKeysWithValues: SessionTag.builtIns.map { ($0.normalizedName, $0) })

        var seen = Set<String>()
        var custom: [SessionTag] = []

        for tag in tags {
            let name = tag.normalizedName
            guard !name.isEmpty, !seen.contains(name) else { continue }
            seen.insert(name)

            if builtInByName[name] == nil {
                custom.append(SessionTag(id: tag.id, name: name, isBuiltIn: false))
            }
        }

        custom.sort { $0.name < $1.name }
        return SessionTag.builtIns + custom
    }

    private func tagsFileURL() throws -> URL {
        guard let appSupportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw TagStoreError.directoryUnavailable
        }

        let directory = appSupportDirectory
            .appendingPathComponent("Orbit", isDirectory: true)

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory.appendingPathComponent("tags.json", isDirectory: false)
        } catch {
            throw TagStoreError.directoryUnavailable
        }
    }
}
