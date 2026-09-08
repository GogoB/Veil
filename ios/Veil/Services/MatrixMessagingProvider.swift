import Foundation
import MatrixRustSDK
import VeilShared

/// The only file in the app target that imports MatrixRustSDK. Views and app
/// models never see Matrix user or room identifiers.
final class MatrixMessagingProvider: MessagingProvider, @unchecked Sendable {
    private var client: MatrixRustSDK.Client?
    private var timelines: [String: Timeline] = [:]
    private var timelineListeners: [String: MatrixTimelineListener] = [:]
    private var timelineHandles: [String: TaskHandle] = [:]

    func configure(with configuration: VeilShared.MessagingSessionConfiguration) async throws {
        let fileManager = FileManager.default
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let safeUser = Data(configuration.userID.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
        let dataDirectory = applicationSupport.appendingPathComponent("VeilMatrix/\(safeUser)", isDirectory: true)
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VeilMatrix/\(safeUser)", isDirectory: true)
        try fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        let matrixClient = try await ClientBuilder()
            .homeserverUrl(url: configuration.homeserverURL.absoluteString)
            .sessionPaths(dataPath: dataDirectory.path, cachePath: cacheDirectory.path)
            .slidingSyncVersionBuilder(versionBuilder: .native)
            .build()
        try await matrixClient.restoreSession(session: Session(
            accessToken: configuration.accessToken,
            refreshToken: nil,
            userId: configuration.userID,
            deviceId: configuration.deviceID,
            homeserverUrl: configuration.homeserverURL.absoluteString,
            oauthData: nil,
            slidingSyncVersion: .native
        ))
        client = matrixClient
        _ = try await matrixClient.syncOnceV2(settings: SyncSettingsV2(timeoutMs: 0, fullState: true))
    }

    func synchronize() async throws {
        guard let client else { throw MatrixMessagingError.notConfigured }
        _ = try await client.syncOnceV2(settings: SyncSettingsV2(timeoutMs: 0))
    }

    func observeMessages(
        in roomID: String,
        onUpdate: @escaping @Sendable ([MatrixDecryptedMessage]) -> Void
    ) async throws {
        let timeline = try await timeline(for: roomID)
        let listener = MatrixTimelineListener(onUpdate: onUpdate)
        let handle = await timeline.addListener(listener: listener)
        timelineListeners[roomID] = listener
        timelineHandles[roomID] = handle
        try await synchronize()
    }

    func sendText(_ text: String, to roomID: String) async throws -> String {
        let timeline = try await timeline(for: roomID)
        let previousEventID = await timeline.latestEventId()
        guard let content = timeline.createMessageContent(
            msgType: .text(content: TextMessageContent(body: text, formatted: nil))
        ) else { throw MatrixMessagingError.invalidContent }
        _ = try await timeline.send(msg: content)
        return try await awaitLatestEventID(on: timeline, excluding: previousEventID)
    }

    func sendImage(_ data: Data, mimeType: String, width: Int, height: Int, to roomID: String) async throws -> String {
        let timeline = try await timeline(for: roomID)
        let previousEventID = await timeline.latestEventId()
        let thumbnailInfo = ThumbnailInfo(
            height: UInt64(height),
            width: UInt64(width),
            mimetype: mimeType,
            size: UInt64(data.count)
        )
        let imageInfo = ImageInfo(
            height: UInt64(height),
            width: UInt64(width),
            mimetype: mimeType,
            size: UInt64(data.count),
            thumbnailInfo: thumbnailInfo,
            thumbnailSource: nil,
            blurhash: nil,
            isAnimated: nil
        )
        let handle = try timeline.sendImage(
            params: .init(
                source: .data(bytes: data, filename: "image.jpg"),
                caption: nil,
                formattedCaption: nil,
                mentions: nil,
                inReplyTo: nil
            ),
            thumbnailSource: .data(bytes: data, filename: "thumbnail.jpg"),
            imageInfo: imageInfo
        )
        try await handle.join()
        return try await awaitLatestEventID(on: timeline, excluding: previousEventID)
    }

    func acceptRequest(in roomID: String) async throws {
        guard let client, let room = try client.getRoom(roomId: roomID) else {
            throw MatrixMessagingError.roomUnavailable
        }
        try await room.join()
        try await synchronize()
    }

    func deleteForAll(eventID: String, in roomID: String) async throws {
        let timeline = try await timeline(for: roomID)
        try await timeline.redactEvent(eventOrTransactionId: .eventId(eventId: eventID), reason: nil)
    }

    func setDisappearingTimer(_ seconds: Int?, in roomID: String) async throws {
        _ = seconds
        _ = try await timeline(for: roomID)
    }

    func block(roomID: String) async {
        timelines.removeValue(forKey: roomID)
        timelineListeners.removeValue(forKey: roomID)
        timelineHandles.removeValue(forKey: roomID)
    }

    /// Produces a recovery key only after the old device has uploaded its room
    /// keys. Veil does not keep this key and account recovery cannot recreate it.
    func exportOldDeviceKeys() async throws -> String {
        guard let client else { throw MatrixMessagingError.notConfigured }
        return try await client.encryption().enableRecovery(
            waitForBackupsToUpload: true,
            passphrase: nil,
            progressListener: SilentRecoveryProgressListener()
        )
    }

    func importTransferredKeys(_ recoveryKey: String) async throws {
        guard let client else { throw MatrixMessagingError.notConfigured }
        try await client.encryption().recover(recoveryKey: recoveryKey)
    }

    private func timeline(for roomID: String) async throws -> Timeline {
        if let timeline = timelines[roomID] { return timeline }
        guard let client, let room = try client.getRoom(roomId: roomID) else {
            throw MatrixMessagingError.roomUnavailable
        }
        let timeline = try await room.timeline()
        timelines[roomID] = timeline
        return timeline
    }

    private func awaitLatestEventID(on timeline: Timeline, excluding previousEventID: String?) async throws -> String {
        for _ in 0..<8 {
            try await synchronize()
            if let eventID = await timeline.latestEventId(), eventID != previousEventID { return eventID }
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        throw MatrixMessagingError.eventConfirmationTimedOut
    }
}

struct MatrixDecryptedMessage: Sendable {
    let eventID: String
    let body: String
    let isMine: Bool
    let sentAt: Date
}

enum MatrixMessagingError: LocalizedError {
    case notConfigured
    case roomUnavailable
    case invalidContent
    case eventConfirmationTimedOut

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Encrypted messaging has not finished starting."
        case .roomUnavailable: return "The encrypted room is unavailable."
        case .invalidContent: return "The message could not be encrypted."
        case .eventConfirmationTimedOut: return "The homeserver did not confirm the encrypted event in time."
        }
    }
}

