# CPU Utilization - Warning (Per Node)
resource "aws_cloudwatch_metric_alarm" "elasticache_cpu_utilization_warning_per_node" {
  for_each = var.cache_nodes

  alarm_name          = "${var.app_name}-elasticache-cpu-warning-${each.value.cluster_id}-${each.value.node_id}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = var.period
  datapoints_to_alarm = var.datapoints_to_alarm
  statistic           = "Average"
  threshold           = var.cpu_utilization_warning_threshold
  alarm_description   = "ElastiCache CPU utilization is high on cluster ${each.value.cluster_id} node ${each.value.node_id}"
  alarm_actions       = [var.chatbot_notice_sns_topic_arn]
  ok_actions          = [var.chatbot_notice_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    CacheClusterId = each.value.cluster_id
    CacheNodeId    = each.value.node_id
  }

  tags = merge(
    var.tags,
    {
      Name      = "${var.app_name}-elasticache-cpu-warning-${each.value.cluster_id}-${each.value.node_id}"
      ClusterId = each.value.cluster_id
      NodeId    = each.value.node_id
    }
  )
}

# CPU Utilization - Critical (Per Node)
resource "aws_cloudwatch_metric_alarm" "elasticache_cpu_utilization_critical_per_node" {
  for_each = var.cache_nodes

  alarm_name          = "${var.app_name}-elasticache-cpu-critical-${each.value.cluster_id}-${each.value.node_id}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.critical_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = var.critical_period
  datapoints_to_alarm = var.critical_datapoints_to_alarm
  statistic           = "Average"
  threshold           = var.cpu_utilization_critical_threshold
  alarm_description   = "ElastiCache CPU utilization is critically high on cluster ${each.value.cluster_id} node ${each.value.node_id}"
  alarm_actions       = [var.chatbot_alert_sns_topic_arn]
  ok_actions          = [var.chatbot_alert_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    CacheClusterId = each.value.cluster_id
    CacheNodeId    = each.value.node_id
  }

  tags = merge(
    var.tags,
    {
      Name      = "${var.app_name}-elasticache-cpu-critical-${each.value.cluster_id}-${each.value.node_id}"
      ClusterId = each.value.cluster_id
      NodeId    = each.value.node_id
    }
  )
}

# Database Memory Usage - Warning (Per Node)
resource "aws_cloudwatch_metric_alarm" "elasticache_memory_usage_warning_per_node" {
  for_each = var.cache_nodes

  alarm_name          = "${var.app_name}-elasticache-memory-warning-${each.value.cluster_id}-${each.value.node_id}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = var.period
  datapoints_to_alarm = var.datapoints_to_alarm
  statistic           = "Average"
  threshold           = var.database_memory_usage_warning_threshold
  alarm_description   = "ElastiCache memory usage is high on cluster ${each.value.cluster_id} node ${each.value.node_id}"
  alarm_actions       = [var.chatbot_notice_sns_topic_arn]
  ok_actions          = [var.chatbot_notice_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    CacheClusterId = each.value.cluster_id
    CacheNodeId    = each.value.node_id
  }

  tags = merge(
    var.tags,
    {
      Name      = "${var.app_name}-elasticache-memory-warning-${each.value.cluster_id}-${each.value.node_id}"
      ClusterId = each.value.cluster_id
      NodeId    = each.value.node_id
    }
  )
}

# Database Memory Usage - Critical
resource "aws_cloudwatch_metric_alarm" "elasticache_memory_usage_critical_per_node" {
  for_each = var.cache_nodes

  alarm_name          = "${var.app_name}-elasticache-memory-critical-${each.value.cluster_id}-${each.value.node_id}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.critical_evaluation_periods
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = var.critical_period
  datapoints_to_alarm = var.critical_datapoints_to_alarm
  statistic           = "Average"
  threshold           = var.database_memory_usage_critical_threshold
  alarm_description   = "ElastiCache memory usage is critically high on cluster ${each.value.cluster_id} node ${each.value.node_id}"
  alarm_actions       = [var.chatbot_alert_sns_topic_arn]
  ok_actions          = [var.chatbot_alert_sns_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    CacheClusterId = each.value.cluster_id
    CacheNodeId    = each.value.node_id
  }

  tags = merge(
    var.tags,
    {
      Name      = "${var.app_name}-elasticache-memory-critical-${each.value.cluster_id}-${each.value.node_id}"
      ClusterId = each.value.cluster_id
      NodeId    = each.value.node_id
    }
  )
}

