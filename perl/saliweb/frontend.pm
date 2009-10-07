package saliweb::frontend;

use saliweb::server qw(validate_user);

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(check_optional_email check_required_email);

use File::Spec;
use IO::Socket;
use DBI;
use CGI;

sub new {
    my ($invocant, $config_file, $server_name) = @_;
    my $class = ref($invocant) || $invocant;
    my $self = {};
    bless($self, $class);
    $self->{'CGI'} = $self->_setup_cgi();
    $self->{'server_name'} = $server_name;
    # Read configuration file
    $self->{'config'} = my $config = read_config($config_file);
    $self->{'htmlroot'} = $config->{general}->{urltop};
    $self->{'cgiroot'} = $self->{'htmlroot'} . "/cgi/";
    $self->{'dbh'} = my $dbh = connect_to_database($config);
    $self->_setup_user($dbh);
    return $self;
}

sub htmlroot {
    my $self = shift;
    return $self->{'htmlroot'};
}

sub cgiroot {
    my $self = shift;
    return $self->{'cgiroot'};
}

sub email {
    my $self = shift;
    if (defined($self->{'user_info'})) {
        return $self->{'user_info'}->{'email'};
    }
}

sub _setup_cgi {
    return new CGI;
}

sub _setup_user {
    my ($self, $dbh) = @_;
    my $q = $self->{'CGI'};

    my %cookie = $q->cookie('sali-servers');
    $self->{'user_name'} = "Anonymous";
    $self->{'user_info'} = undef;
    if ($cookie{'user_name'}) {
        my ($user_name, $hash, $user_info) =
            &validate_user($dbh, 'servers', 'hash', $cookie{'user_name'},
                           $cookie{'session'});
        if (($user_name ne "not validated") && ($user_name ne "")
            && ($user_name)) {
            $self->{'user_name'} = $user_name;
            $self->{'user_info'} = $user_info;
        }
    }
}

sub start_html {
    my ($self) = @_;
    my $q = $self->{'CGI'};
    my $style = "/saliweb/css/server.css";
    return $q->header .
           $q->start_html(-title => $self->{'server_name'},
                          -style => {-src=>$style},
                          -onload=>"opt.init(document.forms[0])",
                          -script=>[{-language => 'JavaScript',
                                     -src=>"/saliweb/js/salilab.js"}]
                          );
}

sub end_html {
    my ($self) = @_;
    my $q = $self->{'CGI'};
    return $q->end_html;
}

sub get_projects {
    my %projects;
    return \%projects;
}

sub get_project_menu {
    return "";
}

sub header {
    my $self = shift;
    my $q = $self->{'CGI'};
    my $projects = $self->get_projects();
    my $project_menu = $self->get_project_menu($q);
    my $navigation_links = $self->get_navigation_links($q);
    my $user_name = $self->{'user_name'};
    unshift @$navigation_links,
            $q->a({-href=>"/scgi/server.cgi?logout=true"},"Logout");
    unshift @$navigation_links,
            $q->a({-href=>"/scgi/server.cgi"},"Current User:$user_name");
    my $navigation = "<div id=\"navigation_second\">" .
                     join("&nbsp;&bull;&nbsp;\n", @$navigation_links) .
                     "</div>";
    return saliweb::server::header($self->{'cgiroot'}, $self->{'server_name'},
                                   "none", $projects, $project_menu,
                                   $navigation);
}

sub check_optional_email {
    my ($email) = @_;
    if ($email) {
        return check_required_email($email);
    }
}

sub check_required_email {
    my ($email) = @_;
    if ($email !~ m/^[\w\.-]+@[\w-]+\.[\w-]+((\.[\w-]+)*)?$/ ) {
        return "Please provide a valid return email address";
    }
}

sub failure {
    my ($self, $msg) = @_;
    my $q = $self->{'CGI'};
    return $q->table(
               $q->Tr($q->td({-class=>"redtxt", -align=>"left"},
                      $q->h3("Server Error:"))) .
               $q->Tr($q->td($q->b("An error occured during your request:"))) .
               $q->Tr($q->td("<div class=standout>$msg</div>")) .
               $q->Tr($q->td($q->b("Please click on your browser's \"BACK\" " .
                                   "button, and correct " .
                                   "the problem.",$q->br))));
}


sub footer {
    return "";
}

sub get_index_page {
    return "";
}

sub get_submit_page {
    return "";
}

sub get_results_page {
    return "";
}

sub get_queue_page {
    my $self = shift;
    my $q = $self->{'CGI'};
    my $dbh = $self->{'dbh'};
    my $return = "<h3>Current " . $self->{'server_name'} . " Queue</h3>\n";
    $return .= $q->table($q->Tr([$q->th(['Job ID', 'Submit time (UTC)',
                                         'Status']),
                                 $self->get_queue_rows($q, $dbh)
                                ]));

    return $return . $self->get_queue_key();
}

