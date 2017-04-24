#!/usr/bin/env python

import argparse
import sys

def run(hosts, interfaces):
    '''
        Remediation for the port_down event
    '''

    print hosts
    print interfaces 

if __name__ == '__main__':

    parser = argparse.ArgumentParser(description='Remediation for the port_down event.')
    parser.add_argument('--hostnames',
                       help='Hostnames affected ')
    parser.add_argument('--interfaces',
                       help='Interfaces affected')

    args = parser.parse_args()

    hostnames = args.hostnames
    interfaces = args.interfaces

    run(hostnames, interfaces)
