#!/usr/bin/perl -w

use lib '.';
use test_setup;

use Test::More 'no_plan';
use Test::Exception;
use Test::Output qw(stdout_from stdout_is);
use Error;
use CGI;
use Dummy;
use strict;

# Tests of the saliweb::frontend::RESTService results page methods

BEGIN { use_ok('saliweb::frontend::RESTService'); }

sub make_test_frontend {
    my $q = new CGI;
    $q->param('job', shift);
    $q->param('passwd', shift);
    my $dbh = new Dummy::DB;
    $dbh->{query_class} = 'Dummy::ResultsQuery';
    my $cls = {CGI=>$q, dbh=>$dbh, server_name=>'test',
               cgiroot=>'http://test'};
    bless($cls, 'Dummy::RESTService');
    return $cls;
}

# Test display_results_page
{
    my $cls = make_test_frontend(undef, undef);
    my $out = stdout_from { $cls->display_results_page() };
    like($out, '/^Status: 400 Bad Request.*' .
               'Content\-Type: text\/xml.*' .
               '<error type="results">Missing \'job\' and \'passwd\'.*' .
               '<\/error>/s',
         "REST display_results_page missing job and passwd");

    $cls = make_test_frontend('testjob', 'passwd');
    $out = stdout_from { $cls->display_results_page() };
    like($out, '/^Content\-Type: text\/xml.*' .
               '<saliweb.*' .
               '<results_file xlink:href="http:\/\/test/job\?' .
               'job=testjob;passwd=testpw;file=test\.txt.*>' .
               'test\.txt<\/results_file>.*' .
               '<results_file xlink:href=.*log\.out.*>log\.out' .
               '<\/results_file>.*' .
               '<\/saliweb>/s',
         '                     (completed job)');
}