sub get_help_page {
    my ($self, $display_type) = @_;
    my $file;
    if ($display_type eq "contact") {
        $file = "contact.txt";
    } elsif ($display_type eq "news") {
        $file = "news.txt";
    } else {
        $file = "help.txt";
    }
    return $self->get_text_file($file);
}

sub get_text_file {
    my ($self, $file) = @_;
    my $ret = "<div id=fullpart>\n";
    open ("TXT","../txt/$file");
    while ($line=<TXT>) {
        $ret .= $line;
    }
    $ret .= "</div>";
    $ret .= "<div style=\"clear:both;\"></div>";
    return $ret;
}

sub get_queue_rows {
    my ($self, $q, $dbh) = @_;
    my @rows;
    my $query =
         $dbh->prepare("select name,submit_time,state from jobs " .
                       "where state != 'ARCHIVED' and state != 'EXPIRED' ".
                       "order by submit_time desc")
              or die "Couldn't prepare query " . $dbh->errstr;
    $query->execute() or die "Couldn't execute query " . $dbh->errstr;
    while (my @data = $query->fetchrow_array()) {
        push @rows, $q->td([$data[0], $data[1], $data[2]]);
    }
    return @rows;
}

sub get_queue_key {
    my $self = shift;
    my $q = $self->{'CGI'};
    return
      $q->h3("Key") .
      $q->p($q->b("INCOMING:"),
            " the job has been successfully submitted by the " .
            "web interface. If your job is stuck in this state for more than " .
            "15 minutes, contact us for help.") .

      $q->p($q->b("RUNNING:"),
            " the job is running on our grid machines. When the system is " .
            "is particularly busy, this could take hours or days, so please " .
            "be patient. Resubmitting your job will not help.") .

      $q->p($q->b("COMPLETED:"),
            " the job has finished. You can find the job " .
            "results at the URL given when you submitted it. If you provided " .
            "an email address, you should also receive an email notification " .
            "when the job finishes.") .

      $q->p($q->b("FAILED:"),
            " a technical fault occurred. We are automatically " .
            "notified of such jobs, and will resubmit the job for you once " .
            "the problem has been fixed. (Typically, resubmitting it " .
            "yourself will not help.)");
}

sub _display_web_page {
    my ($self, $content) = @_;
    print $self->start_html();
    print $self->header();
    print "<div id=\"fullpart\">";
    print $content;
    print "</div></div><div style=\"clear:both;\"></div>";
    print $self->footer();
    print $self->end_html;
}

sub display_index_page {
    my $self = shift;
    $self->_display_web_page($self->get_index_page());
}

sub display_submit_page {
    my $self = shift;
    $self->_display_web_page($self->get_submit_page());
}

sub display_queue_page {
    my $self = shift;
    $self->_display_web_page($self->get_queue_page());
}

sub display_help_page {
    my $self = shift;
    my $q = $self->{'CGI'};
    my $display_type = $q->param('type') || 'help';
    $self->_display_web_page($self->get_help_page($display_type));
}

sub display_results_page {
    my $self = shift;
    my $q = $self->{'CGI'};
    my $dbh = $self->{'dbh'};

    my $job = $q->param('job');
    my $passwd = $q->param('passwd');
    my $file = $q->param('file');

    my $query = $dbh->prepare("select state,directory,archive_time from jobs " .
                              "where name=? and passwd=?")
                or die "Cannot prepare: " . $dbh->errstr;
    $query->execute($job, $passwd) or die "Cannot execute " . $dbh->errstr;

    my @data = $query->fetchrow_array();

    if (!@data) {
        $self->_display_web_page(
                 $q->p("Job '$job' does not exist, or wrong password."));
    } elsif ($data[0] ne 'COMPLETED') {
        $self->_display_web_page(
                 $q->p("Job '$job' has not yet completed; please check " .
                       "back later.") .
                 $q->p("You can also check on your job at the " .
                       "<a href=\"queue\">queue</a> page."));
    } else {
        chdir($data[1]);
        if (defined($file) and -f $file and $self->allow_file_download($file)) {
            $self->download_file($q, $file);
        } else {
            $self->_display_web_page($self->get_results_page($job, $data[2]));
        }
    }
}

sub allow_file_download {
    my ($self, $file) = @_;
    return 1;
}

sub get_file_mime_type {
    return 'text/plain';
}

sub download_file {
    my ($self, $q, $file) = @_;
    print $q->header($self->get_file_mime_type($file));
    open(FILE, "$file") or die "Cannot open $file: $!";
    while(<FILE>) {
        print;
    }
    close FILE;
}

