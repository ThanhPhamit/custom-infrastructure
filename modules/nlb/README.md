# ECS Nest Module

## AWS Commands to Check Available IP Addresses

### 1. Check Subnet Information and Available IP Count

```bash
aws ec2 describe-subnets --profile welfan-lg-mfa --region ap-northeast-3 --filters "Name=cidr-block,Values=192.168.26.128/26" --query 'Subnets[*].[SubnetId,CidrBlock,AvailableIpAddressCount]' --output table
```

**Output:**

```
---------------------------------------------------------
|                    DescribeSubnets                    |
+---------------------------+---------------------+-----+
|  subnet-0d052d81b1c098346 |  192.168.26.128/26  |  41 |
+---------------------------+---------------------+-----+
```

### 2. Check Currently Used IP Addresses

```bash
aws ec2 describe-network-interfaces --profile welfan-lg-mfa --region ap-northeast-3 --filters "Name=subnet-id,Values=subnet-0d052d81b1c098346" --query 'NetworkInterfaces[*].PrivateIpAddress' --output table
```

**Output:**

```
---------------------------
|DescribeNetworkInterfaces|
+-------------------------+
|  192.168.26.141         |
|  192.168.26.174         |
|  192.168.26.147         |
|  192.168.26.171         |
|  192.168.26.138         |
|  192.168.26.167         |
|  192.168.26.170         |
|  192.168.26.145         |
|  192.168.26.150         |
|  192.168.26.159         |
|  192.168.26.186         |
|  192.168.26.133         |
|  192.168.26.142         |
|  192.168.26.172         |
|  192.168.26.177         |
|  192.168.26.180         |
|  192.168.26.182         |
|  192.168.26.158         |
+-------------------------+
```

### IP Range Information

- **CIDR Block:** 192.168.26.128/26
- **Total IPs:** 64 (192.168.26.128 - 192.168.26.191)
- **Usable IP Range:** 192.168.26.132 - 192.168.26.190 (59 usable IPs)
- **Reserved IPs:**
  - 192.168.26.128: Network address
  - 192.168.26.129: VPC router (gateway)
  - 192.168.26.130: DNS server
  - 192.168.26.131: Future use
  - 192.168.26.191: Broadcast address
- **Currently Used:** 18 IPs (shown in command output above)
- **Available:** 41 IPs

### Notes

- Choose any IP from the range 192.168.26.132 - 192.168.26.190 that doesn't appear in the "Currently Used" list
- Always run these commands before selecting an IP to ensure it's still available
