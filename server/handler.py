import ipaddress
import json
import logging
import os

import boto3

log = logging.getLogger()
log.setLevel(logging.INFO)

HOSTED_ZONE_ID = os.environ["HOSTED_ZONE_ID"]
RECORD_NAME = os.environ["RECORD_NAME"]
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
TTL = int(os.environ.get("TTL", "60"))

route53 = boto3.client("route53")
sns = boto3.client("sns")

FAMILY_TO_TYPE = {4: "A", 6: "AAAA"}


def _response(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def _parse_ip(value, expected_version):
    try:
        addr = ipaddress.ip_address(value)
    except ValueError:
        raise ValueError(f"invalid IP address: {value!r}")
    if addr.version != expected_version:
        raise ValueError(f"expected IPv{expected_version}, got IPv{addr.version}: {value}")
    return str(addr)


def _current_record(rtype):
    resp = route53.list_resource_record_sets(
        HostedZoneId=HOSTED_ZONE_ID,
        StartRecordName=RECORD_NAME,
        StartRecordType=rtype,
        MaxItems="1",
    )
    for rr in resp.get("ResourceRecordSets", []):
        if rr["Name"].rstrip(".") == RECORD_NAME.rstrip(".") and rr["Type"] == rtype:
            values = [r["Value"] for r in rr.get("ResourceRecords", [])]
            return values[0] if values else None
    return None


def _upsert(rtype, value):
    route53.change_resource_record_sets(
        HostedZoneId=HOSTED_ZONE_ID,
        ChangeBatch={
            "Comment": "ddns update",
            "Changes": [
                {
                    "Action": "UPSERT",
                    "ResourceRecordSet": {
                        "Name": RECORD_NAME,
                        "Type": rtype,
                        "TTL": TTL,
                        "ResourceRecords": [{"Value": value}],
                    },
                }
            ],
        },
    )


def handler(event, context):
    try:
        raw = event.get("body") or "{}"
        if event.get("isBase64Encoded"):
            import base64
            raw = base64.b64decode(raw).decode("utf-8")
        payload = json.loads(raw)
    except (ValueError, TypeError) as e:
        log.warning("invalid JSON: %s", e)
        return _response(400, {"error": "invalid JSON body"})

    requested = {}
    try:
        if "ipv4" in payload and payload["ipv4"] is not None:
            requested["A"] = _parse_ip(payload["ipv4"], 4)
        if "ipv6" in payload and payload["ipv6"] is not None:
            requested["AAAA"] = _parse_ip(payload["ipv6"], 6)
    except ValueError as e:
        return _response(400, {"error": str(e)})

    if not requested:
        return _response(400, {"error": "must supply ipv4 and/or ipv6"})

    changed = []
    unchanged = []
    summary_parts = []

    for rtype, new_value in requested.items():
        current = _current_record(rtype)
        if current == new_value:
            unchanged.append(rtype)
            summary_parts.append(f"{rtype} unchanged ({new_value})")
            continue

        _upsert(rtype, new_value)
        changed.append(rtype)
        was = current if current is not None else "none"
        summary_parts.append(f"{rtype} {new_value} (was {was})")

    if changed:
        message = f"{RECORD_NAME} updated: " + "; ".join(summary_parts)
        log.info(message)
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"DDNS: {RECORD_NAME} IP changed",
            Message=message,
        )
    else:
        log.info("%s: no changes (%s)", RECORD_NAME, "; ".join(summary_parts))

    return _response(200, {"changed": changed, "unchanged": unchanged})
