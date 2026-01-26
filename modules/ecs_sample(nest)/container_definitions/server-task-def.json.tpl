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
      "node",
      "dist/main"
    ],
    "environment": [
      {
        "name": "NODE_ENV",
        "value": "production"
      },
      {
        "name": "PORT",
        "value": "${container_port}"
      },
      {
        "name": "DB_PORT",
        "value": "${db_port}"
      },
      {
        "name": "DB_NAME",
        "value": "${db_name}"
      },
      {
        "name": "DB_SCHEMA",
        "value": "${db_schema}"
      },
      {
        "name": "DB_TIMEZONE",
        "value": "${db_timezone}"
      },
      {
        "name": "WHITE_LIST",
        "value": "${white_list}"
      },
      {
        "name": "JWT_ALGORITHM",
        "value": "${jwt_algorithm}"
      },
      {
        "name": "JWT_EXPIRES_IN",
        "value": "${jwt_expires_in}"
      },
      {
        "name": "REFRESH_TOKEN_EXPIRES_IN",
        "value": "${refresh_token_expires_in}"
      },
      {
        "name": "CRYPTO_ALGORITHM",
        "value": "${crypto_algorithm}"
      },
      {
        "name": "REDIS_URL",
        "value": "${redis_url}"
      },
      {
        "name": "QUEUE_HOST",
        "value": "${queue_host}"
      },
      {
        "name": "QUEUE_PORT",
        "value": "${queue_port}"
      },
      {
        "name": "HTTP_TIMEOUT",
        "value": "${http_timeout}"
      },
      {
        "name": "HTTP_MAX_REDIRECTS",
        "value": "${http_max_redirects}"
      },
      {
        "name": "WCS_ROBOT_API_URL",
        "value": "${wcs_robot_api_url}"
      },
      {
        "name": "WCS_MAX_ROBOT_CALL_QUEUE",
        "value": "${wcs_max_robot_call_queue}"
      },
      {
        "name": "WCS_ROBOT_IDS",
        "value": "${wcs_robot_ids}"
      }
    ],
    "secrets": [
      {
        "valueFrom": "${db_host_secret_arn}",
        "name": "DB_HOST"
      },
      {
        "valueFrom": "${db_user_secret_arn}",
        "name": "DB_USER"
      },
      {
        "valueFrom": "${db_password_secret_arn}",
        "name": "DB_PASSWORD"
      },
      {
        "valueFrom": "${jwt_secret_arn}",
        "name": "JWT_SECRET"
      },
      {
        "valueFrom": "${refresh_token_secret_arn}",
        "name": "REFRESH_TOKEN_SECRET"
      },
      {
        "valueFrom": "${session_secret_arn}",
        "name": "SESSION_SECRET"
      },
      {
        "valueFrom": "${crypto_key_secret_arn}",
        "name": "CRYPTO_KEY"
      },
      {
        "valueFrom": "${crypto_iv_secret_arn}",
        "name": "CRYPTO_IV"
      },
      {
        "valueFrom": "${crypto_salt_secret_arn}",
        "name": "CRYPTO_SALT"
      }
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
      "interval": 10,
      "retries": 10,
      "startPeriod": 10,
      "timeout": 5
    }
  }
]