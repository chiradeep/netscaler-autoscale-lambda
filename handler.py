import os
import subprocess
import logging
import boto3
import botocore
import zipfile
import uuid
import base64
from dyndbmutex import DynamoDbMutex

logger = logging.getLogger()
logger.setLevel(logging.INFO)

bindir = os.path.join(os.getcwd(), 'bin')
tfconfig_path = "/tmp/config.zip"
tfconfig_local_dir = "/tmp/tfconfig/config/"
tfconfig_key = "config.zip"

s3_client = boto3.client('s3')
asg_client = boto3.client('autoscaling')
ec2_client = boto3.client('ec2')


def random_name():
    return base64.b32encode(str(uuid.uuid4()))[:8]


def fetch_asg_instance_ips():
    result = []
    asg = os.environ['ASG_NAME']
    groups = asg_client.describe_auto_scaling_groups(AutoScalingGroupNames=[asg])
    for group in groups['AutoScalingGroups']:
        instances = group['Instances']
        for instance in instances:
            instance_id = instance['InstanceId']
            ec2_reservations = ec2_client.describe_instances(InstanceIds=[instance_id])
            for reservation in ec2_reservations['Reservations']:
                ec2_instances = reservation['Instances']
                for ec2_instance in ec2_instances:
                    ec2_instance_id = ec2_instance['InstanceId']
                    logger.info("Found ec2_instance " + ec2_instance_id + " in ASG " + asg + ", state=" + ec2_instance['State']['Name'])
                    if ec2_instance['State']['Name'] != 'running':
                        continue
                    # for interface in ec2_instance['NetworkInterfaces']:
                    # TODO: we assume only one network interface and ip for now
                    net_if = ec2_instance['NetworkInterfaces'][0]
                    logger.info("Found net interface for " + ec2_instance_id + ", state=" + net_if['Status'])
                    if net_if['Status'] == 'in-use':
                        private_ip = net_if['PrivateIpAddresses'][0]['PrivateIpAddress']
                        logger.info("Found private ip for " + ec2_instance_id + ": " + private_ip)
                        result.append(private_ip)
    return result


def find_ns_vpx_instances(subnet_ids, tagkey, tagvalue):
    filters = [{'Name': 'tag:{}'.format(tagkey), 'Values': [tagvalue]}]
    result = []
    reservations = ec2_client.describe_instances(Filters=filters)
    for r in reservations["Reservations"]:
        for instance in r["Instances"]:
            instance_info = {}
            instance_id = instance['InstanceId']
            logger.info("Found NS VPX " + instance_id + ", state=" + instance['State']['Name'])
            if instance['State']['Name'] != 'running':
                continue
            instance_info['instance_id'] = instance_id
            for intf in instance['NetworkInterfaces']:
                if intf['SubnetId'] in subnet_ids:
                    instance_info['ns_url'] = 'http://{}:80/'.format(intf['PrivateIpAddress']) # TODO:https
                    logger.info("NS VPX: " + instance_id + ", private ip=" + intf['PrivateIpAddress'])
                    result.append(instance_info)
                    break
    logger.info("find_ns_vpx_instances:found " +  str(len(result)) + " instances")
    return result


def get_tfstate_path(instance_id):
    return '/tmp/terraform.{}.tfstate'.format(instance_id)

def get_tfstate_key(instance_id):
    return '{}.tfstate'.format(instance_id)

def fetch_tfstate(instance_id):
    bucket = os.environ['S3_TFSTATE_BUCKET']
    try:
        s3_client.download_file(bucket, get_tfstate_key(instance_id), get_tfstate_path(instance_id))
        logger.info("Downloaded tfstate file to " + get_tfstate_path(instance_id))
    except botocore.exceptions.ClientError as e:
        error_code = int(e.response['Error']['Code'])
        if error_code == 404:
            logger.info("Tfstate file does not exist in S3: OK")
        else:
            logger.info("Exception trying to download tfstate file, error_code=" + str(error_code))
            raise


def fetch_tfconfig():
    bucket = os.environ['S3_TFCONFIG_BUCKET']
    try:
        s3_client.download_file(bucket, tfconfig_key, tfconfig_path)
        logger.info("Downloaded tfconfig file to " + tfconfig_path)
        zip_ref = zipfile.ZipFile(tfconfig_path, 'r')
        zip_ref.extractall(tfconfig_local_dir + "../")
        zip_ref.close()
        logger.info("Unzipped tfconfig file to " + tfconfig_local_dir)
    except botocore.exceptions.ClientError as e:
        error_code = int(e.response['Error']['Code'])
        logger.info("Exception trying to download tfconfig file, error_code=" + str(error_code))
        if error_code == 404:
            logger.info("TfConfig zip file does not exist in S3: cannot proceed")
        raise


def upload_tfstate(instance_id):
    bucket = os.environ['S3_TFSTATE_BUCKET']
    s3_client.upload_file(get_tfstate_path(instance_id), bucket, get_tfstate_key(instance_id))
    logger.info("uploaded tfstate file")


def configure_vpx(vpx_info, services):
    try:
        NS_URL = vpx_info['ns_url'] 
        NS_LOGIN = os.environ['NS_LOGIN']
        NS_PASSWORD = vpx_info['instance_id']
        instance_id = vpx_info['instance_id']
        state_bucket = os.environ['S3_TFSTATE_BUCKET']
        config_bucket = os.environ['S3_TFCONFIG_BUCKET']
        asg = os.environ['ASG_NAME']
    except:
        logger.info("Bailing since we can't get the required environment vars")
        return

    logger.info(vpx_info)
    fetch_tfstate(vpx_info['instance_id'])
    fetch_tfconfig()
    command = "NS_URL={} NS_LOGIN={} NS_PASSWORD={} {}/terraform apply -state={} -backup=- -no-color -var-file={}/terraform.tfvars -var 'backend_services=[{}]' {}".format(NS_URL, NS_LOGIN, NS_PASSWORD, bindir, get_tfstate_path(instance_id), tfconfig_local_dir, services, tfconfig_local_dir)
    logger.info("Executing command: " + command)
    try:
        m = DynamoDbMutex(name=instance_id, holder=random_name(), timeoutms=40 * 1000)
        if m.lock():
            tf_output = subprocess.check_output(command, stderr=subprocess.STDOUT, shell=True)
            logger.info(tf_output)
            upload_tfstate(instance_id)
            m.release()
        else:
            logger.info("Failed to acquire mutex (no-op)")
    except subprocess.CalledProcessError as cpe:
        logger.info(cpe.output)
        m.release()
    except:
        logger.info("Caught exception, releasing lock")
        m.release()


def handler(event, context):
    try:
        subnet_ids = os.environ['NS_VPX_SUBNET_IDS'].split(',')
        vpx_tag_key = os.environ['NS_VPX_TAG_KEY']
        vpx_tag_value = os.environ['NS_VPX_TAG_VALUE']
        asg = os.environ['ASG_NAME']
    except:
        logger.info("Bailing since we can't get the required environment vars")
        return
    
    vpx_instances = find_ns_vpx_instances(subnet_ids, vpx_tag_key, vpx_tag_value)
    if len(vpx_instances) == 0:
        logger.info("Couldn't find any VPXs to configure!, Exiting")

    services = ""
    for s in fetch_asg_instance_ips():
        services = services + '"' + s + '",'

    for vpx_info in vpx_instances:
        configure_vpx(vpx_info, services)
