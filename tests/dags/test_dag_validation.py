"""
Test DAG validation and integrity

This module tests that all DAGs are valid, can be loaded,
and don't have common issues.
"""
import os
import pytest
from pathlib import Path
from airflow.models import DagBag


# Path to DAGs directory
DAGS_DIR = Path(__file__).parent.parent.parent / "dags"


class TestDagIntegrity:
    """Test suite for DAG integrity and validation"""

    @pytest.fixture(scope="class")
    def dagbag(self):
        """Create a DagBag for testing"""
        return DagBag(dag_folder=str(DAGS_DIR), include_examples=False)

    def test_no_import_errors(self, dagbag):
        """Test that there are no import errors in DAGs"""
        assert not dagbag.import_errors, \
            f"DAG import failures: {dagbag.import_errors}"

    def test_dags_loaded(self, dagbag):
        """Test that at least one DAG is loaded"""
        assert len(dagbag.dags) > 0, "No DAGs were loaded"

    def test_all_dags_have_tags(self, dagbag):
        """Test that all DAGs have tags"""
        for dag_id, dag in dagbag.dags.items():
            assert dag.tags, f"DAG {dag_id} has no tags"

    def test_all_dags_have_owner(self, dagbag):
        """Test that all DAGs have an owner"""
        for dag_id, dag in dagbag.dags.items():
            assert dag.owner, f"DAG {dag_id} has no owner"
            assert dag.owner != "airflow", \
                f"DAG {dag_id} still has default owner 'airflow'"

    def test_default_args_present(self, dagbag):
        """Test that all DAGs have default_args"""
        for dag_id, dag in dagbag.dags.items():
            assert dag.default_args, f"DAG {dag_id} has no default_args"

    def test_retries_configured(self, dagbag):
        """Test that all DAGs have retry configuration"""
        for dag_id, dag in dagbag.dags.items():
            default_args = dag.default_args
            assert 'retries' in default_args, \
                f"DAG {dag_id} has no retry configuration"
            assert default_args['retries'] >= 0, \
                f"DAG {dag_id} has invalid retry count"

    def test_no_duplicate_task_ids(self, dagbag):
        """Test that DAGs don't have duplicate task IDs"""
        for dag_id, dag in dagbag.dags.items():
            task_ids = [task.task_id for task in dag.tasks]
            assert len(task_ids) == len(set(task_ids)), \
                f"DAG {dag_id} has duplicate task IDs"

    def test_tasks_have_descriptions(self, dagbag):
        """Test that tasks have doc strings or descriptions"""
        for dag_id, dag in dagbag.dags.items():
            for task in dag.tasks:
                # Either task doc or DAG doc should exist
                assert task.doc or dag.doc_md or dag.description, \
                    f"Task {task.task_id} in DAG {dag_id} has no documentation"

    def test_no_cyclic_dependencies(self, dagbag):
        """Test that DAGs don't have cyclic dependencies"""
        for dag_id, dag in dagbag.dags.items():
            # This will raise an exception if there are cycles
            try:
                dag.topological_sort()
            except Exception as e:
                pytest.fail(f"DAG {dag_id} has cyclic dependencies: {str(e)}")

    def test_start_date_not_dynamic(self, dagbag):
        """Test that DAGs don't use dynamic start dates"""
        from datetime import datetime

        for dag_id, dag in dagbag.dags.items():
            # Start date should be a fixed datetime
            assert isinstance(dag.start_date, datetime), \
                f"DAG {dag_id} has no valid start_date"

            # Check that it's not using datetime.now() or similar
            # (this is a heuristic - we check if it's recent)
            from datetime import timedelta
            recent = datetime.now() - timedelta(days=1)
            assert dag.start_date < recent, \
                f"DAG {dag_id} might be using dynamic start_date (too recent)"

    def test_schedule_interval_valid(self, dagbag):
        """Test that schedule intervals are valid"""
        for dag_id, dag in dagbag.dags.items():
            # schedule_interval can be None, string, or timedelta
            if dag.schedule_interval is not None:
                assert isinstance(dag.schedule_interval, (str, type(None))) or \
                       hasattr(dag.schedule_interval, 'days'), \
                    f"DAG {dag_id} has invalid schedule_interval type"

    def test_catchup_disabled_for_new_dags(self, dagbag):
        """Test that new DAGs have catchup disabled (recommended)"""
        for dag_id, dag in dagbag.dags.items():
            # For new DAGs, catchup should typically be False
            # This is a warning rather than an error
            if dag.catchup:
                print(f"⚠️  Warning: DAG {dag_id} has catchup=True. " +
                      "Consider disabling for new DAGs.")

    def test_email_on_failure_configured(self, dagbag):
        """Test that email notifications are configured for failures"""
        for dag_id, dag in dagbag.dags.items():
            default_args = dag.default_args
            # Check if email on failure is explicitly set
            if 'email_on_failure' in default_args:
                if default_args['email_on_failure']:
                    assert 'email' in default_args, \
                        f"DAG {dag_id} has email_on_failure=True but no email configured"


