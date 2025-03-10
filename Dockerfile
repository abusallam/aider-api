# Stage 1: Build stage (for building dependencies)
FROM python:3.11-slim as build-stage

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

# Install necessary system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy the application files into the container
COPY . /app/

# Install dependencies using the uv package manager
RUN pip install virtualenv
RUN python3 -m venv .venv
RUN .venv/bin/pip install uv
RUN .venv/bin/uv pip install --upgrade pip
RUN .venv/bin/uv pip install -r requirements.txt

# Stage 2: Production stage (lighter, optimized for runtime)
FROM python:3.11-slim as production-stage

# Set environment variables for production
ENV PYTHONUNBUFFERED=1

# Set working directory
WORKDIR /app

# Copy the app files from build-stage to production-stage
COPY --from=build-stage /app /app

# Install only production dependencies (no dev dependencies)
RUN pip install gunicorn uvicorn

# Expose the port the application will run on
EXPOSE 8000

# Command to run the app using Gunicorn + Uvicorn worker
CMD ["gunicorn", "server:app", "-w", "4", "-k", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8000"]