# # Cache Hit Ratio (Per Node)
# resource "aws_cloudwatch_metric_alarm" "elasticache_cache_hit_ratio_per_node" {
#   for_each = var.cache_nodes

#   alarm_name          = "${var.app_name}-elasticache-cache-hit-ratio-low-${each.value.cluster_id}-${each.value.node_id}"
#   comparison_operator = "LessThanThreshold"
#   evaluation_periods  = var.evaluation_periods
#   metric_name         = "CacheHitRate"
#   namespace           = "AWS/ElastiCache"
#   period              = var.period
#   datapoints_to_alarm = var.datapoints_to_alarm
#   statistic           = "Average"
#   threshold           = var.cache_hit_ratio_threshold
#   alarm_description   = "ElastiCache cache hit ratio is low on cluster ${each.value.cluster_id} node ${each.value.node_id}"
#   alarm_actions       = [var.chatbot_notice_sns_topic_arn]
#   ok_actions          = [var.chatbot_notice_sns_topic_arn]
#   treat_missing_data  = "notBreaching"

#   dimensions = {
#     CacheClusterId = each.value.cluster_id
#     CacheNodeId    = each.value.node_id
#   }

#   tags = merge(
#     var.tags,
#     {
#       Name      = "${var.app_name}-elasticache-cache-hit-ratio-low-${each.value.cluster_id}-${each.value.node_id}"
#       ClusterId = each.value.cluster_id
#       NodeId    = each.value.node_id
#     }
#   )
# }


# # Current Connections (Per Node)
# resource "aws_cloudwatch_metric_alarm" "elasticache_curr_connections_per_node" {
#   for_each = var.cache_nodes

#   alarm_name          = "${var.app_name}-elasticache-connections-high-${each.value.cluster_id}-${each.value.node_id}"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = var.evaluation_periods
#   metric_name         = "CurrConnections"
#   namespace           = "AWS/ElastiCache"
#   period              = var.period
#   datapoints_to_alarm = var.datapoints_to_alarm
#   statistic           = "Average"
#   threshold           = var.curr_connections_threshold
#   alarm_description   = "ElastiCache current connections is high on cluster ${each.value.cluster_id} node ${each.value.node_id}"
#   alarm_actions       = [var.chatbot_notice_sns_topic_arn]
#   ok_actions          = [var.chatbot_notice_sns_topic_arn]
#   treat_missing_data  = "notBreaching"

#   dimensions = {
#     CacheClusterId = each.value.cluster_id
#     CacheNodeId    = each.value.node_id
#   }

#   tags = merge(
#     var.tags,
#     {
#       Name      = "${var.app_name}-elasticache-connections-high-${each.value.cluster_id}-${each.value.node_id}"
#       ClusterId = each.value.cluster_id
#       NodeId    = each.value.node_id
#     }
#   )
# }

# # Evictions (Per Node)
# resource "aws_cloudwatch_metric_alarm" "elasticache_evictions_per_node" {
#   for_each = var.cache_nodes

#   alarm_name          = "${var.app_name}-elasticache-evictions-high-${each.value.cluster_id}-${each.value.node_id}"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = var.evaluation_periods
#   metric_name         = "Evictions"
#   namespace           = "AWS/ElastiCache"
#   period              = var.period
#   datapoints_to_alarm = var.datapoints_to_alarm
#   statistic           = "Sum"
#   threshold           = var.evictions_threshold
#   alarm_description   = "ElastiCache evictions are high on cluster ${each.value.cluster_id} node ${each.value.node_id}"
#   alarm_actions       = [var.chatbot_alert_sns_topic_arn]
#   ok_actions          = [var.chatbot_alert_sns_topic_arn]
#   treat_missing_data  = "notBreaching"

#   dimensions = {
#     CacheClusterId = each.value.cluster_id
#     CacheNodeId    = each.value.node_id
#   }

#   tags = merge(
#     var.tags,
#     {
#       Name      = "${var.app_name}-elasticache-evictions-high-${each.value.cluster_id}-${each.value.node_id}"
#       ClusterId = each.value.cluster_id
#       NodeId    = each.value.node_id
#     }
#   )
# }