private final class SilentRecoveryProgressListener: EnableRecoveryProgressListener, @unchecked Sendable {
    func onUpdate(status: EnableRecoveryProgress) { }
}

private final class MatrixTimelineListener: TimelineListener, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [TimelineItem] = []
    private let onUpdate: @Sendable ([MatrixDecryptedMessage]) -> Void

    init(onUpdate: @escaping @Sendable ([MatrixDecryptedMessage]) -> Void) {
        self.onUpdate = onUpdate
    }

    func onUpdate(diff: [TimelineDiff]) {
        lock.lock()
        for change in diff { apply(change) }
        let messages = items.compactMap(Self.message(from:))
        lock.unlock()
        onUpdate(messages)
    }

    private func apply(_ diff: TimelineDiff) {
        switch diff {
        case let .append(values): items.append(contentsOf: values)
        case .clear: items.removeAll()
        case let .pushFront(value): items.insert(value, at: 0)
        case let .pushBack(value): items.append(value)
        case .popFront: if !items.isEmpty { items.removeFirst() }
        case .popBack: if !items.isEmpty { items.removeLast() }
        case let .insert(index, value): items.insert(value, at: min(Int(index), items.count))
        case let .set(index, value): if items.indices.contains(Int(index)) { items[Int(index)] = value }
        case let .remove(index): if items.indices.contains(Int(index)) { items.remove(at: Int(index)) }
        case let .truncate(length): items = Array(items.prefix(Int(length)))
        case let .reset(values): items = values
        }
    }

    private static func message(from item: TimelineItem) -> MatrixDecryptedMessage? {
        guard let event = item.asEvent(),
              case let .msgLike(content) = event.content,
              case let .message(message) = content.kind else { return nil }
        let eventID: String
        switch event.eventOrTransactionId {
        case let .eventId(value): eventID = value
        case let .transactionId(value): eventID = value
        }
        return MatrixDecryptedMessage(
            eventID: eventID,
            body: message.body,
            isMine: event.isOwn,
            sentAt: Date(timeIntervalSince1970: TimeInterval(event.timestamp) / 1_000)
        )
    }
}
