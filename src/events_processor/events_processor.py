#!/usr/bin/env python
"""
This script reads Events queue and filters duplicated messages with timefilter.
Non-duplicates are routed to Actionable_events queue
"""
import pika
import json
from time import time

EVENTS_QUEUE_NAME = 'events'
ACTION_QUEUE_NAME = 'actionable_events'
OBSERVED_EVENTS = {} # device_hash to timestamp mapping 
TIME_FILTER_TRESHHOLD = 10 #Seconds

def is_known_event(event_body):
    #Here we can define list of known events
    return True

def is_duplicate(event_body):
    #Placeholder for timefiler
    #We need to hash Dict here...
    event = json.loads(event_body)
    h = hash((
        event['device_type'],
        tuple(event['remediations']),
        event['hostname'],
        event['parameters']['interface'],
        #event['parameters']['state'],
    ))
    now = time()
    if h in OBSERVED_EVENTS:
        previous_time = OBSERVED_EVENTS[h]
        if now - previous_time > TIME_FILTER_TRESHHOLD:
            print("...previous observation expired {} sec ago for {}".format(
                now - previous_time,event_body))
            OBSERVED_EVENTS[h] = now
            return False
        else:
            print("...duplicate detected under treshhold of {}. {}".format(
                now - previous_time, event_body
            ))
            return True
    else:
        print("...new event found")
        OBSERVED_EVENTS[h] = now
        return False

def send_to_action_queue(event_body):
    with pika.BlockingConnection(pika.ConnectionParameters('localhost')) as connection:
        channel = connection.channel()
        channel.queue_declare(queue=ACTION_QUEUE_NAME)
        body = event_body
        channel.basic_publish(exchange='',
                routing_key=ACTION_QUEUE_NAME,
                body=body)
        print(" [!] Sent to {}: {}".format(ACTION_QUEUE_NAME,body))

def callback(ch, method, properties, body):
    print(" [x] Received %r" % body)
    if not is_known_event(body):
        print(" [:(] Unkown event here, skipping")
        return
    if is_duplicate(body):
        print(" [zzz] I've seen it before somewhere...duplicate skip")
        return
    send_to_action_queue(body)

connection = pika.BlockingConnection(pika.ConnectionParameters(host='localhost'))
channel = connection.channel()
channel.queue_declare(queue=EVENTS_QUEUE_NAME)
channel.basic_consume(callback, queue=EVENTS_QUEUE_NAME, no_ack=True)

print(' [*] Waiting for messages. To exit press CTRL+C')
channel.start_consuming()
