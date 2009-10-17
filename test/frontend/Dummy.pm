package Dummy::IncomingJob;

sub new {
    my $self = {};
    bless($self, shift);
    return $self;
}

sub results_url {
    return "http://test/results.cgi?job=foo&passwd=bar";
}
1;


package Dummy::Query;

sub new {
    my $self = {};
    bless($self, shift);
    $self->{execute_calls} = 0;
    $self->{fetch_calls} = 0;
    return $self;
}

sub execute {
    my $self = shift;
    my $jobname = shift;
    $self->{jobname} = $jobname;
    $self->{execute_calls}++;
    my $calls = $self->{execute_calls};
    if ($jobname eq "fail-$calls") {
        return undef;
    }
    return $jobname ne "fail-job";
}

sub fetchrow_array {
    my $self = shift;
    $self->{fetch_calls}++;
    if ($self->{jobname} eq "existing-job") {
        return (1);
    } elsif ($self->{jobname} eq "justmade-job"
             and $self->{execute_calls} > 1) {
        return (1);
    } else {
        return (0);
    }
}
1;


package Dummy::QueueQuery;
our @ISA = qw/Dummy::Query/;

sub execute {
    my $self = shift;
    $self->{execute_calls}++;
    return $self->{failexecute} != 1;
}

sub fetchrow_array {
    my $self = shift;
    $self->{fetch_calls}++;
    if ($self->{fetch_calls} == 1) {
        return "job1", "time1", "state1";
    } elsif ($self->{fetch_calls} == 2) {
        return "job2", "time2", "state2";
    } else {
        return;
    }
}
1;

package Dummy::ResultsQuery;
our @ISA = qw/Dummy::Query/;

sub execute {
    my $self = shift;
    $self->{job} = shift;
    $self->{passwd} = shift;
    $self->{execute_calls}++;
    return $self->{failexecute} != 1;
}

sub fetchrow_hashref {
    my $self = shift;
    if ($self->{job} eq "not-exist-job") {
        return undef;
    } elsif ($self->{job} eq "running-job") {
        return {state=>'RUNNING'};
    } elsif ($self->{job} eq "archived-job") {
        return {state=>'ARCHIVED'};
    } elsif ($self->{job} eq "expired-job") {
        return {state=>'EXPIRED'};
    } else {
        return {state=>'COMPLETED', directory=>'/tmp',
                name=>$self->{job}, passwd=>'testpw'};
    }
}
1;


package Dummy::UserQuery;
our @ISA = qw/Dummy::Query/;

sub execute {
    my ($self, $user, $hash) = @_;
    $self->{hash} = $hash;
    $self->{execute_calls}++;
    return $self->{failexecute} != 1;
}

sub fetchrow_array {
    my $self = shift;
    if ($self->{hash} eq 'wronghash') {
        return undef;
    } else {
        return ('test user', 'hash', 'first', 'last', 'test email');
    }
}
1;


package Dummy::DB;

sub new {
    my $self = {};
    $self->{failprepare} = 0;
    $self->{failexecute} = 0;
    $self->{preparecalls} = 0;
    $self->{query} = undef;
    $self->{query_class} = 'Dummy::Query';
    bless($self, shift);
    return $self;
}

sub errstr {
    my $self = shift;
    return "DB error";
}

sub prepare {
    my ($self, $query) = @_;
    $self->{preparecalls}++;
    if ($self->{failprepare}) {
        return undef;
    } else {
        $self->{query} = new $self->{query_class};
        $self->{query}->{failexecute} = $self->{failexecute};
        return $self->{query};
    }
}
1;

package Dummy::Frontend;
our @ISA = qw/saliweb::frontend/;
use saliweb::frontend;
use Error;

sub _check_rate_limit {
    my $self = shift;
    $self->{rate_limit_checked} = 1;
    return (1, 10, 30);
}

sub get_project_menu {
    my $self = shift;
    return "Project menu for " . $self->{server_name} . " service";
}

sub get_navigation_links {
    my $self = shift;
    return ["Link 1", "Link 2 for " . $self->{server_name} . " service"];
}

sub get_index_page {
    my $self = shift;
    if ($self->{server_name} eq "failindex") {
        throw saliweb::frontend::InternalError("get_index_page failure");
    } else {
        return "test_index_page";
    }
}

sub get_submit_page {
    my $self = shift;
    if ($self->{server_name} eq "invalidsubmit") {
        throw saliweb::frontend::InputValidationError("bad submission");
    } elsif ($self->{server_name} eq "failsubmit") {
        throw saliweb::frontend::InternalError("get_submit_page failure");
    } else {
        if ($self->{server_name} ne "nosubmit") {
            $self->_add_submitted_job("Dummy");
        }
        return "test_submit_page";
    }
}

sub get_queue_page {
    my $self = shift;
    if ($self->{server_name} eq "failqueue") {
        throw saliweb::frontend::InternalError("get_queue_page failure");
    } else {
        return "test_queue_page";
    }
}

sub get_help_page {
    my $self = shift;
    if ($self->{server_name} eq "failhelp") {
        throw saliweb::frontend::InternalError("get_help_page failure");
    } else {
        return "test_help_page";
    }
}

sub get_results_page {
    my ($self, $jobobj) = @_;
    if ($self->{server_name} eq "failresults") {
        throw saliweb::frontend::InternalError("get_results_page failure");
    } else {
        return "test_results_page " . ref($jobobj) . " " . $jobobj->{name};
    }
}

sub get_footer {
    my $self = shift;
    if ($self->{server_name} eq "failfooter") {
        # NoThrowError has no throw method, so use the superclass
        my $exc = new Dummy::NoThrowError("footer failure");
        Error::throw($exc);
    }
    return "";
}
1;


package Dummy::NoThrowError;
use base qw(Error::Simple);

sub throw {
    # do-nothing throw, so that the exception cannot be rethrown by
    # fatal error handlers (so we can catch stdout reliably)
}
1;

package Dummy::RESTService;
use base "saliweb::frontend::RESTService";
use Error;

sub _check_rate_limit { return Dummy::Frontend::_check_rate_limit(@_); }

sub get_project_menu { return Dummy::Frontend::get_project_menu(@_); }

sub get_navigation_links { return Dummy::Frontend::get_navigation_links(@_); }

sub get_submit_page {
    my $self = shift;
    if ($self->{server_name} eq "invalidsubmit") {
        throw saliweb::frontend::InputValidationError("bad submission");
    } elsif ($self->{server_name} eq "failsubmit") {
        throw saliweb::frontend::InternalError("get_submit_page failure");
    } else {
        if ($self->{server_name} ne "nosubmit") {
            $self->_add_submitted_job(new Dummy::IncomingJob());
        }
        return "test_submit_page";
    }
}

sub get_results_page {
    my ($self, $jobobj) = @_;
    return "test_results_page " .
           $jobobj->get_results_file_url('test.txt') . ' ' .
           $jobobj->get_results_file_url('log.out');
}

1;
