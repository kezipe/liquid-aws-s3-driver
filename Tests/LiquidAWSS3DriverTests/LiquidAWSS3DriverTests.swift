import Foundation
import LiquidKit
import NIO
import XCTest

@testable import LiquidAWSS3Driver

private enum MockError: Error { case transport }

private actor MockS3Service: S3Service {
    private var objects: [String: Data] = [:]
    private var failure: Error?
    private var putDelayNanoseconds: UInt64 = 0

    func setFailure(_ error: Error?) { failure = error }
    func setPutDelay(nanoseconds: UInt64) { putDelayNanoseconds = nanoseconds }

    func putObject(bucket: String, key: String, data: Data) async throws {
        if putDelayNanoseconds > 0 { try await Task.sleep(nanoseconds: putDelayNanoseconds) }
        try Task.checkCancellation()
        if let failure { throw failure }
        objects[key] = data
    }

    func copyObject(bucket: String, source: String, destination: String) async throws {
        if let failure { throw failure }
        guard let data = objects[source] else { throw S3ServiceError.keyNotFound }
        objects[destination] = data
    }

    func deleteObject(bucket: String, key: String) async throws {
        if let failure { throw failure }
        objects[key] = nil
    }

    func getObject(bucket: String, key: String) async throws -> Data {
        if let failure { throw failure }
        guard let data = objects[key] else { throw S3ServiceError.keyNotFound }
        return data
    }

    func objectExists(bucket: String, key: String) async throws -> Bool {
        if let failure { throw failure }
        return objects[key] != nil
    }

    func listObjects(bucket: String, prefix: String?) async throws -> [String] {
        if let failure { throw failure }
        return objects.keys.filter { prefix.map($0.hasPrefix) ?? true }.sorted()
    }
}

final class LiquidAWSS3DriverTests: XCTestCase, @unchecked Sendable {
    private var eventLoopGroup: MultiThreadedEventLoopGroup!
    private var service: MockS3Service!
    private var storage: LiquidAWSS3Storage!

    override func setUp() {
        super.setUp()
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        service = MockS3Service()
        storage = makeStorage(region: "us-east-2", endpoint: nil)
    }

    override func tearDown() {
        try? eventLoopGroup.syncShutdownGracefully()
        storage = nil
        service = nil
        eventLoopGroup = nil
        super.tearDown()
    }

    private func makeStorage(region: Region, endpoint: String?) -> LiquidAWSS3Storage {
        let configuration = LiquidAWSS3StorageConfiguration(
            region: region,
            bucket: "test-bucket",
            endpoint: endpoint
        )
        let context = FileStorageContext(
            configuration: configuration,
            logger: .init(label: "liquid-aws-s3-driver-tests"),
            eventLoop: eventLoopGroup.next()
        )
        return LiquidAWSS3Storage(configuration: configuration, context: context, service: service)
    }

    func testResolveUsesRegionalUSEastOneAndCustomURLs() {
        XCTAssertEqual(
            storage.resolve(key: "directory/file.txt"),
            "https://test-bucket.s3-us-east-2.amazonaws.com/directory/file.txt"
        )
        XCTAssertEqual(
            makeStorage(region: "us-east-1", endpoint: nil).resolve(key: "file.txt"),
            "https://test-bucket.s3.amazonaws.com/file.txt"
        )
        XCTAssertEqual(
            makeStorage(region: "us-east-2", endpoint: "http://localhost:9000").resolve(key: "file.txt"),
            "http://localhost:9000/test-bucket/file.txt"
        )
    }

    func testCopySourceIsURLPathEncoded() {
        XCTAssertEqual(
            AWSS3Service.copySource(bucket: "test-bucket", key: "dir/a b?#%.txt"),
            "test-bucket/dir/a%20b%3F%23%25.txt"
        )
    }

    func testUploadDownloadEmptyLargeAndOverwrite() async throws {
        let empty = Data()
        _ = try await storage.upload(key: "empty", data: empty)
        let downloadedEmpty = try await storage.getObject(key: "empty")
        XCTAssertEqual(downloadedEmpty, empty)

        let large = Data((0..<(2 * 1024 * 1024)).map { UInt8($0 % 251) })
        _ = try await storage.upload(key: "large", data: large)
        let downloadedLarge = try await storage.getObject(key: "large")
        XCTAssertEqual(downloadedLarge, large)

        let replacement = Data("replacement".utf8)
        _ = try await storage.upload(key: "large", data: replacement)
        let downloadedReplacement = try await storage.getObject(key: "large")
        XCTAssertEqual(downloadedReplacement, replacement)
    }

    func testCreateDirectoryAndListByPrefix() async throws {
        try await storage.createDirectory(key: "dir/subdir/")
        _ = try await storage.upload(key: "dir/file.txt", data: Data("file".utf8))
        _ = try await storage.upload(key: "other.txt", data: Data("other".utf8))
        let directoryObjects = try await storage.list(key: "dir/")
        let allObjects = try await storage.list(key: nil)
        XCTAssertEqual(directoryObjects, ["dir/file.txt", "dir/subdir/"])
        XCTAssertEqual(allObjects, ["dir/file.txt", "dir/subdir/", "other.txt"])
    }

    func testCopyAndMovePreserveDataAndReturnDestinationURL() async throws {
        let data = Data("payload".utf8)
        _ = try await storage.upload(key: "source", data: data)
        let copyURL = try await storage.copy(key: "source", to: "copy")
        let copiedData = try await storage.getObject(key: "copy")
        let moveURL = try await storage.move(key: "source", to: "moved")
        let sourceExists = await storage.exists(key: "source")
        let movedData = try await storage.getObject(key: "moved")
        XCTAssertEqual(copyURL, storage.resolve(key: "copy"))
        XCTAssertEqual(copiedData, data)
        XCTAssertEqual(moveURL, storage.resolve(key: "moved"))
        XCTAssertFalse(sourceExists)
        XCTAssertEqual(movedData, data)
    }

    func testDeleteIsIdempotent() async throws {
        _ = try await storage.upload(key: "key", data: Data("value".utf8))
        try await storage.delete(key: "key")
        try await storage.delete(key: "key")
        let exists = await storage.exists(key: "key")
        XCTAssertFalse(exists)
    }

    func testMissingKeyTranslation() async throws {
        do {
            _ = try await storage.getObject(key: "missing")
            XCTFail("Expected keyNotExists")
        } catch LiquidError.keyNotExists {}

        do {
            _ = try await storage.copy(key: "missing", to: "destination")
            XCTFail("Expected keyNotExists")
        } catch LiquidError.keyNotExists {}
    }

    func testTransportFailuresAreNotTranslatedToMissingKeys() async throws {
        await service.setFailure(MockError.transport)
        do {
            _ = try await storage.getObject(key: "key")
            XCTFail("Expected transport error")
        } catch MockError.transport {}
        let exists = await storage.exists(key: "key")
        XCTAssertFalse(exists)
    }

    func testCancellationStopsUpload() async throws {
        await service.setPutDelay(nanoseconds: 5_000_000_000)
        let task = Task { try await storage.upload(key: "cancelled", data: Data("value".utf8)) }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
        let exists = await storage.exists(key: "cancelled")
        XCTAssertFalse(exists)
    }

    func testConcurrentAccessPreservesEveryObject() async throws {
        let count = 100
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<count {
                group.addTask { [storage] in
                    _ = try await storage?.upload(
                        key: "key-\(index)",
                        data: Data("value-\(index)".utf8)
                    )
                }
            }
            try await group.waitForAll()
        }
        let objects = try await storage.list(key: "key-")
        XCTAssertEqual(objects.count, count)
    }
}
