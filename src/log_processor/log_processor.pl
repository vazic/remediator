#!/usr/bin/env perl

use v5.20;
use strict;
use warnings;
use feature 'postderef' ; no warnings 'experimental::postderef';

# we will add to our @INC the lib and the local (carton) paths
use File::Basename;
use File::Spec;
use lib File::Spec->catdir( File::Spec->catdir( File::Spec->rel2abs( dirname( $0 ) ) ) , 'local' , 'lib', 'perl5' ) ;

use Data::Printer;
use Data::Dumper;
use Log::Log4perl;
use Scalar::Util;
use Errno;
use YAML qw(LoadFile);
use Try::Tiny;
use Data::Dumper;
use autodie qw(chdir open close fork);
use POSIX qw(setsid); # used for daemonize
use JSON;

use Getopt::Long;
#lifted from https://perlancar.wordpress.com/2016/12/01/getopt-modules-01-getoptlong/
Getopt::Long::Configure("bundling", "no_ignore_case", "permute", "no_getopt_compat");

GetOptions(
    'd'             => \(my $daemonize = 0),
    'r|rules'       => \(my $rules_file = File::Spec->catdir( File::Spec->catdir( File::Spec->rel2abs( dirname( $0 ) ) ) , 'rules.yaml' ) ),
    'c|config'       => \(my $config_file = File::Spec->catdir( File::Spec->catdir( File::Spec->rel2abs( dirname( $0 ) ) ) , 'config.yaml' ) ),
    'i|incoming'    => \(my $incoming = 'rawlogs' ),
    'o|outgoing'    => \(my $outgoing = 'events' ),
    'h|host'        => \(my $host = 'localhost' ),
    'l|logger'      => \(my $logger_file = File::Spec->catdir( File::Spec->rel2abs( dirname( $0 ) ) , 'log_processor.logger' ) ),
    'channel'       => \(my $channel = 1 ),
);

Log::Log4perl::init_and_watch( $logger_file );
my $logger = Log::Log4perl->get_logger;

sub load_yaml {
    my $file = shift // die 'error, no file specified';
    -f $file || do { 
        $logger->fatal("$file not found!..");
        exit(2)
    };
    my $ret = LoadFile($file) // do { 
        $logger->fatal("Error!..Cannot parse $file");
        exit(3)
    };
    $logger->trace('Rules:'.Dumper($ret));
    return $ret
}


my $conf = load_yaml( $config_file );
my $rules = load_yaml( $rules_file );

$host = (defined( $conf->{ RABBITMQ_HOST } ))? $conf->{ RABBITMQ_HOST } : $host ;

use Net::AMQP::RabbitMQ;
my $mq = Net::AMQP::RabbitMQ->new();

$mq->connect($host, {});
$mq->channel_open($channel);
my $options = { auto_delete => 0 };
$mq->queue_declare($channel, $incoming, $options );
$mq->queue_declare($channel,$outgoing, $options );

$mq->consume( $channel, $incoming );

$logger->info('waiting for messages');

#send_line("Apr 22 13:07:46 eos-leaf1 Ebra: %LINEPROTO-5-UPDOWN: Line protocol on Interface Ethernet1 (CONNECTS_to_Ethernet1_on_eos-spine1), changed state to down");
#send_line("Apr 22 13:48:19 eos-leaf1 Ebra: %LINEPROTO-5-UPDOWN: Line protocol on Interface Ethernet7, changed state to up");
#send_line("Apr 22 14:26:58 MIKEL mib2d[2395]: SNMP_TRAP_LINK_DOWN: ifIndex 517, ifAdminStatus down(2), ifOperStatus down(2), ifName ge-0/0/0");

if( $daemonize ) {
        &daemonize;
}

my %stats;

while(1) {
    my $received = $mq->recv(0);
    my $line = $received->{body};
    $logger->debug("received $line");
    $stats{ received }++;
    my $ret = parse_line( $line, $conf, $rules );
    if( defined( $ret ) ) {
        send_event( $ret, $mq, $channel, $outgoing );
        $stats{ sent }++
    }
    else {
        $logger->debug("Cannot match to any rule: $line")
    }
}

sub send_line {
    send_event( parse_line( $_[0], $conf, $rules ), $mq, $channel, $outgoing )
}
                
sub send_event {
    my $event   = shift // die 'event cannot be undefined';
    my $mq      = shift // die 'message queue object cannot be undefined';
    my $channel = shift // die 'channel name cannot be undefined';
    my $key     = shift // die 'routing key name cannot be undefined';
   
    my $json = encode_json( $event ) // do {
        $logger->fatal('cannot serialize to JSON:'.Dumper($event));
        exit(3)
    };
    $logger->info("sending to channel=$channel, key=$key the following message: $json");
    $mq->publish($channel, $key, $json );
}

sub parse_line {
    my $line    = shift // die 'line cannot be undef';
    my $config  = shift // die 'config cannot be undef';
    my $rules   = shift // die 'rules cannot be undef';

    my @ret;

    for my $rule (keys $rules->%*) {
        $logger->debug("trying rule $rule");
        my $rule_struct = $rules->{ $rule };
        $logger->trace( Dumper( $rule_struct ) );
        my $device_type = $rule_struct->{ device_type } // die "Rule $rule does not contain a device_type field";
        my $regex_str = $rule_struct->{ regex } // die "Rule $rule does not contain a regex field";
        my $alert_type = $rule_struct->{ alert_type } // die "Rule $rule does not contain an alert_type field";
        my @remediate = $rule_struct->{ remediate }->@*;
        my $base_re = eval { qr/$config->{BASEREG}/ };
        if( $@ ) {
            $logger->error("Cannot use regular expression: $base_re");
            return
        }
        $logger->trace( $base_re );
        if( $line =~ $base_re ) {
            my %basic = ( %+ );
            $logger->debug('basic info:'.join(' ',map { $_.'=>'.$basic{$_} } (sort keys %basic ) ) );
            my $rest = $+{rest} // do {
                $logger->error("Basic regular expression MUST include a 'rest' field");
                return
            };
            my $rule_re = eval { qr/$regex_str/ };
            if( $@ ) {
                $logger->error("Cannot use rule $rule regexp: $regex_str");
                return
            }
            $logger->trace("rest is: $rest");
            if( $rest =~ /$rule_re/ ) {
                $logger->trace(Dumper(\%+));
                $logger->info("message matches $rule");
                my $event = {
                    device_type     => $device_type,
                    remediations    =>[ @remediate ],
                    hostname        => $basic{ hostname },
                    date            => $basic{ time },
                    parameters      => {
                        %+,
                    },
                };
                $logger->info("event: ".Dumper($event));
                push @ret,$event;
                return $event
            }
            else {
                $logger->debug("message does not match rest of $rule")
            }
        }
        else {
            $logger->trace("$rule does not match")
        }
    }
    return
}


# from http://perldoc.perl.org/perlipc.html#Complete-Dissociation-of-Child-from-Parent
sub daemonize {
    chdir("/")                      || die "can't chdir to /: $!";
    open(STDIN,  '<', '/dev/null')  || die "can't read /dev/null: $!";
    open(STDOUT, '>', '/dev/null')  || die "can't write to /dev/null: $!";
    defined(my $pid = fork())       || die "can't fork: $!";
    exit if $pid;                   # non-zero now means I am the parent
    (setsid() != -1)                || die "Can't start a new session: $!";
    open(STDERR, '>&', \*STDOUT)    || die "can't dup stdout: $!";
}



