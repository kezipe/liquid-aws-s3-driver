//
//  FileStorageConfiguration+AWSS3.swift
//  LiquidAwsS3Driver
//
//  Created by Tibor Bodecs on 2020. 04. 28..
//
import LiquidKit

public extension FileStorageConfigurationFactory {

    /// creates a new Liquid FileStorageConfigurationFactory object using the provided S3 configuration 
    static func awsS3(region: Region,
                      bucket: S3Bucket,
                      endpoint: String? = nil) -> FileStorageConfigurationFactory {
        .init {
            LiquidAWSS3StorageConfiguration(region: region,
                                            bucket: bucket,
                                            endpoint: endpoint)
        }
    }
}
