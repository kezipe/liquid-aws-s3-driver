# LiquidAWSS3Driver



AWS S3 driver implementation for the [LiquidKit](https://github.com/aoenth/liquid-kit) file storage solution, based on the [AWS Swift SDK](https://aws.amazon.com/sdk-for-swift/) project.

The package requires Swift 6.1 or newer and uses AWS SDK for Swift 1.7.62 or newer within the 1.x release line. The lower-bound requirement lets applications receive compatible SDK security and bug fixes while SwiftPM's `Package.resolved` keeps application and CI builds reproducible.

LiquidKit and the AWS S3 driver is also compatible with Vapor 4 through the [Liquid](https://github.com/aoenth/liquid) repository, that contains Vapor specific extensions.

## Key resolution for S3 objects

Keys are being resolved using a the bucket and the region name, with the standard AWS structure:

- url = "https://" + [bucket name] + ".s3-" + [region name] + "amazonaws.com/" + [key]

Alternatively you can use a custom endpoint. In that case the endpoint will be extended with the bucket name and key.

- url = [custom endpoint] + [bucket name] + [key]


e.g. 

- bucketName = "testbucket"
- regionName = "us-west-1"
- key = "test.txt"

- resolvedUrl = "https://testbucket.s3-us-west-1.amazonaws.com/test.txt"


## Credentials

It is possible to configure credentials via multiple methods, by default the driver will try to load the credentials from the shared credential file.

You can read more about the configuration in the AWS SDK Swift [documentation](https://docs.aws.amazon.com/sdk-for-swift/latest/developer-guide/credential-providers.html).

To get started with a default shared credential file, place the following values into the `~/.aws/credentials` file.

```ini
[default]
aws_access_key_id = YOUR_AWS_ACCESS_KEY_ID
aws_secret_access_key = YOUR_AWS_SECRET_ACCESS_KEY
```


## Usage with SwiftNIO


Add the required dependencies using SPM:

```swift
// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "myProject",
    platforms: [
       .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/aoenth/liquid", from: "1.3.3"),
        .package(url: "https://github.com/kezipe/liquid-aws-s3-driver.git", from: "2.1.0"),
    ],
    targets: [
        .target(name: "App", dependencies: [
            .product(name: "Liquid", package: "liquid"),
            .product(name: "LiquidAWSS3Driver", package: "liquid-aws-s3-driver"),
        ]),
    ]
)
```

A basic usage example with SwiftNIO:

```swift
/// setup thread pool
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let pool = NIOThreadPool(numberOfThreads: 1)
pool.start()

/// create fs  
let fileio = NonBlockingFileIO(threadPool: pool)
let storages = FileStorages(fileio: fileio)
storages.use(.awsS3(region: "us-west-1", bucket: "testbucket"), as: .awsS3)
let fs = storages.fileStorage(.awsS3, logger: .init(label: "[test-logger]"), on: elg.next())!

/// test file upload
let key = "test.txt"
let data = Data("file storage test".utf8)
let res = try await fs.upload(key: key, data: data)

/// https://testbucket.s3-us-west-1.amazonaws.com/test.txt
let url = req.fs.resolve(key: key)

/// delete key
try await fs.delete(key: key)

```

For an S3-compatible service, pass its base URL as `endpoint`; the SDK uses that endpoint for requests and the driver uses it when resolving public object URLs:

```swift
storages.use(
    .awsS3(
        region: "us-east-1",
        bucket: "testbucket",
        endpoint: "http://localhost:9000"
    ),
    as: .awsS3
)
```

## Credits
Forked from Binary Bird's [LiquidAwsS3Driver](https://github.com/BinaryBirds/liquid-aws-s3-driver) project that was based on the [Soto for AWS](https://github.com/soto-project/soto) project.