# # Network Bytes In (Per Node)
# resource "aws_cloudwatch_metric_alarm" "elasticache_network_bytes_in_per_node" {
#   for_each = var.cache_nodes

#   alarm_name          = "${var.app_name}-elasticache-network-bytes-in-high-${each.value.cluster_id}-${each.value.node_id}"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = var.evaluation_periods
#   metric_name         = "NetworkBytesIn"
#   namespace           = "AWS/ElastiCache"
#   period              = var.period
#   datapoints_to_alarm = var.datapoints_to_alarm
#   statistic           = "Average"
#   threshold           = var.network_bytes_in_threshold
#   alarm_description   = "ElastiCache network bytes in is high on cluster ${each.value.cluster_id} node ${each.value.node_id}"
#   alarm_actions       = [var.chatbot_notice_sns_topic_arn]
#   ok_actions          = [var.chatbot_notice_sns_topic_arn]
#   treat_missing_data  = "notBreaching"

#   dimensions = {
#     CacheClusterId = each.value.cluster_id
#     CacheNodeId    = each.value.node_id
#   }

#   tags = merge(
#     var.tags,
#     {
#       Name      = "${var.app_name}-elasticache-network-bytes-in-high-${each.value.cluster_id}-${each.value.node_id}"
#       ClusterId = each.value.cluster_id
#       NodeId    = each.value.node_id
#     }
#   )
# }

# # Network Bytes Out (Per Node)
# resource "aws_cloudwatch_metric_alarm" "elasticache_network_bytes_out_per_node" {
#   for_each = var.cache_nodes

#   alarm_name          = "${var.app_name}-elasticache-network-bytes-out-high-${each.value.cluster_id}-${each.value.node_id}"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = var.evaluation_periods
#   metric_name         = "NetworkBytesOut"
#   namespace           = "AWS/ElastiCache"
#   period              = var.period
#   datapoints_to_alarm = var.datapoints_to_alarm
#   statistic           = "Average"
#   threshold           = var.network_bytes_out_threshold
#   alarm_description   = "ElastiCache network bytes out is high on cluster ${each.value.cluster_id} node ${each.value.node_id}"
#   alarm_actions       = [var.chatbot_notice_sns_topic_arn]
#   ok_actions          = [var.chatbot_notice_sns_topic_arn]
#   treat_missing_data  = "notBreaching"

#   dimensions = {
#     CacheClusterId = each.value.cluster_id
#     CacheNodeId    = each.value.node_id
#   }

#   tags = merge(
#     var.tags,
#     {
#       Name      = "${var.app_name}-elasticache-network-bytes-out-high-${each.value.cluster_id}-${each.value.node_id}"
#       ClusterId = each.value.cluster_id
#       NodeId    = each.value.node_id
#     }
#   )
# }

# # GET Commands (Per Node) - Low activity detection
# resource "aws_cloudwatch_metric_alarm" "elasticache_get_commands_per_node" {
#   for_each = var.cache_nodes

#   alarm_name          = "${var.app_name}-elasticache-get-commands-low-${each.value.cluster_id}-${each.value.node_id}"
#   comparison_operator = "LessThanThreshold"
#   evaluation_periods  = var.evaluation_periods
#   metric_name         = "GetTypeCmds"
#   namespace           = "AWS/ElastiCache"
#   period              = var.period
#   datapoints_to_alarm = var.datapoints_to_alarm
#   statistic           = "Sum"
#   threshold           = 1
#   alarm_description   = "ElastiCache GET commands are unusually low on cluster ${each.value.cluster_id} node ${each.value.node_id} - possible connectivity issue"
#   alarm_actions       = [var.chatbot_notice_sns_topic_arn]
#   ok_actions          = [var.chatbot_notice_sns_topic_arn]
#   treat_missing_data  = "breaching"

#   dimensions = {
#     CacheClusterId = each.value.cluster_id
#     CacheNodeId    = each.value.node_id
#   }

#   tags = merge(
#     var.tags,
#     {
#       Name      = "${var.app_name}-elasticache-get-commands-low-${each.value.cluster_id}-${each.value.node_id}"
#       ClusterId = each.value.cluster_id
#       NodeId    = each.value.node_id
#     }
#   )
# }
