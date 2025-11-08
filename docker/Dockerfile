# ==============================================================================
# Multi-Stage Dockerfile for Apache Airflow 2.9.1 with Python 3.11
# Using uv for fast dependency installation
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Builder - Install dependencies using uv
# ------------------------------------------------------------------------------
FROM apache/airflow:2.9.1-python3.11 AS builder

USER root

# Install system dependencies needed for building Python packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        curl \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install uv - fast Python package installer
# https://github.com/astral-sh/uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Add uv to PATH
ENV PATH="/root/.cargo/bin:$PATH"

# Copy requirements file
COPY requirements.txt /tmp/requirements.txt

# Create virtual environment and install packages as root
# This ensures uv has proper permissions
RUN python -m venv /opt/airflow/venv \
    && /root/.cargo/bin/uv pip install \
        --python /opt/airflow/venv/bin/python \
        --no-cache \
        -r /tmp/requirements.txt

# Change ownership of venv to airflow user
RUN chown -R airflow:root /opt/airflow/venv

# ------------------------------------------------------------------------------
# Stage 2: Runtime - Final lightweight image
# ------------------------------------------------------------------------------
FROM apache/airflow:2.9.1-python3.11

USER root

# Install only runtime system dependencies (minimal set)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy installed packages from builder stage
COPY --from=builder --chown=airflow:root /opt/airflow/venv /opt/airflow/venv

USER airflow

# Update PATH to use venv packages
ENV PATH="/opt/airflow/venv/bin:$PATH"
ENV PYTHONPATH="/opt/airflow/venv/lib/python3.11/site-packages:$PYTHONPATH"

# Copy any custom plugins or scripts if needed
# COPY --chown=airflow:root plugins/ ${AIRFLOW_HOME}/plugins/
# COPY --chown=airflow:root dags/ ${AIRFLOW_HOME}/dags/

# Verify installation
RUN python -c "import airflow; print(f'Airflow version: {airflow.__version__}')" \
    && python -c "import google.cloud.storage; print('GCP packages installed successfully')"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import airflow; print('OK')" || exit 1

# Labels for image metadata
LABEL maintainer="your-team@example.com"
LABEL version="2.9.1"
LABEL description="Apache Airflow 2.9.1 with Python 3.11, built with uv package manager"
LABEL org.opencontainers.image.source="https://github.com/your-org/airflow-2.9.1-python-3.11-gke"
