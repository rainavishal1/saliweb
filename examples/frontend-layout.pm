sub get_navigation_links {
    my $self = shift;
    my $q = $self->cgi;
    return [ $q->a({-href=>$self->index_url}, "ModFoo Home"),
             $q->a({-href=>$self->queue_url}, "ModFoo Queue"),
             $q->a({-href=>$self->help_url}, "Help"),
             $q->a({-href=>$self->contact_url}, "Contact")
           ];
}

sub get_project_menu {
    my $self = shift;
    return <<MENU;
<h4>Developer:</h4>
<p>Sali Lab</p>
MENU
}

sub get_footer {
    my $self = shift;
    return <<FOOTER;
<p>
Please cite Bob et. al, JMB 2008.
</p>
FOOTER
}
