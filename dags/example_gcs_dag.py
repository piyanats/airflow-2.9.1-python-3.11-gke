"""
Example DAG demonstrating GCS operations
This DAG will work when GCP credentials are properly configured
"""
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator

# Uncomment when GCP is configured
# from airflow.providers.google.cloud.operators.gcs import (
#     GCSCreateBucketOperator,
#     GCSListObjectsOperator,
# )
# from airflow.providers.google.cloud.transfers.local_to_gcs import (
#     LocalFilesystemToGCSOperator,
# )


default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}


def check_gcp_connection():
    """Check if GCP connection is available"""
    try:
        from google.cloud import storage
        client = storage.Client()
        print(f"GCP Project: {client.project}")
        print("GCP connection successful!")
        return True
    except Exception as e:
        print(f"GCP connection failed: {str(e)}")
        print("This is expected if GCP credentials are not configured")
        return False


with DAG(
    'example_gcs_dag',
    default_args=default_args,
    description='Example DAG for GCS operations',
    schedule_interval=None,  # Manual trigger only
    catchup=False,
    tags=['example', 'gcs'],
) as dag:

    # Task to check GCP connection
    check_connection = PythonOperator(
        task_id='check_gcp_connection',
        python_callable=check_gcp_connection,
    )

    # Uncomment these tasks when GCP is properly configured:

    # list_gcs_objects = GCSListObjectsOperator(
    #     task_id='list_gcs_objects',
    #     bucket='your-bucket-name',
    #     gcp_conn_id='google_cloud_default',
    # )

    # check_connection >> list_gcs_objects
