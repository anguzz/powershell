# SAML HTTP-Redirect Binding: Diagnosing an Intermittent "Query String Too Long" Error

## TL;DR

An SP (service provider) was sending signed SAML `AuthnRequest` messages to an IdP using
**HTTP-Redirect binding**, but was signing them the way you're supposed to sign a
**HTTP-POST binding** request — by embedding the full XML signature block (including the
entire X.509 certificate) inside the request itself.

That's backwards for a redirect-bound request. The result: a GET request with a URL that
balloons past most IdPs' query-string limits, causing an intermittent authentication
failure that "goes away" if you just retry.

This writeup documents how I found it, why it happens, and the standard proposed fixes.

---

## Background: two ways to send a SAML AuthnRequest

SAML defines multiple "bindings" — i.e., transport mechanisms — for getting a protocol
message (like an `AuthnRequest`) from the Service Provider (SP) to the Identity Provider
(IdP). The two relevant here:

- **HTTP-POST binding** — the message is submitted as an HTML form field. No practical
  size limit. The signature is embedded directly in the XML (an "enveloped" signature).
- **HTTP-Redirect binding** — the message is deflated, base64-encoded, URL-encoded, and
  stuffed into a query string parameter (`SAMLRequest`) on a redirect URL. This path
  **is** subject to URL/query-string length limits enforced by browsers and servers.

Because these two bindings have very different size constraints, the SAML spec treats
signing differently for each one.

## The relevant spec text (SAML 2.0 Bindings, OASIS, §3.4.4.1 — DEFLATE Encoding)

For HTTP-Redirect binding, the spec is explicit:

> 1. Any signature on the SAML protocol message, including the `<ds:Signature>` XML
>    element itself, **MUST be removed**... SAML protocol messages that contain signed
>    content **SHOULD NOT** be encoded using this mechanism.
> 2. DEFLATE-compress the remaining XML.
> 3. Base64-encode the compressed data.
> 4. URL-encode it and add it as the `SAMLRequest` query parameter.
> 6. If the message needs to be signed, a **new signature covering the encoded data**
>    must be attached using a separate `SigAlg` parameter (identifying the signing
>    algorithm) and a `Signature` parameter (the resulting signature value) — both as
>    their own query string parameters, computed over the encoded `SAMLRequest` (+
>    `RelayState` if present), **not** embedded in the XML.

In short: redirect-bound requests get a **lightweight, detached signature** — just two
short query parameters — never a full embedded `<ds:Signature>` block with a certificate.
(Note: §3.4.5, "Message Exchange," just describes the general request/response sequence
diagram for this binding — it's useful background but isn't where the signing/encoding
rules live. The root cause here is entirely in §3.4.4.1.)

## What we found when we decoded a failed request

- The embedded `<ds:Signature>` element — signature value plus the full X.509
  certificate — accounted for roughly **80% of the AuthnRequest XML's size**.
- After DEFLATE + base64 + URL-encoding, the `SAMLRequest` parameter alone was still
  thousands of characters.
- The IdP appended its own diagnostic query parameters on top (correlation/tracking IDs),
  pushing borderline-sized requests over the query-string limit.
- Because every request has a unique timestamp, ID, and signature, the final encoded
  length varies slightly request to request — explaining why the failure was
  **intermittent** rather than constant, and why simply retrying ("click Play again")
  usually worked.

## ASCII flow chart

**What a spec-correct HTTP-Redirect request should look like:**

```
┌──────────────────────────────────────────────────────────┐
│ Service Provider (SP)                                   │
└──────────────────────────────────────────────────────────┘
                │
                │ Build AuthnRequest XML
                ▼
        [Unsigned XML]
                │
                │ DEFLATE
                │ Base64 Encode
                │ URL Encode
                ▼
        [Encoded SAMLRequest]
                │
                │ Sign:
                │ SAMLRequest
                │ + RelayState
                │ + SigAlg
                ▼
        Add Query Parameters
           SigAlg=<algorithm>
           Signature=<signature>
                │
                ▼
GET /sso?
   SAMLRequest=<compressed-request>
   &SigAlg=<algorithm>
   &Signature=<signature>
                │
                ▼
┌──────────────────────────────────────────────────────────┐
│ Identity Provider (IdP)                                 │
└──────────────────────────────────────────────────────────┘

Result:
- Small URL
- Spec-compliant
- Low risk of URL length issues
```

**What was actually happening (the bug pattern):**

```
┌──────────────────────────────────────────────────────────┐
│ Service Provider (SP)                                   │
└──────────────────────────────────────────────────────────┘
                │
                │ Build AuthnRequest XML
                ▼
        [AuthnRequest]
                │
                │ XML Sign Request
                ▼
        <ds:Signature>
           <SignatureValue>...</SignatureValue>
           <X509Certificate>...</X509Certificate>
        </ds:Signature>
                │
                │ DEFLATE
                │ Base64 Encode
                │ URL Encode
                ▼
        Very Large SAMLRequest
                │
                ▼
GET /sso?
   SAMLRequest=<very large blob>
                │
                │ IdP adds:
                │ correlation IDs
                │ tracking parameters
                ▼
        URL exceeds limit
                │
         ┌──────┴──────┐
         │             │
         ▼             ▼
      Success       Failure
                   "Query String
                    Too Long"
```

## Why this happens (likely root cause)

This is almost never a deliberate design choice — there's no benefit to embedding a
signature in a redirect-bound request, only cost. It's a well-known gap in some SAML
libraries/toolkits: many implementations have a single "sign this request" function that
was originally written for POST binding (sign the whole XML document), and when
redirect-binding support gets added later, it's easy to re-use that same signing function
instead of switching to the detached `SigAlg`/`Signature` parameter method. The request
still validates most of the time (IdPs just parse whatever's in `SAMLRequest`), so the bug
can go unnoticed until a request happens to land right at the size ceiling.

This exact confusion has shown up in real open-source SAML libraries — see the reference
below.

## Possible fixes

1. Switch the AuthnRequest transport to **HTTP-POST binding** (no URL-length ceiling).
2. Keep HTTP-Redirect binding, but sign using the **detached `SigAlg` / `Signature`
   query parameters** instead of an embedded XML signature.
3. Stop signing the AuthnRequest entirely, if that's acceptable for the IdP's security
   requirements (this is common and spec-compliant for SP-initiated redirect flows).

## References

- OASIS, *Bindings for the OASIS Security Assertion Markup Language (SAML) V2.0*,
  Section 3.4.4.1 "DEFLATE Encoding":
  https://docs.oasis-open.org/security/saml/v2.0/saml-bindings-2.0-os.pdf
