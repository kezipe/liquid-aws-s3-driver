//
//  LiquidAWSS3Storage.swift
//  LiquidAWSS3Driver
//
//  Created by Tibor Bodecs on 2020. 04. 28..
//

import Foundation
import LiquidKit

/// AWS S3 File Storage implementation
struct LiquidAWSS3Storage: FileStorage {

    let configuration: LiquidAWSS3StorageConfiguration
    let context: FileStorageContext

    init(configuration: LiquidAWSS3StorageConfiguration,
         context: FileStorageContext,
         service: any S3Service)
    {
        self.configuration = configuration
        self.context = context
        
        guard configuration.bucket.hasValidName() else {
            fatalError("Invalid bucket name")
        }

        self.s3 = service
    }
    
    // MARK: - private

    /// private s3 reference
    private let s3: any S3Service

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
        try await s3.putObject(bucket: bucket, key: key, data: data)
        return resolve(key: key)
    }

    /// Create a directory structure for a given key
    func createDirectory(key: String) async throws {
        try await s3.putObject(bucket: bucket, key: key, data: Data())
    }

    /// List objects under a given key
    func list(key: String? = nil) async throws -> [String] {
        try await s3.listObjects(bucket: bucket, prefix: key)
    }
    
    func copy(key source: String, to destination: String) async throws -> String {
        guard try await s3.objectExists(bucket: bucket, key: source) else {
            throw LiquidError.keyNotExists
        }
        try await s3.copyObject(bucket: bucket, source: source, destination: destination)
        return resolve(key: destination)
    }
    
    func move(key source: String, to destination: String) async throws -> String {
        _ = try await copy(key: source, to: destination)
        try await delete(key: source)
        return resolve(key: destination)
    }

    func getObject(key source: String) async throws -> Data? {
        do {
            return try await s3.getObject(bucket: bucket, key: source)
        } catch S3ServiceError.keyNotFound {
            throw LiquidError.keyNotExists
        }
    }

    /// Removes a file resource using a key
    func delete(key: String) async throws {
        try await s3.deleteObject(bucket: bucket, key: key)
    }

    func exists(key: String) async -> Bool {
        do {
            return try await s3.objectExists(bucket: bucket, key: key)
        } catch {
            return false
        }
    }
}
