#!/usr/bin/env python
from ncclient import manager
from ncclient.xml_ import *

import argparse
import time
import pprint

parser = argparse.ArgumentParser()
parser.add_argument('--hostname')
args = parser.parse_args()

def connect(host, port, user, password, source):
    conn = manager.connect(host=args.hostname,
            port=830,
            username='ntc',
            password='ntc123',
            timeout=10,
            device_params = {'name':'junos'},
            hostkey_verify=False)

    print 'locking configuration'
    lock = conn.lock()

    rpc = """
     <edit-config>
      <target>
       <candidate/>
      </target>
     <config>
      <configuration>
       <system>
        <host-name>vmx7</host-name>
       </system>
      </configuration>
     </config>
    </edit-config>"""

    result = conn.rpc(rpc)

    print 'Validate configuration'
    check_config = conn.validate()
    print check_config.tostring

    commit_config = conn.commit()
    print 'committed configuration'

    print 'unlocking configuration'
    unlock = conn.unlock()
    print unlock.tostring

    rpc = new_ele('get-software-information')

    result = conn.rpc(rpc)
    print 'Hostname:', result.xpath('//software-information/host-name')[0].text

if __name__ == '__main__':
    connect('router', 830, 'netconf', 'juniper!', 'candidate')

