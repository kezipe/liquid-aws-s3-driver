//
//  LiquidAWSS3StorageDriver.swift
//  LiquidAWSS3Driver
//
//  Created by Tibor Bodecs on 2020. 04. 28..
//

import AWSS3
import LiquidKit

/// the storage driver is responsible for creating the AWS S3 storage object with the given configuration and the underlying AWS Client with the right credentials
struct LiquidAWSS3StorageDriver: FileStorageDriver {

    /// AWS S3 Storage Configuration object
    let configuration: LiquidAWSS3StorageConfiguration
    let service: any S3Service

    init(configuration: LiquidAWSS3StorageConfiguration) {
        self.configuration = configuration
        do {
            let config = try S3Client.S3ClientConfig(
                region: configuration.region.name,
                endpoint: configuration.endpoint
            )
            self.service = AWSS3Service(client: S3Client(config: config))
        } catch {
            fatalError("Cannot instantiate S3Client: \(error.localizedDescription)")
        }
    }

    /// creates a new AWS S3 based FileStorage object
    func makeStorage(with context: FileStorageContext) -> FileStorage {
        LiquidAWSS3Storage(
            configuration: configuration,
            context: context, service: service
        )
    }

    /// shutdown the AWSClient if needed
    func shutdown() {
    }
}
