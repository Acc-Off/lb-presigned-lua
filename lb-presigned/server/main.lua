-- Reverse lookup: MIME type → preferred file extension
local EXT_FROM_MIME = {
    ["audio/mpeg"] = "mp3",
    ["audio/ogg"]  = "ogg",
    ["audio/opus"] = "opus",
    ["audio/webm"] = "weba",
    ["video/mp4"]  = "mp4",
    ["video/webm"] = "webm",
    ["video/ogg"]  = "ogv",
    ["image/jpeg"] = "jpg",
    ["image/png"]  = "png",
    ["image/webp"] = "webp",
}

local function utc_iso8601(offset_sec)
    return os.date("!%Y-%m-%dT%H:%M:%SZ", os.time() + (offset_sec or 0))
end
local function GenerateUUID()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 15) or math.random(8, 11)
        return string.format('%x', v)
    end)
end

exports('GeneratePresignedUrl', function(mimeType)
    if not mimeType then
        Log.error("GeneratePresignedUrl: invalid mimeType")
        return nil
    end

    local ext = EXT_FROM_MIME[mimeType]
    if not ext then
        Log.error("GeneratePresignedUrl: unsupported mime type '%s'", mimeType)
        return nil
    end

    -- Unique file name: YYYYMM/DD/HHMMSS_UUID.ext
    local file_name = string.format("%s/%s/%s_%s.%s",
        os.date("!%Y%m"), os.date("!%d"), os.date("!%H%M%S"), GenerateUUID(), ext)

    if Config.Target == "AzureBlob" then
        local az_ok, az_result = pcall(AzureSas.BlobSasSign, {
            account_name   = Config.Azure.AccountName,
            account_key    = Config.Azure.AccountKey,
            container_name = Config.Azure.ContainerName,
            blob_name      = file_name,
            permissions    = "cw",
            expiry         = utc_iso8601(600),   -- 10 minutes from now
            protocol       = "https"
        })
        if not az_ok then
            Log.error("AzureSas.BlobSasSign failed (blob=%s): %s", file_name, tostring(az_result))
            return nil
        end
        return {
            presignedUrl = az_result.sasUrl,
            fileUrl      = az_result.url
        }
    elseif Config.Target == "AwsS3" then
        local host     = Config.AwsS3.BucketName .. ".s3." .. Config.AwsS3.Region .. ".amazonaws.com"
        local datetime = os.date("!%Y%m%dT%H%M%SZ")
        local date     = os.date("!%Y%m%d")

        local s3_ok, presigned_url = pcall(AwsSigV4.PresignedUrl, {
            method       = "PUT",
            host         = host,
            path         = "/" .. file_name,
            content_type = mimeType,
            access_key   = Config.AwsS3.AccessKey,
            secret_key   = Config.AwsS3.SecretKey,
            region       = Config.AwsS3.Region,
            service      = "s3",
            date         = date,
            datetime     = datetime,
            expires      = 60,
        })
        if not s3_ok then
            Log.error("AwsSigV4.PresignedUrl failed (key=%s): %s", file_name, tostring(presigned_url))
            return nil
        end
        return {
            presignedUrl = presigned_url,
            fileUrl      = "https://" .. host .. "/" .. file_name
        }
    else
        Log.error("Unknown Config.Target: '%s'", tostring(Config.Target))
        return nil
    end
end)