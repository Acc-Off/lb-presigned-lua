
# lb-presigned-lua

## Overview

A Lua port of [lbphone/lb-presigned](https://github.com/lbphone/lb-presigned) — a FiveM script to generate presigned URLs for uploading files — with added support for **Azure Blob Storage** in addition to AWS S3.

> [!NOTE]
> If you need per-player path separation or tagging (metadata support), use this resource instead:
> [Acc-Off/lb-presigned-with-metadata](https://github.com/Acc-Off/lb-presigned-with-metadata)

> [!IMPORTANT]
> This requires LB Phone v2.6.0 or higher, or LB Tablet v1.6.0 or higher.

---

## Installation

### 1. Place the resource

Download the ZIP from GitHub and place the `lb-presigned` folder in your `resources` folder.

### 2. Update server.cfg

```
ensure lb-presigned
```

### 3. Configure `lb-presigned\server\config.lua`

#### For Azure Blob Storage

```lua
Config.Target = "AzureBlob" -- "AzureBlob" or "AwsS3"
Config.Azure = {}
Config.Azure.AccountName   = "your_account_name"
Config.Azure.AccountKey    = "your_account_key"
Config.Azure.ContainerName = "your_container_name"
```

#### For AWS S3

```lua
Config.Target = "AwsS3" -- "AzureBlob" or "AwsS3"
Config.AwsS3 = {}
Config.AwsS3.AccessKey  = "your_access_key"
Config.AwsS3.SecretKey  = "your_secret_key"
Config.AwsS3.Region     = "your_region"
Config.AwsS3.BucketName = "your_bucket_name"
```


### 4. Modify lb-phone

> **Note:** If you are using **lb-tablet**, replace all references to `lb-phone` with `lb-tablet` throughout this section.

#### Edit `lb-phone\config\config.lua`

Update the upload method values:

```lua
Config.UploadMethod.Video = "LBPresigned"
Config.UploadMethod.Image = "LBPresigned"
Config.UploadMethod.Audio = "LBPresigned"
```

If targeting Azure Blob Storage, add `"windows.net"` to the whitelist:

```lua
Config.UploadWhitelistedDomains = {
    "fivemanage.com",
    "fmfile.com",
    "amazonaws.com", -- lb-presigned (S3)
    "windows.net"
}
```

#### Edit `lb-phone\shared\upload.lua`

Add the `LBPresigned` entry to `UploadMethods`.

For **Azure Blob Storage**, a `headers` block is required. For **AWS S3**, omit it (not needed):

```lua
UploadMethods = {
    LBPresigned = { -- https://github.com/lbphone/lb-presigned
        Default = {
            url = "PRESIGNED_URL",
            httpMethod = "PUT",
            headers = {
                ["x-ms-blob-type"] = "BlockBlob" -- Required for Azure Blob; remove for AWS S3
            },
            uploadType = "binary",
        }
    },
}
```
