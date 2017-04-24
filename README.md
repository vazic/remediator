# remediator
An automatic remediation tool for network infrastructure.  This project is based on idea we can parse and capture events from network device logs and launch jobs for automated remediation.

# system diagram

   +--------+
   | syslog |
   +---|----+              +---------------------------+
       |                   |         Rabbit MQ         |
       |                   |                           |
       v                   |                           |
+-------------+            |    +                 +    |
| log_capture |---------------> |     rawlogs     |    |   +---------------+
+-------------+            |    |-----------------|------->| log_processor |
                           |    +                 +    |   +---------------+
                           |                           |           |
                           |    +                 +    |           |
+-----------------+        |    |     events      |    |           |
| events_processor|<------------|-----------------| <--------------+
+-----------------+        |    +                 +    |
         |                 |                           |
         |                 |    +                 +    |
         |                 |    |actionable_events|    |    +-----------------+
         +--------------------> |-----------------|-------->| action_listener |
                           |    +                 +    |    +-----------------+
                           |                           |             |
                           +---------------------------+             |
                                                                     |
                                                                     v
                                                          +---------------------+
                                                          |  remediation_script |
                                                          +---------------------+
                                                                     |
                             +-----------------------+               |
                             |                       |               |
                             |    Network Device     |<--------------+
                             |                       |
                             +-----------------------+

# installation

TBD

# quick start

TBD
