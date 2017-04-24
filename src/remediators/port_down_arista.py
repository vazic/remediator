#!/usr/bin/env python
from netmiko import ConnectHandler
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--hostname')
parser.add_argument('--interface')
args = parser.parse_args()


net_connect = ConnectHandler(device_type='arista_eos', ip=args.hostname, username='ntc', password='ntc123')
prompt = net_connect.find_prompt()

config_commands = [
'interface {}'.format(args.interface),
'no shut',
]
output = net_connect.send_config_set(config_commands)

print output
