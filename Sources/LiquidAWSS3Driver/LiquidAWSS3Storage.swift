//
//  LiquidAWSS3Storage.swift
//  LiquidAWSS3Driver
//
//  Created by Tibor Bodecs on 2020. 04. 28..
//

import AWSS3
import Foundation
import LiquidKit

/// AWS S3 File Storage implementation
struct LiquidAWSS3Storage: FileStorage {

    let configuration: LiquidAWSS3StorageConfiguration
    let context: FileStorageContext

	init(configuration: LiquidAWSS3StorageConfiguration,
         context: FileStorageContext,
         client: S3Client)
	{
        self.configuration = configuration
        self.context = context
        
        guard configuration.bucket.hasValidName() else {
            fatalError("Invalid bucket name")
        }

        self.s3 = client
    }
    
    // MARK: - private

    /// private s3 reference
    private var s3: S3Client!
	
    /// private helper for accessing region name
    private var region: String { configuration.region.name }
    
	/// private helper for accessing bucket name
    private var bucket: String { configuration.bucket.name }
    
	/// private helper for accessing the endpoint URL as a String
    private var endpoint: String {
        configuration.endpoint ?? "https://s3.\(region).amazonaws.com"
	}
    
	/// private helper for accessing the publicEndpoint URL as a String
    private var publicEndpoint: String {
		if let customEndpoint = configuration.endpoint {
			return customEndpoint + "/" + bucket
		}

        /// http://www.wryway.com/blog/aws-s3-url-styles/
        if region == "us-east-1" {
            return "https://\(bucket).s3.amazonaws.com"
        }
        return "https://\(bucket).s3-\(region).amazonaws.com"
    }
    
    // MARK: - api

    /// resolves a file location using a key and the public endpoint URL string
    func resolve(key: String) -> String { publicEndpoint + "/" + key }
    
    /// Uploads a file using a key and a data object returning the resolved URL of the uploaded file
    /// https://docs.aws.amazon.com/general/latest/gr/s3.html
    func upload(key: String, data: Data) async throws -> String {
        let input = PutObjectInput(
            body: .data(data),
            bucket: bucket,
            key: key)
        _ = try await s3.putObject(input: input)
        return resolve(key: key)
    }

    /// Create a directory structure for a given key
    func createDirectory(key: String) async throws {
        let input = PutObjectInput(
            bucket: bucket,
            contentLength: 0,
            key: key)
        _ = try await s3.putObject(input: input)
    }

    /// List objects under a given key
    func list(key: String? = nil) async throws -> [String] {
        let input = ListObjectsInput(bucket: bucket, prefix: key)
        let response = try await s3.listObjects(input: input)
        guard let objects = response.contents else { return [] }
        return objects.compactMap(\.key)
    }
    
    func copy(key source: String, to destination: String) async throws -> String {
        guard await exists(key: source) else {
            throw LiquidError.keyNotExists
        }
        let input = CopyObjectInput(bucket: bucket,
                                    copySource: bucket + "/" + source,
                                    key: destination)
        _ = try await s3.copyObject(input: input)
        return resolve(key: destination)
    }
    
    func move(key source: String, to destination: String) async throws -> String {
        _ = try await copy(key: source, to: destination)
        try await delete(key: source)
        return source
    }

    func getObject(key source: String) async throws -> Data? {
        guard await exists(key: source) else {
            throw LiquidError.keyNotExists
        }
        let input = GetObjectInput(bucket: bucket, key: source)
        let response = try await s3.getObject(input: input)
        return try await response.body?.readData()
    }

    /// Removes a file resource using a key
    func delete(key: String) async throws {
        let input = DeleteObjectInput(bucket: bucket, key: key)
        _ = try await s3.deleteObject(input: input)
    }

    func exists(key: String) async -> Bool {
        let input = GetObjectInput(bucket: bucket, key: key)
        do {
            _ = try await s3.getObject(input: input)
        } catch {
            print(#file + String(describing: #line) + ": Unable to check object existence: " + String(describing: error))
            return false
        }
        return true
    }
}


