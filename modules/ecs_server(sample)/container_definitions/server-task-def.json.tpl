[
  {
    "name": "${container_name}",
    "image": "${repository_url}:latest",
    "essential": true,
    "memory": ${memory_size},
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-region": "${aws_region}",
        "awslogs-stream-prefix": "${container_name}",
        "awslogs-group": "/ecs_server/${app_name}/${container_name}"
      }
    },
    "command": [
      "/bin/sh",
      "-c",
      "python manage.py migrate && python manage.py runserver 0.0.0.0:${container_port}"
    ],
    "environment": [
      { "name": "ENVIRONMENT", "value": "${environment}" },
      { "name": "ALLOWED_HOSTS", "value": "${allowed_hosts}" },
      { "name": "ERROR_CODE_PREFIX", "value": "${error_code_prefix}" },
      { "name": "TIME_ZONE", "value": "${time_zone}" },
      { "name": "CORS_ALLOWED_ORIGINS", "value": "${cors_allowed_origins}" },
      { "name": "FORWARD_APP_PORT", "value": "${container_port}" },
      { "name": "CLIENT_SERVER", "value": "${client_server}" },
      
      { "name": "POSTGRES_HOST", "value": "${postgres_host}" },
      { "name": "POSTGRES_PORT", "value": "${postgres_port}" },
      { "name": "POSTGRES_DB", "value": "${postgres_db}" },
      { "name": "POSTGRES_USER", "value": "${postgres_user}" },
      { "name": "POSTGRES_SCHEMA", "value": "${postgres_schema}" },
      
      { "name": "CACHE_HOST", "value": "${cache_host}" },
      { "name": "CACHE_PORT", "value": "${cache_port}" },
      
      { "name": "JWT_ALGORITHMS", "value": "${jwt_algorithms}" },
      { "name": "JWT_EXPIRATES", "value": "${jwt_expires}" },
      { "name": "JWT_REFRESH_EXPIRATES", "value": "${jwt_refresh_expires}" },
      
      { "name": "GMO_PREFIX_MEMBER", "value": "${gmo_prefix_member}" },
      { "name": "GMO_SITE_ID", "value": "${gmo_site_id}" },
      { "name": "GMO_SHOP_ID", "value": "${gmo_shop_id}" },
      { "name": "DEV_GMO_BASE_URL", "value": "${dev_gmo_base_url}" },
      { "name": "PROD_GMO_BASE_URL", "value": "${prod_gmo_base_url}" },
      
      { "name": "EMAIL_HOST", "value": "${email_host}" },
      { "name": "EMAIL_PORT", "value": "${email_port}" },
      { "name": "EMAIL_USE_TLS", "value": "${email_use_tls}" },
      { "name": "DEFAULT_FROM_EMAIL", "value": "${default_from_email}" },
      { "name": "EMAIL_SUBJECT_PREFIX", "value": "" },
      
      { "name": "TWILIO_ACCOUNT_SID", "value": "${twilio_account_sid}" },
      { "name": "TWILIO_SERVICE_MESSAGING_SID", "value": "${twilio_service_messaging_sid}" },
      { "name": "PHONE_CODE", "value": "${phone_code}" },
      
      { "name": "TAX", "value": "${tax}" },
      { "name": "INVOICE_TAX", "value": "${invoice_tax}" },
      { "name": "ORDER_PREFIX", "value": "${order_prefix}" },
      { "name": "CONSULTING_PREFIX", "value": "${consulting_prefix}" },
      { "name": "INVOICE_PREFIX", "value": "${invoice_prefix}" },
      { "name": "INVOICE_RANGE_DAYS", "value": "${invoice_range_days}" },
      
      { "name": "AWS_BUCKET", "value": "${aws_bucket}" },
      { "name": "AWS_BUCKET_REGION", "value": "${aws_bucket_region}" },
      { "name": "AWS_PREFIX_FILE_NAME", "value": "${aws_prefix_file_name}" },
      { "name": "AWS_CHIME_DEFAULT_REGION", "value": "${aws_chime_default_region}" },

      { "name": "DEBUG", "value": "${debug}" },
      { "name": "HTTP_X_FORWARDED_PROTO", "value": "${http_x_forwarded_proto}" },
      
      { "name": "INQUIRY_PAYMENT_EMAIL", "value": "${inquiry_payment_email}" },
      { "name": "INQUIRY_ONLINE_CLINIC_SERVICE_EMAIL", "value": "${inquiry_online_clinic_service_email}" },
      { "name": "INQUIRY_OTHER_EMAIL", "value": "${inquiry_other_email}" },
      { "name": "INQUIRY_EMAIL_CC_TO", "value": "${inquiry_email_cc_to}" }
    ],
    "secrets": [
      { "name": "ADMIN_SECRET_KEY", "valueFrom": "${admin_secret_key_secret_arn}" },
      { "name": "JWT_SECRET_KEY", "valueFrom": "${jwt_secret_key_secret_arn}" },
      { "name": "JWT_REFRESH_SECRET_KEY", "valueFrom": "${jwt_refresh_secret_key_secret_arn}" },
      { "name": "CRYPTO_SECRET_KEY", "valueFrom": "${crypto_secret_key_secret_arn}" },
      { "name": "SECRET_KEY", "valueFrom": "${secret_key_secret_arn}" },
      { "name": "POSTGRES_PASSWORD", "valueFrom": "${postgres_password_secret_arn}" },
      { "name": "GMO_SITE_PASS", "valueFrom": "${gmo_site_pass_secret_arn}" },
      { "name": "GMO_SHOP_PASS", "valueFrom": "${gmo_shop_pass_secret_arn}" },
      { "name": "EMAIL_HOST_USER", "valueFrom": "${email_host_user_secret_arn}" },
      { "name": "EMAIL_HOST_PASSWORD", "valueFrom": "${email_host_password_secret_arn}" },
      { "name": "TWILIO_AUTH_TOKEN", "valueFrom": "${twilio_auth_token_secret_arn}" }
    ],
    "portMappings": [
      {
        "containerPort": ${container_port},
        "hostPort": ${container_port}
      }
    ],
    "healthCheck": {
      "command": [
        "CMD-SHELL",
        "curl -f http://localhost:${container_port}${health_check_path} || exit 1"
      ],
      "interval": 30,
      "retries": 5,
      "startPeriod": 60,
      "timeout": 10
    }
  }
]