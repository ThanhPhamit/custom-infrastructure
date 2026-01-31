# 📊 ElastiCache CloudWatch Alarms - Monitoring Report

## 🎯 Purpose

This module monitors **ElastiCache (Redis/Memcached)** - tracks CPU and memory for cache nodes.

---

## 🔴 CRITICAL ALERTS (Sent to Slack)

### 🔴 `elasticache_cpu_critical_per_node`

- **Triggers when:** CPU > 90% (per node)
- **Meaning:** Cache node CPU at critical levels
- **Action required:** Investigate immediately
  - Request rate too high?
  - Need to scale up node type?
  - Optimize cache keys?

### 🔴 `elasticache_memory_usage_critical_per_node`

- **Triggers when:** Memory > 95% (per node)
- **Meaning:** Cache memory critically low
- **Action required:** Investigate immediately
  - Too many cached keys?
  - Need to scale up memory?
  - Should add more nodes?

---

## 🟡 WARNING ALERTS (FYI - Informational)

### 🟡 `elasticache_cpu_warning_per_node`

- **Triggers when:** CPU > 70% (per node)
- **Meaning:** Cache node CPU increasing - FYI
- **Action:** Monitor trend

### 🟡 `elasticache_memory_usage_warning_per_node`

- **Triggers when:** Memory > 80% (per node)
- **Meaning:** Cache memory increasing - FYI
- **Action:** Monitor trend, prepare to scale

---

## 📋 Summary

| Alert           | Type        | Metric | Threshold | Action            |
| --------------- | ----------- | ------ | --------- | ----------------- |
| CPU Critical    | 🔴 Critical | CPU    | > 90%     | Check immediately |
| Memory Critical | 🔴 Critical | Memory | > 95%     | Check immediately |
| CPU Warning     | 🟡 Warning  | CPU    | > 70%     | Monitor           |
| Memory Warning  | 🟡 Warning  | Memory | > 80%     | Monitor           |

---

## 💡 Common Remediation Actions

- **High CPU:** Reduce request rate, optimize cache key patterns, scale up node type
- **High Memory:** Add more nodes, increase node size, clean up expired/unused data
- **Both High:** Implement comprehensive scaling and optimization strategy

---

## 📌 Important Notes

- Each alert is created **per node** (multiple nodes = multiple alerts)
- Dimensions: `CacheClusterId` + `CacheNodeId` help identify which node has issues
- Additional alerts like Cache Hit Ratio, Connections, Evictions are currently **disabled** (commented out)
