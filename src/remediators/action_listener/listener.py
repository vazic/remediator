#!/usr/bin/env python
import time
import json
from subprocess import call
from lib import rabbit_mq 
import logging
log = logging.getLogger()

REMEDIATIONS_BASEDIR = '/home/ntc/remediator/remediations/'

def actionable_event_received(ch, method, properties, body):
    '''
    Callback that is called when we receive a actionable_event in the queue
    '''
    time.sleep(body.count(b'.'))
 
    # loads the event from the queue 
    event = json.loads(body)

    for remediation in event['remediations']:
        logging.debug('Remediation to call: {}'.format(remediation))

        cmd = [REMEDIATIONS_BASEDIR + remediation]

        parameters = []
        for p, v in event['parameters'].items():
            logging.debug('Parameter: {}, Value: {}'.format(p, v))
            cmd.append('--{}'.format(p))
            cmd.append('{}'.format(v)) 

        cmd.append('--hostname')
        cmd.append(event['hostname']) 

        print '******'
        print cmd

        call(cmd)    


    ch.basic_ack(delivery_tag = method.delivery_tag)

def listener():
    '''
    Listens for messages on the 'actionable_events' queue and select the action to take 
    '''
    
    channel = rabbit_mq.connect('localhost') 
    channel.basic_consume(actionable_event_received,
                          queue='actionable_events')

    channel.start_consuming()

if __name__ == '__main__':
    log.setLevel(logging.DEBUG)
    listener()
