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
RUN rm -rf .venv/lib/python3.11/site-packages/*
RUN .venv/bin/uv pip install -r requirements.txt
RUN .venv/bin/uv pip install -U aider-chat

# Stage 2: Production stage (lighter, optimized for runtime)
FROM python:3.11-slim as production-stage

# Set environment variables for production
ENV PYTHONUNBUFFERED=1
ENV OPEN_WEB_UI_URL=https://open-webui.consulting.sa/
ENV API_TOKEN=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6ImZjMzE2ZmZlLTBkNTctNDE2YS04MTdiLTIyNjQyMmM0ZDQ5MCJ9.-LQ3n1aIznBJoJ1sxTvR8l3NtnXYx7nYUYJczSJs7H8
ENV MODEL_NAME=gpt-3.5-turbo
ENV PATH="/app/.venv/bin:${PATH}"

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