class TestSpecificDAGs:
    """Test specific DAGs for their unique requirements"""

    @pytest.fixture(scope="class")
    def dagbag(self):
        """Create a DagBag for testing"""
        return DagBag(dag_folder=str(DAGS_DIR), include_examples=False)

    def test_example_dag_exists(self, dagbag):
        """Test that example_dag exists"""
        assert 'example_dag' in dagbag.dags, "example_dag not found"

    def test_example_dag_structure(self, dagbag):
        """Test example_dag has correct structure"""
        dag = dagbag.dags.get('example_dag')
        if dag:
            # Should have at least 3 tasks
            assert len(dag.tasks) >= 3, \
                "example_dag should have at least 3 tasks"

            # Check specific tasks exist
            task_ids = [task.task_id for task in dag.tasks]
            assert 'print_hello' in task_ids
            assert 'print_date' in task_ids
            assert 'print_context' in task_ids

    def test_example_gcs_dag_exists(self, dagbag):
        """Test that example_gcs_dag exists"""
        assert 'example_gcs_dag' in dagbag.dags, "example_gcs_dag not found"


class TestTaskTypes:
    """Test different types of tasks"""

    @pytest.fixture(scope="class")
    def dagbag(self):
        """Create a DagBag for testing"""
        return DagBag(dag_folder=str(DAGS_DIR), include_examples=False)

    def test_python_operators_valid(self, dagbag):
        """Test that PythonOperators have valid callables"""
        from airflow.operators.python import PythonOperator

        for dag_id, dag in dagbag.dags.items():
            for task in dag.tasks:
                if isinstance(task, PythonOperator):
                    assert task.python_callable is not None, \
                        f"PythonOperator {task.task_id} in {dag_id} has no callable"
                    assert callable(task.python_callable), \
                        f"PythonOperator {task.task_id} in {dag_id} has non-callable"

    def test_bash_operators_valid(self, dagbag):
        """Test that BashOperators have valid commands"""
        from airflow.operators.bash import BashOperator

        for dag_id, dag in dagbag.dags.items():
            for task in dag.tasks:
                if isinstance(task, BashOperator):
                    assert task.bash_command, \
                        f"BashOperator {task.task_id} in {dag_id} has no command"
                    assert isinstance(task.bash_command, str), \
                        f"BashOperator {task.task_id} in {dag_id} has non-string command"


class TestDAGPerformance:
    """Test DAG performance and best practices"""

    @pytest.fixture(scope="class")
    def dagbag(self):
        """Create a DagBag for testing"""
        return DagBag(dag_folder=str(DAGS_DIR), include_examples=False)

    def test_dag_not_too_many_tasks(self, dagbag):
        """Test that DAGs don't have too many tasks"""
        MAX_TASKS = 100  # Recommended maximum

        for dag_id, dag in dagbag.dags.items():
            task_count = len(dag.tasks)
            if task_count > MAX_TASKS:
                print(f"⚠️  Warning: DAG {dag_id} has {task_count} tasks. " +
                      f"Consider splitting into multiple DAGs.")

    def test_no_top_level_code(self):
        """Test that DAG files don't have expensive top-level code"""
        # This is a basic check - scan for common anti-patterns
        dag_files = list(DAGS_DIR.glob("*.py"))

        for dag_file in dag_files:
            with open(dag_file, 'r') as f:
                content = f.read()

                # Check for common anti-patterns
                anti_patterns = [
                    ('requests.get', 'HTTP requests at module level'),
                    ('pd.read_', 'Pandas read operations at module level'),
                    ('open(', 'File operations at module level (use in tasks)'),
                ]

                for pattern, message in anti_patterns:
                    # This is a simple check - might have false positives
                    if pattern in content:
                        # Check if it's inside a function
                        lines = content.split('\n')
                        for i, line in enumerate(lines):
                            if pattern in line:
                                # Simple check: is there indentation?
                                if line.startswith(pattern):
                                    print(f"⚠️  Warning: {dag_file.name} line {i+1}: {message}")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
