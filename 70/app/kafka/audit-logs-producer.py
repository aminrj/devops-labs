import os
import time
from confluent_kafka import Producer

# Kafka configuration
conf = {
    'bootstrap.servers': 'my-cluster-kafka:9092',  # Adjust to your Kafka bootstrap service
    'sasl.mechanism': 'SCRAM-SHA-512',
    # 'security.protocol': 'SASL_SSL',  # Use SASL_SSL if using SSL
    'sasl.username': 'audit-logs-producer',
    'sasl.password': os.environ['KAFKA_USER_PASSWORD'],
    'client.id': 'audit-logs-producer'
}

# Create a Producer instance
producer = Producer(**conf)

# Kafka topic
topic = 'audit-logs-topic'

# Path to the log file
log_file_path = '/app/log/file.log'

def acked(err, msg):
    if err is not None:
        print(f"Failed to deliver message: {err}")
    else:
        print(f"Message produced: {msg.value().decode('utf-8')}")

def read_and_send_logs():
    with open(log_file_path, 'r') as log_file:
        while True:
            line = log_file.readline()
            if not line:
                time.sleep(0.1)  # Sleep briefly to wait for new log entries
                continue
            
            # Produce the log line to Kafka
            producer.produce(topic, line.strip(), callback=acked)
            producer.poll(0)  # Poll to trigger the callback

if __name__ == "__main__":
    try:
        read_and_send_logs()
    except KeyboardInterrupt:
        pass
    finally:
        producer.flush()
