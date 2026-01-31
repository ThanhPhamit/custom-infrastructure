# 📊 ECS CloudWatch Alarms - Monitoring Report

## 🎯 Purpose

This module monitors **ECS services** - auto-scaling and alerting when CPU/Memory is too high or low.

---

## 🔴 CRITICAL ALERTS (Sent to Slack)

### 🔴 `ecs_memory_utilization_high_alert`

- **Triggers when:** Memory > 90%
- **Meaning:** ECS tasks at critical memory levels
- **Action required:** Investigate application memory consumption immediately

### 🔴 `ecs_cpu_utilization_high_alert`

- **Triggers when:** CPU > 90%
- **Meaning:** ECS tasks at critical CPU levels
- **Action required:** Investigate application CPU usage immediately

### 🔴 `alb_healthy_count_combined`

- **Triggers when:** BOTH Blue AND Green target groups have zero healthy hosts
- **Meaning:** Complete ECS service outage (both environments down)
- **Action required:** Investigate blue/green deployments immediately
- **Note:** Single environment down during normal blue/green deployments is expected

### 🔴 `ecs_service_log_errors_alarm`

- **Triggers when:** Any "error" appears in ECS logs
- **Meaning:** ECS service is experiencing errors
- **Action required:** Check service logs immediately

---

## 🟡 NOTICE ALERTS (FYI - Informational)

### 🟡 `ecs_memory_utilization_high` (Auto-scale)

- **Triggers when:** Memory > 80% (configurable)
- **Meaning:** Memory increasing - auto scaling out (adding tasks)
- **Action:** FYI only - auto-handled

### 🟡 `ecs_cpu_utilization_high` (Auto-scale)

- **Triggers when:** CPU > 80% (configurable)
- **Meaning:** CPU increasing - auto scaling out (adding tasks)
- **Action:** FYI only - auto-handled

### 🟢 `ecs_memory_utilization_low` (Auto-scale in)

- **Triggers when:** Memory < 30% (configurable)
- **Meaning:** Memory low - auto scaling in (removing tasks)
- **Action:** FYI only - auto-handled

### 🟢 `ecs_cpu_utilization_low` (Auto-scale in)

- **Triggers when:** CPU < 30% (configurable)
- **Meaning:** CPU low - auto scaling in (removing tasks)
- **Action:** FYI only - auto-handled

---

## 📋 Summary

| Alert          | Type        | Metric | Action            |
| -------------- | ----------- | ------ | ----------------- |
| Memory > 90%   | 🔴 Critical | Memory | Check immediately |
| CPU > 90%      | 🔴 Critical | CPU    | Check immediately |
| Service Down   | 🔴 Critical | N/A    | Check deployment  |
| Errors in logs | 🔴 Critical | N/A    | Check logs        |
| Memory > 80%   | 🟡 Notice   | Memory | Auto-scale out    |
| CPU > 80%      | 🟡 Notice   | CPU    | Auto-scale out    |
| Memory < 30%   | 🟢 Info     | Memory | Auto-scale in     |
| CPU < 30%      | 🟢 Info     | CPU    | Auto-scale in     |
