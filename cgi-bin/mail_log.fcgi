#!/usr/local/avalon/bin/perl

use strict;
use CGI::Simple;
use FCGI;
use JSON::XS;
use URI::Escape;
use File::Slurp qw(read_file);
use DBI;
use Time::Piece;
use Time::Seconds;
use Data::Dumper;

#DEBUG IN COMMAND LINE
$CGI::Simple::DEBUG = 1;  # debug FCGI
$|++;                     # autoflush output 
#DEBUG IN COMMAND LINE

my $json = JSON::XS->new;

my $fcgi_request = FCGI::Request();
if ($fcgi_request->Accept() >= 0) {
    my $cgi = CGI::Simple->new;

    my $json_response;
   
    print $cgi->header(-type => "application/json", -charset => "utf-8", -access_control_allow_origin => '*');
    
    my $conf_file_mail_log = '/usr/local/lancelot/custom/conf/mysql_mail_log.json';
    my $conf_hash_mail_log = get_conf_hash($conf_file_mail_log) or print STDERR "Error: Can't read config file : $conf_file_mail_log \n";
    my $dbh_mail_log = mysql_connect($conf_hash_mail_log);
    
    if ( !defined $dbh_mail_log ) {
        print STDERR "Error: Couldn't initialize MySQL connection \n";
        $json_response = $json->encode({ 'error' => {'text' => "Couldn't initialize MySQL connection" }});
        print $json_response, "\n";
        exit;
    }
    
    # get parameters
    my $mail  = $cgi->param("mail");
    
    if ($mail !~ /([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\.[a-zA-Z0-9_-]+)/) {
        $json_response = $json->encode({ 'error' => {'text' => "Incorrect email" }});
        print $json_response, "\n";
        exit;
    }
    
    my $val = get_db_data($dbh_mail_log, $mail);
    # my $count = scalar(@$val);
    my $res = '';
    if (scalar @$val <= 100) {
        foreach my $param (@$val) {
            $res .= qq($param->{'created'} $param->{'str'} \n);
        }
    } else {
        $json_response = $json->encode({ 'error' => {'text' => "More then 100 lines" }});
        print $json_response, "\n";
        exit;
    }
    my $result->{data} = $res;
    
    # encode final json
    $json_response = $json->encode($result);
    
    # send it
    print $json_response."\n";
}

sub mysql_connect {
    my ( $cfg, $params ) = @_;
    my $host   = $cfg->{ 'host' } || $cfg->{ 'hostname' };
    my $port   = $cfg->{ 'port' };
    my $user   = $cfg->{ 'user' };
    my $pw     = $cfg->{ 'pw' }   || $cfg->{ 'pass' };
    my $dbname = $cfg->{ 'db' }   || $cfg->{ 'dbname' };
    my $socket = $cfg->{ 'socket' };
    if ( !$host or !$port or !$user or !$pw ) {
        print STDERR "[mysql_connect] Insufficient input data to establish connection to MySQL DB!\n";
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
		print STDERR Dumper($@);
		print STDERR Dumper($json_str);
		return undef;
	}
	return $res;
}

sub get_db_data {
    my ($dbh, $address) = @_;
    
    my $query_string = qq(
        SELECT  
            created, 
            id, 
            int_id, 
            str
        FROM 
            message 
        WHERE 
            str LIKE '%${address}%';
    );

    my $message_value = $dbh->selectall_arrayref($query_string,{ Slice => {} });
    
    $query_string = qq(
        SELECT  
            created, 
            int_id, 
            str, 
            address
        FROM 
            log
        WHERE
            address = ?
    );

    my $log_value = $dbh->selectall_arrayref($query_string,{ Slice => {} }, $address);

    my @result_value = ();

    push (@result_value, @$message_value, @$log_value);

    @result_value =  sort { 
        $a->{'created'} cmp $b->{'created'} or
        $a->{'int_id'} cmp $b->{'int_id'}
    } @result_value;
    
    return \@result_value;
}

