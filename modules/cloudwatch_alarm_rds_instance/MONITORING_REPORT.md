# 📊 RDS CloudWatch Alarms - Monitoring Report

## 🎯 Purpose

This module monitors **RDS Database** - tracks CPU, memory, and storage capacity.

---

## 🔴 CRITICAL ALERTS (Sent to Slack)

### 🔴 `rds_cpu_utilization_alert`

- **Triggers when:** CPU > 90%
- **Meaning:** Database CPU at critical levels
- **Action required:** Investigate database performance immediately
  - Are there long-running queries?
  - Too many connections?
  - Need to scale up RDS instance?

### 🔴 `rds_freeable_memory_alert`

- **Triggers when:** Free memory < 100MB (configurable)
- **Meaning:** Database memory critically low
- **Action required:** Investigate immediately
  - Clean up data or cache?
  - Scale up RDS memory?

### 🔴 `rds_freeable_storage_space_alert`

- **Triggers when:** Free storage < 1GB (configurable)
- **Meaning:** Database storage critically low
- **Action required:** Investigate immediately
  - Clean up old logs/data
  - Increase storage volume

---

## 🟡 NOTICE ALERTS (FYI - Informational)

### 🟡 `rds_cpu_utilization_notice`

- **Triggers when:** CPU > 70% (configurable)
- **Meaning:** Database CPU increasing - FYI
- **Action:** Monitor trend

### 🟡 `rds_freeable_memory_notice`

- **Triggers when:** Free memory < 500MB (configurable)
- **Meaning:** Database memory increasing - FYI
- **Action:** Monitor trend

### 🟡 `rds_freeable_storage_space_notice`

- **Triggers when:** Free storage < 5GB (configurable)
- **Meaning:** Database storage increasing - FYI
- **Action:** Monitor trend, prepare to scale

---

## 📋 Summary

| Alert          | Type        | Metric  | Threshold | Action            |
| -------------- | ----------- | ------- | --------- | ----------------- |
| CPU Alert      | 🔴 Critical | CPU     | > 90%     | Check immediately |
| Memory Alert   | 🔴 Critical | Memory  | < 100MB   | Check immediately |
| Storage Alert  | 🔴 Critical | Storage | < 1GB     | Check immediately |
| CPU Notice     | 🟡 Notice   | CPU     | > 70%     | Monitor           |
| Memory Notice  | 🟡 Notice   | Memory  | < 500MB   | Monitor           |
| Storage Notice | 🟡 Notice   | Storage | < 5GB     | Monitor           |

---

## 💡 Troubleshooting Tips

- **High CPU:** Check slow queries, connection count, consider query optimization
- **Low Memory:** Monitor consumption patterns, scale up if needed, optimize caching
- **Low Storage:** Clean old logs/backups, increase volume, archive old data
