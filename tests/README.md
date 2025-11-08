# Tests

This directory contains all tests for the Airflow project.

## Quick Start

```bash
# Install dependencies
make install-test-deps

# Run all tests
make test

# Run specific test category
make test-dags
```

## Directory Structure

```
tests/
├── README.md           # This file
├── __init__.py         # Test package marker
├── conftest.py         # Pytest fixtures and configuration
├── dags/               # DAG validation tests
│   └── test_dag_validation.py
├── unit/               # Unit tests
│   └── (add your unit tests here)
└── integration/        # Integration tests
    └── (add your integration tests here)
```

## Test Categories

### DAG Tests (`dags/`)

Validates that DAGs:
- Load without errors
- Have correct structure
- Follow best practices
- Have proper configuration

**Run with:** `make test-dags`

### Unit Tests (`unit/`)

Tests individual components:
- Custom operators
- Helper functions
- Utilities

**Run with:** `make test-unit`

### Integration Tests (`integration/`)

Tests complete workflows:
- Full DAG execution
- External service integration
- End-to-end scenarios

**Run with:** `make test-integration`

## Writing Tests

### Example DAG Test

```python
def test_my_dag_exists(dagbag):
    """Test that my_dag is loaded"""
    assert "my_dag" in dagbag.dags
```

### Example Unit Test

```python
def test_my_function():
    """Test my custom function"""
    result = my_function(input_data)
    assert result == expected_output
```

## Documentation

See [Testing Guide](../docs/testing-guide.md) for:
- Complete testing documentation
- Writing test guidelines
- Best practices
- Troubleshooting

## CI/CD

Tests automatically run on:
- Every push to main/develop
- Every pull request
- Manual workflow trigger

See `.github/workflows/ci.yaml` for details.