sub help_link {
    my ($self, $target) = @_;

    my $q = $self->{'CGI'};
    my $url = "help?style=helplink&type=help#$target";

    return $q->a({-href=>"$url",-border=>"0",
                  -onClick=>"launchHelp(\'$url\'); return false;"},
                 $q->img({-src=>"/img/help.jpg", -border=>0,
                          -valign=>"bottom"} ));
}

sub make_job {
  my ($self, $user_jobname) = @_;
  my $config = $self->{'config'};
  my $dbh = $self->{'dbh'};
  # Remove potentially dodgy characters in jobname
  $user_jobname =~ s/[^a-zA-Z0-9_-]//g;
  # Make sure jobname fits in the db (plus extra space for
  # auto-generated suffix if needed)
  $user_jobname = substr($user_jobname, 0, 30);

  my $query = $dbh->prepare('select count(name) from jobs where name=?')
                 or die "Cannot prepare query ". $dbh->errstr;
  my ($jobname, $jobdir);
  $jobdir = try_job_name($user_jobname, $query, $dbh, $config);
  if ($jobdir) {
    return ($user_jobname, $jobdir);
  }
  for (my $tries = 0; $tries < 50; $tries++) {
    $jobname = $user_jobname . "_" . int(rand(100000)) . $tries;
    $jobdir = try_job_name($jobname, $query, $dbh, $config);
    if ($jobdir) {
      return ($jobname, $jobdir);
    }
  }
  die "Could not determine a unique job name";
}

sub generate_results_url {
    my ($self, $jobname) = @_;
    my $passwd = &generate_random_passwd(10);
    $url = $self->cgiroot . "/results?job=$jobname&passwd=$passwd";
    return ($url, $passwd);
}

sub submit_job {
  my ($self, $jobname, $passwd, $email, $jobdir, $url) = @_;
  my $config = $self->{'config'};
  my $dbh = $self->{'dbh'};

  # Insert row into database table
  my $query = "insert into jobs (name,passwd,contact_email,directory,url," .
              "submit_time) VALUES(?, ?, ?, ?, ?, UTC_TIMESTAMP())";
  my $in = $dbh->prepare($query) or die "Cannot prepare query ". $dbh->errstr;
  $in->execute($jobname, $passwd, $email, $jobdir, $url)
        or die "Cannot execute query " . $dbh->errstr;

  # Use socket to inform backend of new incoming job
  my $s = IO::Socket::UNIX->new(Peer=>$config->{general}->{'socket'},
                                Type=>SOCK_STREAM);
  if (defined($s)) {
    print $s "INCOMING $jobname";
    $s->close();
  }
}

sub generate_random_passwd {
  # Generate a random alphanumeric password of the given length
  my ($len) = @_;
  my @validchars = ('a'..'z', 'A'..'Z', 0..9);
  my $randstr = join '', map $validchars[rand @validchars], 1..$len;
  return $randstr;
}


sub read_ini_file {
  my ($filename) = @_;
  open(FILE, $filename) or die "Cannot open $filename: $!";
  my $contents;
  my $section;
  while(<FILE>) {
    if (/^\[(\S+)\]$/) {
      $section = lc $1;
    } elsif (/^\s*(\S+)\s*[=:]\s*(\S+)\s*$/) {
      my ($key, $value) = (lc $1, $2);
      if ($section eq 'directories' and $key ne 'install') {
        $key = uc $key;
      }
      $contents->{$section}->{$key} = $value;
    }
  }
  close FILE;
  return $contents;
}

sub read_config {
  my ($filename) = @_;
  my $contents = read_ini_file($filename);
  my ($vol, $dirs, $file) = File::Spec->splitpath($filename);
  my $frontend_file = File::Spec->rel2abs(
                             $contents->{database}->{frontend_config}, $dirs);
  my $frontend_config = read_ini_file($frontend_file);
  $contents->{database}->{user} = $frontend_config->{frontend_db}->{user};
  $contents->{database}->{passwd} = $frontend_config->{frontend_db}->{passwd};
  return $contents;
}

sub connect_to_database {
  my ($config) = @_;
  my $dbh = DBI->connect("DBI:mysql:" . $config->{database}->{db},
                         $config->{database}->{user},
                         $config->{database}->{passwd})
            or die "Cannot connect to database: $!";
  return $dbh;
}

sub try_job_name {
  my ($jobname, $query, $dbh, $config) = @_;
  my $jobdir = $config->{directories}->{INCOMING} . "/" . $jobname;
  if (-d $jobdir) {
    return;
  }
  $query->execute($jobname) or die "Cannot execute: " . $dbh->errstr;
  my @data = $query->fetchrow_array();
  if ($data[0] == 0) {
    mkdir($jobdir) or die "Cannot make job directory $jobdir: $!";
    $query->execute($jobname) or die "Cannot execute: " . $dbh->errstr;
    @data = $query->fetchrow_array();
    if ($data[0] == 0) {
      return $jobdir;
    }
  }
}

1;
