# DDNS Lambda

AWS Lambda (Python 3.12) that upserts A / AAAA records in Route 53 when the client's public IP changes and publishes a notification to SNS.

## Request

`POST /update` with `x-api-key: <key>` and a JSON body:

```json
{ "ipv4": "203.0.113.42", "ipv6": "2001:db8::1" }
```

- At least one of `ipv4` / `ipv6` is required.
- Either may be omitted or `null`; omitted records are left alone.

## Response

```json
{ "changed": ["A"], "unchanged": ["AAAA"] }
```

- `200` on success (whether or not anything changed).
- `400` on invalid JSON or an IP of the wrong family.
- `500` on unexpected errors (see CloudWatch logs `/aws/lambda/ddns-updater`).

## Environment variables

| Variable | Set by |
|---|---|
| `HOSTED_ZONE_ID` | Terraform (from the existing zone data source) |
| `RECORD_NAME` | Terraform (`var.record_name`) |
| `SNS_TOPIC_ARN` | Terraform |
| `TTL` | Terraform (`var.ttl`, default `60`) |

## Behavior

For each record type supplied, the handler reads the current Route 53 value, compares, and only calls `UPSERT` when the value differs. SNS is only published when at least one record actually changed.
