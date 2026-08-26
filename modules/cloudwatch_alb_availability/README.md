# cloudwatch_alb_availability

One alarm: **no healthy target behind the ALB**. It is the only thing in a typical stack that tracks
*user-visible* availability.

## Why a host alarm is not enough

| Failure | EC2 status check | host-absent alarm | This alarm |
|---|---|---|---|
| Instance stopped / failed to start | no data → depends on policy | fires | fires (metric absent) |
| Instance healthy, **container dead** | **OK** | **OK** | **fires** |
| Target never registered / empty target group | OK | OK | fires |

The middle row is the point. An EC2 status check passes happily while the process on the box is
gone, and a host-absent alarm sees metrics flowing and stays OK — both green while every request
gets a 503. On a single-instance deployment that row is also the *most likely* failure: a bad deploy,
an OOM kill, a full disk.

## Usage

```hcl
module "alb_availability" {
  source = "../../modules/cloudwatch_alb_availability"

  app_name                 = local.app_name
  load_balancer_arn_suffix = module.alb.alb_arn_suffix          # app/<name>/<id>
  target_group_arn_suffix  = aws_lb_target_group.app.arn_suffix # targetgroup/<name>/<id>
  sns_topic_arn            = module.chatbot_slack.chatbot_sns_topic_arn
}
```

Pass the **arn_suffix**, not the ARN — those are the CloudWatch dimension values. Both inputs
validate the shape, so a full ARN fails at plan time rather than producing an alarm that silently
watches nothing.

## Two things that are easy to get wrong

**`treat_missing_data = "breaching"` is doing half the work.** When no target is registered the ALB
publishes *no* `HealthyHostCount` datapoints — it does not publish a zero (measured through a real
outage on 2026-08-26). With `notBreaching` the alarm is blind to an empty target group entirely.

**`statistic = "Maximum"`, not Average.** Averaged across a period with a flapping target the value
lands between 0 and 1 and never crosses `< 1` cleanly. Maximum asks "was there *ever* a healthy
target in this period", which is the honest reading of an availability alarm.

## On a scheduled resource

`breaching` means this alarm fires on every scheduled stop, so pair it with `alarm_office_hours_gate`
and leave `enable_ok_actions = false` — the gate's morning reset is an `ALARM -> OK` transition and
would otherwise post every working day. `actions_enabled` is already under `lifecycle`
`ignore_changes` so a Terraform apply cannot re-arm it mid-window.

Outputs: `alarm_name` (feed to the gate), `alarm_arn`.
