import socket
import boto3

def check_tcp_port(host, port):
    try:
        # Create a socket object
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)  # Set a timeout for the connection attempt (in seconds)

        # Attempt to connect to the remote host and port
        sock.connect((host, port))
        sock.close()

        # If the connection was successful, return True
        return True
    except (socket.timeout, ConnectionRefusedError):
        # If the connection attempt times out or is refused, return False
        return False
    except Exception as e:
        # Handle other exceptions as needed
        return str(e)

def send_cloudwatch_metric(metric_name, metric_value):
    cloudwatch = boto3.client('cloudwatch')
    namespace = 'LambdaCustomHC'

    # Send the custom metric to CloudWatch
    response = cloudwatch.put_metric_data(
        Namespace=namespace,
        MetricData=[
            {
                'MetricName': metric_name,
                'Value': metric_value,
                'Unit': 'Count',
                'StorageResolution': 1
            },
        ]
    )

def lambda_handler(event, context):
    port = 8888  # Replace with the TCP port you want to check

    # Checking testnode1
    if check_tcp_port('10.0.0.1', port):
        send_cloudwatch_metric('test_node_1_availability', 1)
    else:
        send_cloudwatch_metric('test_node_1_availability', 0)
        
    # Checking testnode2
    if check_tcp_port('10.0.0.2', port):
        send_cloudwatch_metric('test_node_2_availability', 1)
    else:
        send_cloudwatch_metric('test_node_2_availability', 0)
        
    return {
        'statusCode': 200,
        'body': 'Private endpoint is alive'
    }