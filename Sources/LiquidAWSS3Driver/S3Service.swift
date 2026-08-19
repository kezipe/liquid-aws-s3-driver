import AWSS3
import Foundation

enum S3ServiceError: Error {
    case keyNotFound
}

protocol S3Service: Sendable {
    func putObject(bucket: String, key: String, data: Data) async throws
    func copyObject(bucket: String, source: String, destination: String) async throws
    func deleteObject(bucket: String, key: String) async throws
    func getObject(bucket: String, key: String) async throws -> Data
    func objectExists(bucket: String, key: String) async throws -> Bool
    func listObjects(bucket: String, prefix: String?) async throws -> [String]
}

final class AWSS3Service: S3Service, @unchecked Sendable {
    private static let copySourceAllowedCharacters = CharacterSet.urlPathAllowed.subtracting(
        CharacterSet(charactersIn: "%?#")
    )

    private let client: S3Client

    init(client: S3Client) {
        self.client = client
    }

    func putObject(bucket: String, key: String, data: Data) async throws {
        let input = PutObjectInput(
            body: .data(data),
            bucket: bucket,
            contentLength: data.count,
            key: key
        )
        _ = try await client.putObject(input: input)
    }

    func copyObject(bucket: String, source: String, destination: String) async throws {
        let copySource = Self.copySource(bucket: bucket, key: source)
        let input = CopyObjectInput(bucket: bucket, copySource: copySource, key: destination)
        _ = try await client.copyObject(input: input)
    }

    static func copySource(bucket: String, key: String) -> String {
        let value = bucket + "/" + key
        return value.addingPercentEncoding(withAllowedCharacters: copySourceAllowedCharacters) ?? value
    }

    func deleteObject(bucket: String, key: String) async throws {
        _ = try await client.deleteObject(input: DeleteObjectInput(bucket: bucket, key: key))
    }

    func getObject(bucket: String, key: String) async throws -> Data {
        do {
            let output = try await client.getObject(input: GetObjectInput(bucket: bucket, key: key))
            return try await output.body?.readData() ?? Data()
        } catch is NoSuchKey {
            throw S3ServiceError.keyNotFound
        }
    }

    func objectExists(bucket: String, key: String) async throws -> Bool {
        do {
            _ = try await client.headObject(input: HeadObjectInput(bucket: bucket, key: key))
            return true
        } catch is NotFound {
            return false
        }
    }

    func listObjects(bucket: String, prefix: String?) async throws -> [String] {
        var keys: [String] = []
        var continuationToken: String?

        repeat {
            let input = ListObjectsV2Input(
                bucket: bucket,
                continuationToken: continuationToken,
                prefix: prefix
            )
            let output = try await client.listObjectsV2(input: input)
            keys.append(contentsOf: output.contents?.compactMap(\.key) ?? [])
            continuationToken = output.isTruncated == true ? output.nextContinuationToken : nil
        } while continuationToken != nil

        return keys
    }
}
