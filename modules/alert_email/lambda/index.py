"""SNS → SES Email Forwarder

Receives SNS messages, renders clean HTML emails, sends via Amazon SES.
No unsubscribe links — clean branded notifications.

Supports:
  - CloudWatch Alarm JSON messages (structured table layout)
  - Generic SNS messages (free-form text)
"""

import boto3
import json
import os
import logging
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ses_client = boto3.client(
    "ses",
    region_name=os.environ.get("SES_REGION", os.environ.get("AWS_REGION")),
)

SENDER = os.environ["SENDER_EMAIL"]
RECIPIENTS = json.loads(os.environ["RECIPIENT_EMAILS"])
APP_NAME = os.environ.get("APP_NAME", "Alert")

# ── Colours ──────────────────────────────────────────────────────────────────
HEADER_BG = "#1a237e"
ALARM_RED = "#d32f2f"
OK_GREEN = "#388e3c"
WARN_ORANGE = "#f57c00"


# ── Entry point ──────────────────────────────────────────────────────────────


def handler(event, context):
    for record in event.get("Records", []):
        sns = record.get("Sns", {})
        subject = sns.get("Subject") or "Alert Notification"
        raw = sns.get("Message", "")
        ts = sns.get("Timestamp", datetime.now(timezone.utc).isoformat())

        alarm = _try_parse_alarm(raw)
        if alarm:
            email_subject = _alarm_subject(alarm)
            html = _alarm_html(alarm, ts)
        else:
            email_subject = f"[{APP_NAME}] {subject}"
            html = _generic_html(subject, raw, ts)

        _send(email_subject, html)
        logger.info("Sent → %s | Subject: %s", RECIPIENTS, email_subject)

    return {"statusCode": 200}


# ── Parsers ──────────────────────────────────────────────────────────────────


def _try_parse_alarm(msg):
    """Return parsed dict if *msg* is a CloudWatch Alarm JSON payload."""
    try:
        data = json.loads(msg)
        if "AlarmName" in data and "NewStateValue" in data:
            return data
    except (json.JSONDecodeError, TypeError):
        pass
    return None


# ── Subject builders ─────────────────────────────────────────────────────────


def _alarm_subject(a):
    state = a.get("NewStateValue", "UNKNOWN")
    name = a.get("AlarmName", "Unknown")
    return f"[{APP_NAME}] {state}: {name}"


# ── HTML renderers ───────────────────────────────────────────────────────────


