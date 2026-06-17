FROM python:3.12-slim

WORKDIR /app

# Install dependencies first for layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Transport defaults — override via compose/env
ENV TRANSPORT=streamable-http \
    HOST=0.0.0.0 \
    PORT=8000 \
    PYTHONUNBUFFERED=1

EXPOSE 8000

# TCP-level healthcheck: confirms the ASGI server is accepting connections.
# (Avoids depending on a specific HTTP path across mcp versions.)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import socket,os; s=socket.create_connection(('127.0.0.1', int(os.environ.get('PORT','8000'))), 3); s.close()" || exit 1

CMD ["python", "server.py"]
