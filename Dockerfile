# ============================================================================
# Multi-stage Docker build for Feature Flag Manager
# Designed for GitHub Actions automated deployment
# ============================================================================

# STAGE 1: Builder
# ============================================================================
FROM python:3.11-slim as builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# STAGE 2: Runtime
# ============================================================================
FROM python:3.11-slim

# Set labels for GitHub Actions
LABEL org.opencontainers.image.source="https://github.com/company/feature-flags"
LABEL org.opencontainers.image.description="Feature Flag Manager - Production"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# Create non-root user for security
RUN useradd -m -u 1000 appuser

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Python dependencies from builder
COPY --from=builder /root/.local /home/appuser/.local

# Copy application code
COPY --chown=appuser:appuser src/ src/

# Copy configuration files
COPY --chown=appuser:appuser config/ config/

# Set environment variables
ENV PATH=/home/appuser/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONPATH=/app/src

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose port
EXPOSE 8000

# Run application
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", \
     "--worker-class", "uvicorn.workers.UvicornWorker", \
     "--timeout", "60", "--access-logfile", "-", \
     "--error-logfile", "-", "src.feature_flags.main:app"]
