AwsSigV4 = {}

--- Convert a parameter table to a SigV4 canonical query string
--- @param params table  { key = value, ... }
--- @return string canonical query string
function AwsSigV4.BuildCanonicalQuery(params)
    local entries = {}
    for k, v in pairs(params) do
        entries[#entries + 1] = { Crypto.uri_encode(tostring(k)), Crypto.uri_encode(tostring(v)) }
    end
    -- Sort by key ascending; sort by value ascending for identical keys
    table.sort(entries, function(a, b)
        if a[1] == b[1] then return a[2] < b[2] end
        return a[1] < b[1]
    end)
    local parts = {}
    for _, e in ipairs(entries) do
        parts[#parts + 1] = e[1] .. "=" .. e[2]
    end
    return table.concat(parts, "&")
end


--[[
  PresignedUrl(opts) → presigned URL string (signature embedded in query parameters)

  Generates an AWS SigV4 presigned URL suitable for client-side PUT uploads.
  All authentication information is in the URL query string; no Authorization
  header is required by the uploading client.

  Equivalent to @aws-sdk/s3-request-presigner getSignedUrl() with PutObjectCommand.

  opts fields:
    method       (string)  HTTP method, typically "PUT"
    host         (string)  Hostname, e.g. "my-bucket.s3.ap-northeast-1.amazonaws.com"
    path         (string)  URI path,  e.g. "/uploads/file.jpg"
    content_type (string)  Optional. If set, it is added to signed headers and
                           the uploading client MUST send a matching Content-Type.
    access_key   (string)  AWS access key ID
    secret_key   (string)  AWS secret access key
    region       (string)  AWS region, e.g. "ap-northeast-1"
    service      (string)  AWS service, e.g. "s3" (default: "s3")
    date         (string)  Date YYYYMMDD,          e.g. "20240101"
    datetime     (string)  Datetime ISO8601,        e.g. "20240101T000000Z"
    expires      (number)  Expiry in seconds (default: 60)

  Return: presigned URL string
--]]
function AwsSigV4.PresignedUrl(opts)
    local method  = opts.method:upper()
    local path    = opts.path or "/"
    local expires = opts.expires or 60
    local service = opts.service or "s3"

    -- Credential scope
    local scope      = opts.date .. "/" .. opts.region .. "/" .. service .. "/aws4_request"
    local credential = opts.access_key .. "/" .. scope

    -- Signed headers (sorted alphabetically; "content-type" < "host")
    local signed_headers, canonical_headers_str
    if opts.content_type then
        signed_headers        = "content-type;host"
        canonical_headers_str = "content-type:" .. opts.content_type .. "\n"
                             .. "host:" .. opts.host .. "\n"
    else
        signed_headers        = "host"
        canonical_headers_str = "host:" .. opts.host .. "\n"
    end

    -- Pre-signature query parameters (X-Amz-Signature is excluded until after signing)
    local query_params = {
        ["X-Amz-Algorithm"]     = "AWS4-HMAC-SHA256",
        ["X-Amz-Credential"]    = credential,
        ["X-Amz-Date"]          = opts.datetime,
        ["X-Amz-Expires"]       = tostring(expires),
        ["X-Amz-SignedHeaders"] = signed_headers,
    }
    local query_string = AwsSigV4.BuildCanonicalQuery(query_params)

    -- Canonical request (payload hash = UNSIGNED-PAYLOAD for presigned URLs)
    local canonical_request = table.concat({
        method,
        Crypto.uri_encode(path, true),
        query_string,
        canonical_headers_str,  -- already ends with "\n"; table.concat adds another → blank line
        signed_headers,
        "UNSIGNED-PAYLOAD",
    }, "\n")

    -- String to sign
    local string_to_sign = table.concat({
        "AWS4-HMAC-SHA256",
        opts.datetime,
        scope,
        Crypto.sha256(canonical_request),
    }, "\n")

    -- Derive signing key
    local signing_key = Crypto.hmac_sha256_bytes("AWS4" .. opts.secret_key, opts.date)
    signing_key       = Crypto.hmac_sha256_bytes(signing_key, opts.region)
    signing_key       = Crypto.hmac_sha256_bytes(signing_key, service)
    signing_key       = Crypto.hmac_sha256_bytes(signing_key, "aws4_request")

    -- Signature
    local signature = Crypto.hmac_sha256(signing_key, string_to_sign)

    return "https://" .. opts.host .. path
        .. "?" .. query_string
        .. "&X-Amz-Signature=" .. signature
end
