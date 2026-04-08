FROM locustio/locust:2.32.4

COPY locustfile.py /mnt/locust/locustfile.py
COPY locust-targets.yaml /mnt/locust/locust-targets.yaml

RUN pip3 install pyyaml
