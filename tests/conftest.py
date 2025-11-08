"""
Pytest configuration and fixtures for Airflow tests
"""
import os
import sys
from pathlib import Path
import pytest

# Add project root to Python path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

# Add dags directory to Python path
dags_dir = project_root / "dags"
sys.path.insert(0, str(dags_dir))


@pytest.fixture(scope="session")
def airflow_home(tmp_path_factory):
    """Create a temporary AIRFLOW_HOME for testing"""
    airflow_home = tmp_path_factory.mktemp("airflow")
    os.environ["AIRFLOW_HOME"] = str(airflow_home)
    return airflow_home


@pytest.fixture(scope="session", autouse=True)
def setup_airflow_db(airflow_home):
    """Initialize Airflow database for testing"""
    from airflow import settings
    from airflow.utils import db

    # Initialize the database
    db.initdb()

    yield

    # Cleanup is automatic with tmp_path


@pytest.fixture
def dag_bag():
    """Create a DagBag for testing"""
    from airflow.models import DagBag

    dags_folder = Path(__file__).parent.parent / "dags"
    return DagBag(dag_folder=str(dags_folder), include_examples=False)


@pytest.fixture
def sample_dag():
    """Create a sample DAG for testing"""
    from airflow import DAG
    from airflow.operators.python import PythonOperator
    from datetime import datetime, timedelta

    default_args = {
        'owner': 'airflow',
        'depends_on_past': False,
        'start_date': datetime(2024, 1, 1),
        'email_on_failure': False,
        'email_on_retry': False,
        'retries': 1,
        'retry_delay': timedelta(minutes=5),
    }

    dag = DAG(
        'test_dag',
        default_args=default_args,
        description='A test DAG',
        schedule_interval=timedelta(days=1),
        catchup=False,
    )

    def dummy_task():
        return "success"

    task = PythonOperator(
        task_id='test_task',
        python_callable=dummy_task,
        dag=dag,
    )

    return dag


def pytest_configure(config):
    """Configure pytest"""
    # Set Airflow unit test mode
    os.environ["AIRFLOW__CORE__UNIT_TEST_MODE"] = "True"

    # Disable loading of example DAGs
    os.environ["AIRFLOW__CORE__LOAD_EXAMPLES"] = "False"

    # Use SQLite for testing
    os.environ["AIRFLOW__DATABASE__SQL_ALCHEMY_CONN"] = "sqlite:////tmp/airflow_test.db"

    # Set executor to SequentialExecutor for testing
    os.environ["AIRFLOW__CORE__EXECUTOR"] = "SequentialExecutor"

    # Disable authentication for testing
    os.environ["AIRFLOW__API__AUTH_BACKENDS"] = "airflow.api.auth.backend.default"


def pytest_collection_modifyitems(config, items):
    """Modify test items"""
    # Add markers to tests
    for item in items:
        # Mark slow tests
        if "slow" in item.nodeid:
            item.add_marker(pytest.mark.slow)

        # Mark integration tests
        if "integration" in item.nodeid:
            item.add_marker(pytest.mark.integration)

        # Mark unit tests
        if "unit" in item.nodeid:
            item.add_marker(pytest.mark.unit)
