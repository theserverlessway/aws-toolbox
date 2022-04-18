import boto3
import sys

s3 = boto3.resource('s3')

for bucket in sys.argv[1:]:
    print(bucket)
    bucket = s3.Bucket(bucket)
    bucket.object_versions.delete()
