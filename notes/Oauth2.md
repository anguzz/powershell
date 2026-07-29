# OAuth2 Notes 

## 1. Core Concepts

OAuth2 is an **authorization** framework, not authentication (that's OpenID Connect, built on top of OAuth2). It defines how a client gets a token that lets it act on behalf of a user or itself against a resource server/API.

**Roles:**
- **Resource Owner** — the user (or, for client credentials, there is no user)
- **Client** — the app requesting access (e.g. Entra provisioning connector)
- **Authorization Server** — issues tokens (e.g. Entra's `/oauth2/v2.0/token`, or a vendor's custom `/auth`)
- **Resource Server** — the API being accessed (e.g. Valimail's SCIM API)

**Tokens:**
- **Access token** — short-lived, sent with each API request (`Authorization: Bearer <token>`)
- **Refresh token** — used to get a new access token without re-authenticating (not available in all grant types)

## 2. Grant Types (Flows)

| Grant Type | `grant_type` value | Use Case | Refresh Token? |
|---|---|---|---|
| Authorization Code | `authorization_code` | Web apps with a user login | Yes |
| Authorization Code + PKCE | `authorization_code` | SPAs / mobile apps | Yes |
| Client Credentials | `client_credentials` | Machine-to-machine, no user (SCIM provisioning, daemons) | No |
| Device Code | `urn:ietf:params:oauth:grant-type:device_code` | Devices with no browser (smart TVs, CLI) | Yes |
| Resource Owner Password (ROPC) | `password` | Legacy, direct username/password (avoid if possible) | Yes |
| Implicit | `token` | Legacy SPA flow (deprecated, avoid) | No |
| On-Behalf-Of | `urn:ietf:params:oauth:grant-type:jwt-bearer` | Service calling another service using the user's original token | No |

**Note:** Client Credentials and Implicit grants do **not** support refresh tokens. For client credentials, you just request a new access token again when the old one expires — there's no separate refresh step.

## 3. Client Credentials Grant — Deep Dive

This is the one behind most SCIM/API-to-API integrations (Entra provisioning, backend jobs, etc.).

**Standard (RFC 6749) request:**
```http
POST /token HTTP/1.1
Host: authserver.example.com
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials&client_id=<id>&client_secret=<secret>
```

**Standard response:**
```json
{
  "access_token": "eyJ0eXAi...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

### Client Authentication Methods (how the client proves who it is)

There isn't just one way to send `client_id`/`client_secret` — this is a common source of mismatches:

1. **`client_secret_post`** — credentials in the form body (`client_id=...&client_secret=...`)
2. **`client_secret_basic`** — credentials in an `Authorization: Basic base64(client_id:client_secret)` header, body only has `grant_type`
3. **`client_secret_jwt` / `private_key_jwt`** — a signed JWT assertion instead of a raw secret
4. **Custom/proprietary** — vendor-specific JSON body, custom field names, etc. (this is where things break)

**Known Entra quirk:** Entra's SCIM provisioning OAuth2 Client Credentials option has been observed sending **both** the Basic auth header **and** the credentials in the form body in the same request. Some authorization servers reject this as ambiguous ("multiple client credentials cannot be specified") even though either method alone would work. If a vendor's server is strict about only accepting one method, this can cause a failure that isn't obvious from Entra's side.

## 4. Where Things Actually Break (Real-World Patterns)

Most "it doesn't work with Entra" SCIM/OAuth2 issues fall into one of these buckets:

- **Format mismatch**: Server expects `application/json`, Entra/OAuth2 client sends `application/x-www-form-urlencoded` (or vice versa).
- **Field name mismatch**: Server expects non-standard field names (e.g. `client-id` / `app-id` instead of `client_id` / `client_secret`).
- **Auth method mismatch**: Server only accepts Basic header OR body params, not both — and rejects the request if it sees both (see Entra quirk above).
- **Endpoint isn't actually OAuth2-compliant**: Vendor calls it "OAuth2" or "token endpoint" marketing-wise, but it's really a custom auth scheme that only superficially resembles OAuth2 (client id + secret > token).
- **Token lifetime too short for the connector's refresh cadence**: not a request-format issue, but a common secondary problem once auth itself works.

### HTTP Status Codes Cheat Sheet

| Code | Meaning | Typical Cause |
|---|---|---|
| 400 | Bad Request | Malformed/unexpected request body or params — **not** a credentials problem |
| 401 | Unauthorized | Missing/invalid credentials or token |
| 403 | Forbidden | Valid credentials, but insufficient permissions/scope |
| 404 | Not Found | Wrong endpoint URL |
| 429 | Too Many Requests | Rate limited |
| 500 | Internal Server Error | Server-side failure |

A **400** specifically points you toward "the shape of my request is wrong," not "my credentials are wrong" that distinction saves a lot of debugging time.

## 5. Troubleshooting Methodology (isolate the variable)

When a vendor's endpoint fails an Entra (or any) OAuth2 client credentials test, don't guess reproduce it manually and change one variable at a time:

1. **Test the vendor's documented/custom format first** (Postman or PowerShell) — confirms your credentials are valid and the endpoint is reachable.
2. **Test a standards-compliant OAuth2 form-encoded request** with the same credentials — this isolates whether the failure is about *credentials* or *request format*.
3. **Test with an added `Authorization: Basic` header** (matching Entra's known behavior) — rules in/out the dual-credential quirk specifically.
4. Compare results side by side. If the custom format succeeds and the standard OAuth2 format fails (with or without Basic auth), the vendor's endpoint is not a standards-compliant OAuth2 token endpoint — full stop. This is not a misconfiguration on your end.

### PowerShell Snippets for This

**Custom JSON body test:**
```powershell
$body = @{ "client-id" = $clientId; "app-id" = $appId } | ConvertTo-Json
Invoke-RestMethod -Uri $authUrl -Method Post -Body $body -ContentType "application/json"
```

**Standard OAuth2 form-encoded test:**
```powershell
$body = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
}
Invoke-RestMethod -Uri $authUrl -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
```

**Adding Basic auth header (mimic Entra  behavior):**
```powershell
$pair = "$($clientId):$($clientSecret)"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$basicAuth = [System.Convert]::ToBase64String($bytes)

$headers = @{ Authorization = "Basic $basicAuth" }
Invoke-RestMethod -Uri $authUrl -Method Post -Headers $headers -Body $body -ContentType "application/x-www-form-urlencoded"
```

> Gotcha to remember: `[System.Convert]::ToBase64String(...)` — easy to accidentally drop the `[System.Convert]` part when retyping/copy-pasting and get a confusing `CommandNotFoundException`.

## 6. Entra ID / SCIM-Specific Notes

- Microsoft Entra provisioning connects to a vendor's SCIM 2.0 endpoint; the vendor is responsible for building a SCIM-compliant, and (if using this auth method) OAuth2-compliant, endpoint.
- Auth methods supported in Entra's non-gallery SCIM app provisioning UI: **Basic Auth** (username/password or bearer-style secret token) and **OAuth2 Client Credentials Grant** (newer option).
- The **Bearer Token** method (a long-lived static token pasted into the "Secret Token" field) is the simplest and most compatible option for vendors that don't have a fully standards-compliant OAuth2 token endpoint — this is a reasonable fallback when a vendor's `/auth` endpoint turns out to be non-standard.
- Always verify: does the "Tenant URL" field expect the base SCIM path (`/scim/v2`) or a specific resource path (`/scim/v2/Users`)? Vendors differ here too.

## 7. Case Study: Valimail `/auth` (July 2026)

**Symptom:** Entra provisioning connection test against Valimail's `/auth` failed with `400 Bad Request — invalid request body`.

**Investigation:**
- Valimail's Swagger spec showed `/auth` expects a custom JSON body: `{"client-id": "...", "app-id": "..."}` — non-standard field names, JSON only.
- Entra's OAuth2 Client Credentials grant sends standard form-encoded `grant_type`/`client_id`/`client_secret`.

**Tests run:**
1. Custom JSON format > **Success**, valid token returned.
2. Standard OAuth2 form-encoded > **Failed**, `400 invalid request body`.
3. Standard OAuth2 form-encoded + Basic auth header > **Failed**, same error.

**Conclusion:** `/auth` is not a standards-compliant OAuth2 client_credentials endpoint — it's a custom token endpoint that only accepts its own JSON schema. Entra's built-in SCIM connector cannot authenticate against it in its current form, regardless of configuration. This is a vendor-side limitation, not a config error.

**Takeaway for future vendor evaluations:** Before assuming an Entra provisioning connector is misconfigured, replicate the exact request Entra sends (form-encoded, standard field names, optionally with Basic auth) against the vendor's endpoint directly. If their documented/custom format succeeds but the standard OAuth2 format fails, the vendor's endpoint isn't real OAuth2 — it just looks like it on the surface.

## 8. Quick Reference / Cheat Sheet

```
Is it 400? > Check request format/body, not credentials.
Is it 401? > Check credentials/token validity.
Is it 403? > Check scopes/permissions, not credentials.

Client Credentials Grant = machine-to-machine, no refresh token needed.
Form-encoded ≠ JSON — many vendor "OAuth2" endpoints are actually custom JSON APIs.
Entra may send Basic header + body creds together — some servers reject this as ambiguous.
When in doubt: reproduce the exact request outside of Entra (Postman/PowerShell) and change one variable at a time.
```



I'd replace that table with something more like a "Things That Change the Outcome" section. It reads more like actual field notes and less like documentation trivia.

### 9. Additional Variables to Check

Not every failed OAuth2 test points to a standards compliance issue. A few common implementation differences can change the results:

* **Required `scope` or `resource` parameter**
  * Some authorization servers require additional parameters beyond `grant_type`, `client_id`, and `client_secret`.
  * If documentation mentions scopes, include them in your test request.

* **JWT-based client authentication**
  * Some platforms use `private_key_jwt` or other signed client assertions instead of a client secret.
  * A standard client credentials request will fail even if the endpoint is fully OAuth2 compliant.

* **Mutual TLS (mTLS)**
  * Certain enterprise APIs require a client certificate during token acquisition.
  * Valid credentials alone are insufficient if the certificate is missing.

* **Network intermediaries**
  * Corporate proxies, firewalls, WAFs, or API gateways can alter or block requests.
  * Always consider network path differences when comparing test results between environments.

* **Token endpoint protections**
  * Some vendors enforce rate limits, temporary lockouts, IP restrictions, or anomaly detection.
  * Repeated failed authentication attempts may affect later testing results.

* **Platform/tool differences**
  * Postman, PowerShell, curl, Entra, and vendor SDKs may serialize requests differently.
  * Capturing the raw HTTP request is often more valuable than comparing tool behavior.

* **Access token success ≠ integration success**
  * Obtaining a token only proves authentication succeeded.
  * The token must still contain the correct permissions, scopes, audience, or roles for the target API.

### Troubleshooting Mindset

```
Successful token request = credentials + request format are accepted.

Failed token request = determine whether the issue is:
- Credentials
- Request format
- Client authentication method
- Required parameters
- Network path
- Vendor implementation

Change one variable at a time and compare results.
When possible, inspect the raw HTTP request instead of relying on UI error messages.
```

I think that reads more like durable lab notes you'd actually come back to a year later. The PowerShell version differences and proxy notes are useful, but they're implementation details, not core OAuth2 knowledge, so I'd move them to an appendix or remove them entirely.
