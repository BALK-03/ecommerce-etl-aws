import uuid
import time
import json
import boto3
import random
import logging
from faker import Faker
from typing import Iterator
from datetime import datetime, timezone
from botocore.client import BaseClient
from mypy_boto3_s3.client import S3Client

fake = Faker()
Faker.seed(42)
random.seed(42)

def generate_chaos_data(batch_size: int) -> Iterator[list[dict]]:       # a list over a set to have duplicated records (dirty data)
    batch_data = []
    batch_data_size = 100

    for i in range(batch_size):
        payload = {
            'order_id': fake.random_int(min=1000, max=9999),
            'customer_id': fake.random_int(min=10, max=100),
            'product_id': fake.random_int(min=100, max=1000),
            'amount': round(random.uniform(10.0, 500.75), 2),
            'currency': random.choice(['USD', 'EUR', 'MAD']),
            'event_timestamp': fake.date_time_this_year().isoformat(),
            'region': random.choice(['EMEA', 'NA', 'LATAM', 'APAC'])
        }

        random_num = random.randint(1, 100)
        if random_num <= 5:
            chaos_type = random.choice(['null', 'null_region', 'type_error', 'format_error'])

            if chaos_type == 'null_region':
                payload['region'] = None
            elif chaos_type == 'null':
                payload[random.choice(['order_id', 'amount', 'region'])] = None
            elif chaos_type == 'type_error':
                payload['amount'] = 'STR_ERROR_' + str(payload['amount'])
            elif chaos_type == 'format_error':
                payload['event_timestamp'] = '01-01-2025 00:00:00' # breaks the iso format like '2025-03-11T08:53:04.971321'
        
        record = {
            'metadata': {
                'source_system': 'dirty_api_v1',
                'ingestion_timestamp': datetime.now(timezone.utc).isoformat(),
                'schema_version': '1.0'
            },
            'payload': payload
        }
        
        batch_data.append(record)

        if i == batch_size-1 or len(batch_data) == batch_data_size:
            yield batch_data
            batch_data = []


class S3Uploader:
    def __init__(self, bucket_name: str) -> None:
        self.bucket = bucket_name
        
        self.s3_client: S3Client | BaseClient = boto3.client('s3')

    @staticmethod
    def retry_mechanism(operation, max_retries=3, base_delay=1, *args, **kwargs):
        for attempt in range(max_retries):
            try:
                return operation(*args, **kwargs)
            except Exception as e:
                if attempt == max_retries-1:
                    raise TimeoutError
                delay = base_delay * (2 ** attempt)
                time.sleep(delay)

    def upload_to_bronze(self, batch: list[dict]) -> bool:
        if not batch:
            return True
        
        first_payload = batch[0].get('payload', {})

        region = first_payload.get('region') or 'unknown'       # If the region=None then it will catch it and becomes unknown
        now = datetime.now(timezone.utc)

        s3_key = f"orders/region={region}/year={now.year}/month={now.month:02d}/day={now.day:02d}/batch_{uuid.uuid4()}.json"

        json_data = "\n".join([json.dumps(record) for record in batch])
        
        try:
            self.retry_mechanism(
                self.s3_client.put_object,
                Bucket=self.bucket,
                Key=s3_key,
                Body=json_data
            )
            return True
        except TimeoutError as e:
            logging.error(e)
            return False


if __name__ == "__main__":
    import os

    S3_BUCKET = os.getenv('BRONZE_BUCKET_NAME', 'badr-datalake-bronze-us-east-1')
    BATCH_SIZE = 10

    s3_uploader = S3Uploader(bucket_name=S3_BUCKET)
    
    for batch in generate_chaos_data(BATCH_SIZE):
        success = s3_uploader.upload_to_bronze(batch=batch)
        if success:
            print('Successfully uploaded to s3...')
        else:
            print('Problem occured while uploading to s3!')