def _alarm_html(a, ts):
    state = a.get("NewStateValue", "UNKNOWN")
    old = a.get("OldStateValue", "UNKNOWN")
    name = _esc(a.get("AlarmName", ""))
    desc = _esc(a.get("AlarmDescription", "N/A"))
    reason = _esc(a.get("NewStateReason", "N/A"))
    region = _esc(a.get("Region", "N/A"))
    account = _esc(a.get("AWSAccountId", "N/A"))
    changed = _esc(a.get("StateChangeTime", ts))

    color = (
        ALARM_RED if state == "ALARM" else OK_GREEN if state == "OK" else WARN_ORANGE
    )

    trigger = a.get("Trigger", {})
    metric = _esc(str(trigger.get("MetricName", "N/A")))
    ns = _esc(str(trigger.get("Namespace", "N/A")))
    stat = _esc(str(trigger.get("Statistic", "N/A")))
    period = _esc(str(trigger.get("Period", "N/A")))
    thresh = _esc(str(trigger.get("Threshold", "N/A")))
    comp = _esc(str(trigger.get("ComparisonOperator", "N/A")))

    dims = "".join(
        f'<tr><td style="padding:6px 12px;color:#555">{_esc(d["name"])}</td>'
        f'<td style="padding:6px 12px">{_esc(d["value"])}</td></tr>'
        for d in trigger.get("Dimensions", [])
    )

    return _wrap(
        f"""
        <tr><td style="padding:24px 24px 0">
          <span style="display:inline-block;background:{color};color:#fff;
                padding:4px 14px;border-radius:4px;font-size:13px;
                font-weight:700;letter-spacing:.5px">{_esc(state)}</span>
          <span style="color:#888;font-size:13px;margin-left:10px">
            {_esc(old)} &rarr; {_esc(state)}</span>
        </td></tr>

        <tr><td style="padding:16px 24px 0">
          <h2 style="margin:0;color:#212121;font-size:16px">{name}</h2>
          <p style="margin:6px 0 0;color:#666;font-size:14px">{desc}</p>
        </td></tr>

        <tr><td style="padding:20px 24px">
          <table width="100%" cellpadding="0" cellspacing="0"
                 style="border:1px solid #e0e0e0;border-radius:6px;
                        overflow:hidden;font-size:13px">
            <tr style="background:#fafafa">
              <td style="padding:6px 12px;color:#555;width:35%">Region</td>
              <td style="padding:6px 12px">{region}</td></tr>
            <tr>
              <td style="padding:6px 12px;color:#555">Account</td>
              <td style="padding:6px 12px">{account}</td></tr>
            <tr style="background:#fafafa">
              <td style="padding:6px 12px;color:#555">Metric</td>
              <td style="padding:6px 12px">{ns} / {metric}</td></tr>
            <tr>
              <td style="padding:6px 12px;color:#555">Statistic</td>
              <td style="padding:6px 12px">{stat} (period {period}s)</td></tr>
            <tr style="background:#fafafa">
              <td style="padding:6px 12px;color:#555">Condition</td>
              <td style="padding:6px 12px">{comp} {thresh}</td></tr>
            <tr>
              <td style="padding:6px 12px;color:#555">Time</td>
              <td style="padding:6px 12px">{changed}</td></tr>
            {dims}
          </table>
        </td></tr>

        <tr><td style="padding:0 24px 20px">
          <div style="background:#f5f5f5;border-left:3px solid {color};
                      padding:12px 16px;border-radius:0 4px 4px 0">
            <p style="margin:0;font-size:13px;color:#333">
              <strong>Reason:</strong> {reason}</p>
          </div>
        </td></tr>"""
    )


def _generic_html(subject, message, ts):
    safe = _esc(message).replace("\n", "<br>")
    return _wrap(
        f"""
        <tr><td style="padding:24px 24px 0">
          <h2 style="margin:0;color:#212121;font-size:16px">{_esc(subject)}</h2>
          <p style="margin:6px 0 0;color:#999;font-size:12px">{_esc(ts)}</p>
        </td></tr>
        <tr><td style="padding:20px 24px">
          <div style="background:#f9f9f9;padding:16px 20px;border-radius:6px;
                      font-size:14px;color:#333;line-height:1.6">
            {safe}
          </div>
        </td></tr>"""
    )


# ── Shared helpers ───────────────────────────────────────────────────────────


def _esc(text):
    """Minimal HTML-entity escaping for untrusted values."""
    return (
        str(text)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def _wrap(content):
    """Wrap *content* rows inside the common email shell (header + footer)."""
    return (
        '<!DOCTYPE html><html><head><meta charset="UTF-8"></head>'
        '<body style="margin:0;padding:0;background:#f4f4f7;'
        "font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif\">"
        '<table width="100%" cellpadding="0" cellspacing="0"'
        ' style="background:#f4f4f7;padding:24px 0">'
        '<tr><td align="center">'
        '<table width="600" cellpadding="0" cellspacing="0"'
        ' style="background:#fff;border-radius:8px;overflow:hidden;'
        'box-shadow:0 2px 8px rgba(0,0,0,.08)">'
        # ── Header
        f'<tr><td style="background:{HEADER_BG};padding:20px 24px">'
        f'<h1 style="margin:0;color:#fff;font-size:18px;font-weight:600">'
        f"{APP_NAME}</h1></td></tr>"
        # ── Dynamic content
        f"{content}"
        # ── Footer
        '<tr><td style="background:#fafafa;padding:16px 24px;'
        'border-top:1px solid #eee">'
        '<p style="margin:0;font-size:12px;color:#999;text-align:center">'
        f"Sent by {APP_NAME} Alert System</p>"
        "</td></tr></table></td></tr></table></body></html>"
    )


def _send(subject, html):
    ses_client.send_email(
        Source=SENDER,
        Destination={"ToAddresses": RECIPIENTS},
        Message={
            "Subject": {"Data": subject, "Charset": "UTF-8"},
            "Body": {"Html": {"Data": html, "Charset": "UTF-8"}},
        },
    )
