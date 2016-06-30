# name our package
package upstreammapper;

# include the nginx request methods and return code definitions
use nginx;

# this subroutine will be called from nginx
sub handler {
    my $r = shift;
    my @alpha = ("a".."z");
    my %upstreams = ();
    # simplistically create a mapping between letter and
    #  an IP which is between 10 and 35 of that network
    foreach my $idx (0..$#alpha) {
	$upstreams{ $alpha[$idx] } = $idx + 10;
    }
    # get the URI into an array
    my @uri = split(//,$r->uri);
    # so that we can use the first letter as a key
    my $ip = "10.100.0." . $upstreams{ $uri[1] };
    return $ip;
}

1;

__END__
