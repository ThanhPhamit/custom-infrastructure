import boto3
import os
import json


def lambda_handler(event, context):
    ec2 = boto3.client("ec2")

    tag_key = os.environ["TAG_KEY"]
    tag_value = os.environ["TAG_VALUE"]
    action = event.get("action", "start")  # 'start' or 'stop'

    try:
        # Find instances with the specified tag
        response = ec2.describe_instances(
            Filters=[
                {
                    "Name": f"tag:{tag_key}",
                    "Values": [tag_value],
                },
                {
                    "Name": "instance-state-name",
                    "Values": [
                        "running",
                        "stopped",
                    ],
                },
            ]
        )

        instance_ids = []
        for reservation in response["Reservations"]:
            for instance in reservation["Instances"]:
                instance_ids.append(instance["InstanceId"])

        if not instance_ids:
            print(f"No instances found with tag {tag_key}={tag_value}")
            return {
                "statusCode": 200,
                "body": json.dumps("No instances found to schedule"),
            }

        if action == "start":
            # Start instances that are stopped
            stopped_instances = [
                instance["InstanceId"]
                for reservation in response["Reservations"]
                for instance in reservation["Instances"]
                if instance["State"]["Name"] == "stopped"
            ]

            if stopped_instances:
                ec2.start_instances(InstanceIds=stopped_instances)
                print(f"Started instances: {stopped_instances}")
            else:
                print("No stopped instances to start")

        elif action == "stop":
            # Stop instances that are running
            running_instances = [
                instance["InstanceId"]
                for reservation in response["Reservations"]
                for instance in reservation["Instances"]
                if instance["State"]["Name"] == "running"
            ]

            if running_instances:
                ec2.stop_instances(InstanceIds=running_instances)
                print(f"Stopped instances: {running_instances}")
            else:
                print("No running instances to stop")

        return {
            "statusCode": 200,
            "body": json.dumps(f"Successfully executed {action} on instances"),
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {"statusCode": 500, "body": json.dumps(f"Error: {str(e)}")}
