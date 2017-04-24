#!/usr/bin/env perl

use v5.20;
use strict;
use warnings;
use feature 'postderef' ; no warnings 'experimental::postderef';

# we will add to our @INC the lib and the local (carton) paths
use File::Basename;
use File::Spec;
use lib File::Spec->catdir( File::Spec->catdir( File::Spec->rel2abs( dirname( $0 ) ) ) , 'local' , 'lib', 'perl5' ) ;

use Net::AMQP::RabbitMQ;
my $mq = Net::AMQP::RabbitMQ->new;

$mq->connect('localhost', {} );

$mq->channel_open(1);

$mq->queue_declare(1, 'hello', { auto_delete => 0 });
    
$mq->publish(1, 'hello', 'Hello, World!');

say " [x] Sent 'Hello World!' ";

$mq->disconnect;

