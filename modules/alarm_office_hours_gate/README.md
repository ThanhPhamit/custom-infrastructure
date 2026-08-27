# alarm_office_hours_gate

Arms a set of CloudWatch alarms only during the hours the resource they watch is scheduled to be
running, using EventBridge Scheduler universal targets. No Lambda.

## The problem

An alarm whose metric **disappears** when the resource stops has to pick a `treat_missing_data`
policy, and on a scheduled resource both choices are wrong:

| Policy | Scheduled stop | Failed start |
|---|---|---|
| `notBreaching` | silent ✅ | **silent** ❌ |
| `breaching` | pages every night ❌ | fires ✅ |

Gating the alarm's **actions** by time lets it keep `breaching` and still stay quiet while the
resource is legitimately off.

Measured on a live single-instance stack, 2026-08-26: a scheduler `StartInstances` call returned success,
EC2 failed the launch internally (`Server.InternalError`), the host never booted, and nothing
alarmed for nine hours because the only host alarm was `notBreaching`.

## Usage

```hcl
module "alarm_gate" {
  source = "../../modules/alarm_office_hours_gate"

  app_name    = local.app_name
  alarm_names = [module.host_obs.host_absent_alarm_name]

  timezone          = "Asia/Tokyo"
  disarm_expression = "cron(55 20 ? * MON-FRI *)" # 5 min BEFORE the resource stops
  arm_expression    = "cron(5 8 ? * MON-FRI *)"   # after it starts
  reset_expression  = "cron(10 8 ? * MON-FRI *)"  # AFTER arm — see below
  dead_letter_arn   = aws_sqs_queue.scheduler_dlq.arn
}
```

The gated alarms must have **empty `ok_actions`** — the morning reset is an `ALARM -> OK`
transition and would otherwise post to chat every working day.

## Why there are three schedules and not two

**Enabling actions is not a state transition.** An alarm that sat in `ALARM` all night is still in
`ALARM` when you arm it, so nothing is sent — arming alone would produce a gate that looks correct
in the console and never fires. The reset is what manufactures a transition for CloudWatch to react
to:

```
20:55  disarm   DisableAlarmActions        (resource still up; alarm OK)
21:00           resource stops             alarm -> ALARM, silent
08:00           resource starts
08:05  arm      EnableAlarmActions         alarm still ALARM, no transition, silent
08:10  reset    SetAlarmState(OK)          silent (ok_actions is empty)
08:12           CloudWatch evaluates       up -> stays OK  |  absent -> OK -> ALARM -> notifies
```

Reversing `arm` and `reset` is the one mistake that produces no symptom at all. Verified end to end
on 2026-08-26: with the gate disarmed a forced `OK -> ALARM` transition produced **no** action entry
in the alarm history and **zero** SNS publishes; a `breaching` alarm with no data produced
`Successfully executed action arn:aws:sns:…` and `NumberOfNotificationsDelivered = 1`.

## Notes

- The IAM policy is scoped to exactly the alarms passed in; ARNs are built from the names.
- Trust is `aws:SourceAccount` **only**. Adding an `ArnLike` on `aws:SourceArn` breaks
  `CreateSchedule`, which validates role assumption before the schedule exists.
- A freshly created role can lose a `CreateSchedule` race to IAM propagation with the same
  "must allow AWS EventBridge Scheduler to assume the role" message. Retry before suspecting policy.
- Give it a `dead_letter_arn`. A failed **arm** is a silently disarmed alarm — the exact failure this
  module exists to prevent — and the DLQ is the only place it surfaces.

## Inputs / Outputs

| Input | Default |
|---|---|
| `app_name`, `alarm_names` | required |
| `timezone` | `Asia/Tokyo` |
| `disarm_expression` / `arm_expression` / `reset_expression` | `cron(55 19 …)` / `cron(5 8 …)` / `cron(10 8 …)` |
| `reset_state_reason` | explanatory string shown in alarm history |
| `enabled`, `kms_key_arn`, `dead_letter_arn`, `retry_*`, `tags` | see `variables.tf` |

Outputs: `role_arn`, `schedule_names`, `gated_alarm_arns`.
