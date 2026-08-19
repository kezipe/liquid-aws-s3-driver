//
//  LiquidAWSS3StorageConfiguration.swift
//  LiquidAWSS3Driver
//
//  Created by Tibor Bodecs on 2020. 04. 28..
//

import LiquidKit
import AWSS3

public struct Region: ExpressibleByStringLiteral, Sendable {
    let name: String

    public init(stringLiteral value: String) {
        self.name = value
    }
}

struct LiquidAWSS3StorageConfiguration: FileStorageConfiguration {
    /// AWS Region
    let region: Region
    
    /// S3 Bucket representation
    let bucket: S3Bucket

    /// custom endpoint for S3
    let endpoint: String?

    /// creates a new FileStrorageDriver using the AWS S3 configuration object
    func makeDriver(for databases: FileStorages) -> FileStorageDriver {
        LiquidAWSS3StorageDriver(configuration: self)
    }
}
