# Testing Guide

Complete guide for testing Airflow DAGs and ensuring code quality.

## Table of Contents

- [Quick Start](#quick-start)
- [Test Structure](#test-structure)
- [Running Tests](#running-tests)
- [Writing Tests](#writing-tests)
- [Code Quality](#code-quality)
- [CI/CD Integration](#cicd-integration)
- [Troubleshooting](#troubleshooting)

## Quick Start

### Installation

```bash
# Install test dependencies
make install-test-deps

# Install pre-commit hooks
make install-hooks
```

### Running Tests

```bash
# Run all tests
make test

# Run specific test suites
make test-dags          # DAG validation
make test-unit          # Unit tests
make test-integration   # Integration tests

# Run with coverage
pytest tests/ --cov=dags --cov-report=html
```

## Test Structure

```
tests/
├── __init__.py
├── conftest.py              # Pytest configuration and fixtures
├── dags/
│   └── test_dag_validation.py   # DAG validation tests
├── unit/
│   └── (unit tests here)
└── integration/
    └── (integration tests here)
```

### Test Categories

1. **DAG Validation Tests** (`tests/dags/`)
   - Import validation
   - Structure validation
   - Configuration checks
   - Best practices validation

2. **Unit Tests** (`tests/unit/`)
   - Individual function tests
   - Operator tests
   - Utility function tests

3. **Integration Tests** (`tests/integration/`)
   - End-to-end DAG execution
   - External service integration
   - Database operations

## Running Tests

### All Tests

```bash
# Using Make
make test

# Using pytest directly
pytest tests/ -v

# With output capture
pytest tests/ -v -s

# With specific verbosity
pytest tests/ -vv
```

### Specific Test Files

```bash
# Single file
pytest tests/dags/test_dag_validation.py

# Specific test class
pytest tests/dags/test_dag_validation.py::TestDagIntegrity

# Specific test method
pytest tests/dags/test_dag_validation.py::TestDagIntegrity::test_no_import_errors
```

### Using Markers

```bash
# Run only unit tests
pytest -m unit

# Run only integration tests
pytest -m integration

# Run all except slow tests
pytest -m "not slow"

# Combine markers
pytest -m "unit and not slow"
```

### Parallel Execution

```bash
# Install pytest-xdist first
pip install pytest-xdist

# Run tests in parallel (auto detect CPUs)
pytest tests/ -n auto

# Run with specific number of workers
pytest tests/ -n 4
```

### Coverage Reports

```bash
# Run with coverage
pytest tests/ --cov=dags

# Generate HTML report
pytest tests/ --cov=dags --cov-report=html

# Open HTML report
open htmlcov/index.html

# Set minimum coverage threshold
pytest tests/ --cov=dags --cov-fail-under=80
```

## Writing Tests

### DAG Validation Tests

```python
# tests/dags/test_my_dag.py
import pytest
from airflow.models import DagBag


class TestMyDAG:
    """Test MyDAG specific functionality"""

    @pytest.fixture(scope="class")
    def dagbag(self):
        return DagBag(dag_folder="dags/", include_examples=False)

    def test_dag_loaded(self, dagbag):
        """Test that my_dag is loaded"""
        assert "my_dag" in dagbag.dags

    def test_dag_has_correct_tasks(self, dagbag):
        """Test that my_dag has expected tasks"""
        dag = dagbag.dags["my_dag"]
        task_ids = [task.task_id for task in dag.tasks]

        assert "extract" in task_ids
        assert "transform" in task_ids
        assert "load" in task_ids

    def test_task_dependencies(self, dagbag):
        """Test task dependencies are correct"""
        dag = dagbag.dags["my_dag"]

        extract = dag.get_task("extract")
        transform = dag.get_task("transform")

        assert transform in extract.downstream_list
```

### Unit Tests

```python
# tests/unit/test_operators.py
import pytest
from airflow.models import DagRun, TaskInstance
from datetime import datetime


class TestMyOperator:
    """Test custom operator"""

    def test_operator_execution(self, sample_dag):
        """Test operator executes successfully"""
        task = sample_dag.get_task("my_task")

        # Create task instance
        ti = TaskInstance(task=task, execution_date=datetime(2024, 1, 1))

        # Execute task
        ti.run()

        # Assert success
        assert ti.state == "success"

    def test_operator_with_mock(self, mocker):
        """Test operator with mocked dependencies"""
        mock_client = mocker.patch("google.cloud.storage.Client")

        # Your test logic here
        assert mock_client.called
```

### Integration Tests

```python
# tests/integration/test_dag_execution.py
import pytest
from airflow.models import DagBag
from airflow.utils.state import State


@pytest.mark.integration
class TestDAGExecution:
    """Test complete DAG execution"""

    def test_dag_runs_successfully(self, dagbag):
        """Test that DAG executes end-to-end"""
        dag = dagbag.dags["my_dag"]

        # Run DAG
        dag.test()

        # Check all tasks succeeded
        for task in dag.tasks:
            ti = task.get_task_instance()
            assert ti.state == State.SUCCESS
```

### Using Fixtures

```python
# tests/conftest.py
import pytest
from airflow.models import DagBag


@pytest.fixture
def sample_dag():
    """Provide a sample DAG for testing"""
    dagbag = DagBag(dag_folder="dags/")
    return dagbag.dags["sample_dag"]


@pytest.fixture
def mock_gcs_client(mocker):
    """Provide a mocked GCS client"""
    return mocker.patch("google.cloud.storage.Client")


# Use in tests
def test_with_fixtures(sample_dag, mock_gcs_client):
    """Test using fixtures"""
    assert sample_dag is not None
    assert mock_gcs_client is not None
```

## Code Quality

### Linting

```bash
# Run all linters
make lint

# Individual linters
flake8 dags/
black --check dags/
isort --check-only dags/
pylint dags/
```

### Formatting

```bash
# Format all code
make format

# Format specific file
black dags/my_dag.py
isort dags/my_dag.py
```

### Pre-commit Hooks

```bash
# Install hooks
make install-hooks

# Run manually on all files
pre-commit run --all-files

# Run on staged files only
git add .
pre-commit run

# Skip hooks (not recommended)
git commit --no-verify
```

### Security Scanning

```bash
# Scan for security issues
bandit -r dags/

# Scan for secrets
detect-secrets scan dags/

# Check dependencies for vulnerabilities
safety check
```

## CI/CD Integration

### GitHub Actions

The project includes a complete CI/CD pipeline (`.github/workflows/ci.yaml`) that runs:

1. **Lint** - Code quality checks
2. **Test** - All test suites
3. **Build** - Docker image build
4. **Security Scan** - Vulnerability scanning
5. **Deploy** - Automatic deployment (on main branch)

### Workflow Triggers

```yaml
on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]
```

### Required Secrets

Configure these in GitHub repository settings:

- `GCP_SA_KEY` - GCP service account key
- `GCP_PROJECT_ID` - GCP project ID
- `GKE_CLUSTER_NAME` - GKE cluster name
- `GKE_REGION` - GKE region

### Local CI Simulation

```bash
# Run the same checks as CI
make lint
make test
make build-image

# Or use act to run GitHub Actions locally
act -j test-dags
```

## Best Practices

### 1. Test Naming

```python
# Good
def test_dag_loads_successfully()
def test_task_has_correct_configuration()
def test_operator_raises_exception_on_error()

# Avoid
def test1()
def test_stuff()
def testDAG()
```

### 2. Test Organization

```python
class TestDAGValidation:
    """Group related tests in classes"""

    def test_import_errors(self):
        pass

    def test_task_dependencies(self):
        pass
```

### 3. Use Descriptive Assertions

```python
# Good
assert len(dag.tasks) == 5, "Expected 5 tasks in DAG"
assert task_id in task_ids, f"Task {task_id} not found in {task_ids}"

# Avoid
assert len(dag.tasks) == 5
assert task_id in task_ids
```

### 4. Test One Thing

```python
# Good
def test_dag_has_correct_schedule():
    assert dag.schedule_interval == "@daily"

def test_dag_has_correct_owner():
    assert dag.owner == "data-team"

# Avoid
def test_dag_configuration():
    assert dag.schedule_interval == "@daily"
    assert dag.owner == "data-team"
    assert dag.catchup is False
    # ... too many assertions
```

### 5. Use Fixtures for Setup

```python
@pytest.fixture
def configured_dag():
    """Setup a configured DAG"""
    # Setup code
    dag = create_dag()
    yield dag
    # Teardown code
    cleanup_dag(dag)
```

## Troubleshooting

### Test Discovery Issues

```bash
# Ensure __init__.py exists in test directories
touch tests/__init__.py
touch tests/dags/__init__.py

# Check pytest can find tests
pytest --collect-only
```

### Import Errors

```bash
# Add project root to PYTHONPATH
export PYTHONPATH=$PYTHONPATH:$(pwd)

# Or use pytest.ini configuration
# pythonpath = . dags
```

### Airflow Database Issues

```bash
# Reset test database
export AIRFLOW_HOME=/tmp/airflow_test
airflow db reset -y

# Or use a fresh database
rm -rf /tmp/airflow_test
airflow db init
```

### Slow Tests

```bash
# Run only fast tests
pytest -m "not slow"

# Profile test execution time
pytest --durations=10

# Use pytest-xdist for parallel execution
pytest -n auto
```

### Coverage Issues

```bash
# Check which files are covered
pytest --cov=dags --cov-report=term-missing

# Exclude files from coverage
# In pytest.ini or .coveragerc
```

## Testing Checklist

Before committing code:

- [ ] All tests pass locally
- [ ] New code has tests
- [ ] Test coverage maintained (≥80%)
- [ ] Linting passes (flake8, black, isort)
- [ ] No security issues (bandit)
- [ ] No secrets committed (detect-secrets)
- [ ] Pre-commit hooks pass
- [ ] CI/CD pipeline passes

## Additional Resources

- [Pytest Documentation](https://docs.pytest.org/)
- [Airflow Testing Best Practices](https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html)
- [Python Testing Best Practices](https://docs.python-guide.org/writing/tests/)

## Examples

### Complete Test Example

```python
"""
tests/dags/test_etl_dag.py
Complete example of testing an ETL DAG
"""
import pytest
from airflow.models import DagBag
from datetime import datetime


class TestETLDAG:
    """Test ETL DAG"""

    EXPECTED_TASKS = ["extract", "transform", "validate", "load"]

    @pytest.fixture(scope="class")
    def dag(self):
        """Load ETL DAG"""
        dagbag = DagBag(dag_folder="dags/")
        return dagbag.dags.get("etl_dag")

    def test_dag_exists(self, dag):
        """Test DAG is loaded"""
        assert dag is not None, "ETL DAG not found"

    def test_dag_has_correct_tasks(self, dag):
        """Test DAG has all expected tasks"""
        task_ids = [task.task_id for task in dag.tasks]
        for expected_task in self.EXPECTED_TASKS:
            assert expected_task in task_ids, \
                f"Task {expected_task} not found"

    def test_task_dependencies(self, dag):
        """Test task dependencies are correct"""
        extract = dag.get_task("extract")
        transform = dag.get_task("transform")
        validate = dag.get_task("validate")
        load = dag.get_task("load")

        # Check linear dependency
        assert transform in extract.downstream_list
        assert validate in transform.downstream_list
        assert load in validate.downstream_list

    @pytest.mark.integration
    def test_dag_execution(self, dag):
        """Test complete DAG execution"""
        execution_date = datetime(2024, 1, 1)
        dag.test(execution_date=execution_date)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
```

---

**Happy Testing!** 🧪
