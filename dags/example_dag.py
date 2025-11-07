"""
Example DAG for testing Airflow deployment
"""
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator


default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}


def print_hello():
    """Simple Python function"""
    print("Hello from Airflow!")
    print(f"Current time: {datetime.now()}")
    return "Success"


def print_context(**context):
    """Print the Airflow context"""
    print(f"Execution date: {context['execution_date']}")
    print(f"DAG run ID: {context['dag_run'].run_id}")
    return "Context printed"


with DAG(
    'example_dag',
    default_args=default_args,
    description='A simple example DAG',
    schedule_interval=timedelta(days=1),
    catchup=False,
    tags=['example'],
) as dag:

    # Task 1: Print hello
    task_hello = PythonOperator(
        task_id='print_hello',
        python_callable=print_hello,
    )

    # Task 2: Bash command
    task_bash = BashOperator(
        task_id='print_date',
        bash_command='date',
    )

    # Task 3: Print context
    task_context = PythonOperator(
        task_id='print_context',
        python_callable=print_context,
    )

    # Define task dependencies
    task_hello >> task_bash >> task_context
