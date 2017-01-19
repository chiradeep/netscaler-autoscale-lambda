import boto3
import botocore
import logging
import os
import socket
import struct
import urllib2
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)
logging.getLogger('boto3').setLevel(logging.WARNING)
logging.getLogger('botocore').setLevel(logging.WARNING)

ec2_client = boto3.client('ec2')

asg_client = boto3.client('autoscaling')


def get_subnet(az, vpc_id, tag_key, tag_value):
    filters = [{'Name': 'availability-zone', 'Values': [az]},
               {'Name': 'vpc-id', 'Values': [vpc_id]},
               {'Name': 'tag-key', 'Values': [tag_key]}]
    subnets = ec2_client.describe_subnets(Filters=filters)
    for subnet in subnets['Subnets']:
        for tag in subnet['Tags']:
            if tag['Key'] == tag_key and tag_value in tag['Value']:
                return subnet['SubnetId']
    return None


def get_instance(instance_id):
    ec2_reservations = ec2_client.describe_instances(InstanceIds=[instance_id])
    for reservation in ec2_reservations['Reservations']:
        ec2_instances = reservation['Instances']
        for ec2_instance in ec2_instances:
            return ec2_instance
    return None


def attach_eip(public_ips, interface_id):
    filters = [{'Name': 'domain', 'Values': ['vpc']},
               {'Name': 'association-id', 'Values': []}]
    addresses = ec2_client.describe_addresses(PublicIps=public_ips,
                                              Filters=filters)['Addresses']
    if len(addresses) == 0:
        raise Exception("Could not find a free elastic ip")
    response = ec2_client.associate_address(PublicIp=addresses[0],
                                            NetworkInterfaceId=interface_id)
    return response['AssociationId']


def configure_snip(instance_id, ns_url, server_eni, server_subnet):
    # the SNIP is unconfigured on a freshly installed VPX. We don't
    # know if the SNIP is already configured, but try anyway. Ignore
    # 409 conflict errors
    NS_PASSWORD = os.getenv('NS_PASSWORD', instance_id)
    if NS_PASSWORD == 'SAME_AS_INSTANCE_ID':
        NS_PASSWORD = instance_id
    url = ns_url + 'nitro/v1/config/nsip'
    snip = server_eni['PrimaryIpAddress']
    subnet_len = server_subnet['CidrBlock'].split("/")[1]
    mask = (1 << 32) - (1 << 32 >> subnet_len)
    subnet_mask = socket.inet_ntoa(struct.pack(">L", mask))

    jsons = '{{"nsip":{{"ipaddress":"{}", "netmask":"{}", "type":"snip"}}}}'.format(snip, subnet_mask)
    headers = {'Content-Type': 'application/json', 'X-NITRO-USER': 'nsroot', 'X-NITRO-PASS': NS_PASSWORD}
    r = urllib2.Request(url, data=jsons, headers=headers)
    try:
        urllib2.urlopen(r)
        logger.info("Configured SNIP: snip= " + snip)
    except urllib2.HTTPError as hte:
        if hte.code != 409:
            logger.info("Error configuring SNIP: Error code: " +
                        str(hte.code) + ", reason=" + hte.reason)
        else:
            logger.info("SNIP already configured")


def lambda_handler(event, context):
    instance_id = event["detail"]["EC2InstanceId"]
    try:
        PUBLIC_IPS = os.environ['PUBLIC_IPS']
    except KeyError as ke:
        logger.warn("Bailing since we can't get the required variable: " +
                    ke.args[0])
        return

    if event['detail-type'] == "EC2 Instance-launch Lifecycle Action":
        instance = get_instance(instance_id)
        az = instance['Placement']['AvailabilityZone']
        vpc_id = instance['VpcId']


        ns_url = 'http://{}:80/'.format(instance['PrivateIpAddress'])  # TODO:https
        public_subnet = get_subnet(az, vpc_id, 'Name', 'public-subnet')
        private_subnet = get_subnet(az, vpc_id, 'Name', 'private-subnet')
        client_interface_id = None
        server_interface_id = None
        try:
            client_interface = create_interface(public_subnet['SubnetId'])
            attach_interface(client_interface['NetworkInterfaceId'], instance_id, 1)
            server_interface = create_interface(private_subnet['SubnetId'])
            attach_interface(server_interface['NetworkInterfaceId'], instance_id, 2)
            attach_eip(PUBLIC_IPS, client_interface['NetworkInterfaceId'])
            configure_snip(instance_id, ns_url, server_interface, private_subnet)
        except:
            if client_interface_id:
                log("Removing client network interface {} after attachment failed.".format(
                    client_interface_id))
                delete_interface(client_interface_id)
            if server_interface_id:
                log("Removing server network interface {} after attachment failed.".format(
                    server_interface_id))
                delete_interface(server_interface_id)

        try:
            asg_client.complete_lifecycle_action(
                LifecycleHookName=event['detail']['LifecycleHookName'],
                AutoScalingGroupName=event['detail']['AutoScalingGroupName'],
                LifecycleActionToken=event['detail']['LifecycleActionToken'],
                LifecycleActionResult='CONTINUE'
            )
        except botocore.exceptions.ClientError as e:
            log("Error completing life cycle hook for instance {}: {}".format(
                instance_id, e.response['Error']['Code']))
            log('{"Error": "1"}')


def create_interface(subnet_id):
    network_interface_id = None
    if subnet_id:
        try:
            network_interface = ec2_client.create_network_interface(
                SubnetId=subnet_id)
            network_interface_id = network_interface[
                'NetworkInterface']['NetworkInterfaceId']
            log("Created network interface: {}".format(network_interface_id))
            return network_interface['NetworkInterface']

        except botocore.exceptions.ClientError as e:
            log("Error creating network interface: {}".format(
                e.response['Error']['Code']))
            raise

    return network_interface


def attach_interface(network_interface_id, instance_id, index):
    attachment = None
    if network_interface_id and instance_id:
        try:
            attach_interface = ec2_client.attach_network_interface(
                NetworkInterfaceId=network_interface_id,
                InstanceId=instance_id,
                DeviceIndex=index
            )
            attachment = attach_interface['AttachmentId']
            log("Created network attachment: {}".format(attachment))

        except botocore.exceptions.ClientError as e:
            log("Error attaching network interface: {}".format(
                e.response['Error']['Code']))
            raise

    return attachment


def delete_interface(network_interface_id):
    try:
        ec2_client.delete_network_interface(
            NetworkInterfaceId=network_interface_id
        )

    except botocore.exceptions.ClientError as e:
        log("Error deleting interface {}: {}".format(
            network_interface_id, e.response['Error']['Code']))


def log(message):
    print (datetime.utcnow().isoformat() + 'Z ' + message)
