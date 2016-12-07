import os
import subprocess
import logging
import boto3
import botocore
import zipfile

logger = logging.getLogger()
logger.setLevel(logging.INFO)

bindir = os.path.join(os.getcwd(), 'bin')
s3_client = boto3.client('s3')
tfstate_path = "/tmp/terraform.tfstate"
tfconfig_path = "/tmp/config.zip"
tfconfig_local_dir = "/tmp/tfconfig/config/"
tfstate_key = "tfstate"
tfconfig_key = "config.zip"


def fetch_tfstate():
    bucket = os.environ['S3_TFSTATE_BUCKET']
    try:
        s3_client.download_file(bucket, tfstate_key, tfstate_path)
    except botocore.exceptions.ClientError as e:
        error_code = int(e.response['Error']['Code'])
        if error_code == 404:
            logger.info("Tfstate file does not exist in S3: OK")
        else:
            raise

def fetch_tfconfig():
    bucket = os.environ['S3_TFCONFIG_BUCKET']
    try:
        s3_client.download_file(bucket, tfconfig_key,  tfconfig_path)
        zip_ref = zipfile.ZipFile(tfconfig_path, 'r')
        zip_ref.extractall(tfconfig_local_dir + "../")
        zip_ref.close()
    except botocore.exceptions.ClientError as e:
        error_code = int(e.response['Error']['Code'])
        if error_code == 404:
            logger.info("TfConfig zip file does not exist in S3: cannot proceed")
        raise

def upload_tfstate():
    bucket = os.environ['S3_TFSTATE_BUCKET']
    s3_client.upload_file(tfstate_path, bucket, tfstate_key)


def handler(event, context):

    try:
        NS_URL = os.environ['NS_URL']
        NS_LOGIN = os.environ['NS_LOGIN']
        NS_PASSWORD = os.environ['NS_PASSWORD']
        s3_tfstate_bucket = os.environ['S3_TFSTATE_BUCKET']
    except:
        logger.info("Bailing since we can't get the required environment vars")
        return

    services = ""
    for s in event['backend_services']:
        services = services + '"' + s + '",'

    logger.info("Service members are " + services)

    fetch_tfstate()
    fetch_tfconfig()
    command = "NS_URL={} NS_LOGIN={} NS_PASSWORD={} {}/terraform apply -state={} -backup=- -no-color -var-file={}/terraform.tfvars -var 'backend_services=[{}]' {}".format(NS_URL, NS_LOGIN, NS_PASSWORD, bindir, tfstate_path, tfconfig_local_dir, services, tfconfig_local_dir)
    try:
        tf_output = subprocess.check_output(command, stderr=subprocess.STDOUT, shell=True)
        logger.info(tf_output)
        upload_tfstate()
    except subprocess.CalledProcessError as cpe:
           logger.info(cpe.output)

