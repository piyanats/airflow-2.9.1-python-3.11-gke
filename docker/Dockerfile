FROM apache/airflow:2.9.1-python3.11

# Switch to root to install system dependencies
USER root

# Install system dependencies if needed
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        git \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Switch back to airflow user
USER airflow

# Copy requirements file
COPY requirements.txt /requirements.txt

# Install Python packages
RUN pip install --no-cache-dir -r /requirements.txt

# Copy any custom plugins or scripts if needed
# COPY --chown=airflow:root plugins/ ${AIRFLOW_HOME}/plugins/
