FROM python:3.9-slim

# Install confluent-kafka
RUN pip install confluent-kafka

# Add your script to the Docker image
COPY kafka/audit-logs-producer.py /app/audit-logs-producer.py
COPY kafka/audit-logs-producer.py /app/log/file.log

WORKDIR /app

# Run the producer script
CMD ["python", "audit-logs-producer.py"]
