#!/usr/local/avalon/bin/perl 

use strict 'vars';
use English qw( -no_match_vars );

use Data::Dumper;
use JSON;
use JSON::XS;
use Time::HiRes qw( gettimeofday );
use Encode qw(encode decode);
use File::Slurp qw(read_file);
use DBI;

my $conf_file_mail_log = '/usr/local/lancelot/custom/conf/mysql_mail_log.json';
my $conf_hash_mail_log = get_conf_hash($conf_file_mail_log) or print "Warning: Can't read config file : $conf_file_mail_log \n";
print Dumper $conf_hash_mail_log;
my $dbh_mail_log = mysql_connect($conf_hash_mail_log);

my $parse_log_file_name = '/usr/local/lancelot/custom/data/mail.log';

parse_log_file_to_mysql_mail_log($parse_log_file_name, $dbh_mail_log);

sub mysql_connect {
    my ( $cfg, $params ) = @_;
    my $host   = $cfg->{ 'host' } || $cfg->{ 'hostname' };
    my $port   = $cfg->{ 'port' };
    my $user   = $cfg->{ 'user' };
    my $pw     = $cfg->{ 'pw' }   || $cfg->{ 'pass' };
    my $dbname = $cfg->{ 'db' }   || $cfg->{ 'dbname' };
    my $socket = $cfg->{ 'socket' };
    if ( !$host or !$port or !$user or !$pw ) {
        print "[mysql_connect] Insufficient input data to establish connection to MySQL DB!\n";
        return;
    }

    if ( $socket and !-f $socket ) {
        $socket = undef;
    }

    my $conn_str = 'dbi:mysql:';
    $socket
        ? ( $conn_str .= "mysql_socket=$socket;" )
        : ( $conn_str .= "host=$host;port=$port;" );
    $conn_str .= "database=$dbname;" if $dbname;

    my $mysql_dbh = DBI->connect(
        $conn_str,
        $user, $pw,
        {
            # mysql_enable_utf8    => 1,
            mysql_auto_reconnect => 1
        }
        )
        or return;

    return $mysql_dbh;
}

sub get_conf_hash {
    my $json_file = (shift or return {});

	if (-f $json_file){
		my $content_str = File::Slurp::read_file($json_file);
		my $content_json = parse_json($content_str);
		return $content_json;
	}else{
		return {};
	}
}

sub parse_json {
	my $json_str = shift;
	my $o_json   = JSON::XS->new;
	$o_json = $o_json->allow_blessed([1]);
	$o_json->allow_nonref([1]);
	my $res;
	eval { $res = $o_json->decode($json_str); };
	if ($@) {
		print Dumper($@);
		print Dumper($json_str);
		return undef;
	}
	return $res;
}

sub parse_log_file_to_mysql_mail_log {
    my ($file_name, $dbh) = @_;
    my ($count_message, $count_log) = (0, 0);
    my $count = 0;
    $DB::single=1;
    my $message_insert_values = $dbh->prepare( "INSERT INTO message(created, id, int_id, str) VALUES(?,?,?,?);" );
    
    my $log_insert_values = $dbh->prepare( "INSERT INTO log(created, int_id, str, address) VALUES(?,?,?,?);" );
    
    open(InFile, $file_name) || print qq(>>> Error!!! Log file $file_name don't open\n);
        while (my $line = <InFile>)
        {
            $line =~ s/[\r\n]+//g;
            if ( $line =~ /^(\d{4}-\d{2}-\d{2})\s(\d{2}:\d{2}:\d{2})\s(.*?)\s(.*)$/) {
                my ($date, $time, $int_id, $end_of_line) = ($1, $2, $3, $4);
                my $date_time = $date . ' ' . $time;                
                (my $str = $line) =~ s/^$date_time //;
                if ($end_of_line =~ /<=/) {
                    if ($end_of_line =~ /\sid=(.*?)(\s.*)?$/) {
                        my $id = $1;
                        $message_insert_values->execute( 
                            $date_time,
                            $id,
                            $int_id,
                            $str
                        );
                        $count_message += 1;
                    } else {
                        $log_insert_values->execute( 
                            $date_time,
                            $int_id,
                            $str,
                            ''
                        );
                        print qq(Warning: line <$line> write to log table \n);
                        $count_log += 1;
                    }
                } else {
                    if ($end_of_line =~ /([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\.[a-zA-Z0-9_-]+)/) {
                        my $recipient = $1;
                        $log_insert_values->execute( 
                            $date_time,
                            $int_id,
                            $str,
                            $recipient
                        );
                        $count_log += 1;
                    } else {
                        $log_insert_values->execute( 
                            $date_time,
                            $int_id,
                            $str,
                            ''
                        );
                        print qq(Warning: line <$line> write to log table \n);
                        $count_log += 1;
                    }
                }
            } else {
                print qq(Error: line <$line> don't write to log table \n);
            }
            
            $count += 1;
            # last if $count > 10;
        }
    close ( InFile );
    print qq'count_message = $count_message \n';
    print qq'count_log = $count_log \n';
    my $ml = $count_log+$count_message;
    print qq'count_m+l = $ml \n';
    print qq'count_all = $count \n';
}
