package Finance::Coinbase::HMAC256;

use strict;
use warnings;
use Carp qw/croak/;

use Time::HiRes qw(gettimeofday);
use Digest::SHA qw(hmac_sha256_hex);
use Config::Tiny ();

use JSON::XS;
use LWP::UserAgent;

our $AUTOLOAD;

sub new {
    my $pkg    = shift;
    my $params = shift;
    help(q{Error specifying config file})
      if not $params
      or ref $params ne q{HASH}
      or not exists $params->{config_file};
    my $config = Config::Tiny->read( $params->{config_file} )
      or croak q{Can't find configuration file.};
    my $baseurl = $config->{_}->{baseurl}
      or croak q{Can't find base url.};
    my $ro_key = $config->{_}->{key} or croak q{Missing credentials.};
    my $ro_secret = $config->{_}->{secret}
      or croak q{Missing credentials.};
    my $lwp  = LWP::UserAgent->new;
    my $self = {
        ua        => $lwp,
        ro_key    => $ro_key,
        ro_secret => $ro_secret,
        baseurl   => $baseurl,
        config    => $config,
    };
    bless $self, $pkg;
    return $self;
}

sub help {
    my $msg = shift;
    print STDERR qq{
      my \$cbclient = Coinbbase->new({config_file=>/path/to/config/file}); \n
};
    croak($msg) ? $msg : qq{Unspecified error\n};
}

sub AUTOLOAD {
    my $self    = shift;
    my $payload = shift;
    if ($payload) {
        $payload = JSON::XS->new->utf8->encode($payload);
    }
    my $command = $AUTOLOAD;
    $command =~ s/.*:://;
    my @c = split /___/, $command;
    my $method = uc( $c[0] );
    $command = $c[1];
    $command =~ s/__/\//g;
    my $uri     = $self->{baseurl} . qq{/$command};
    my $request = $self->genReq( $uri, $method, $payload );
    my $res     = $self->{ua}->request($request);
    return $res->content();
}

sub genReq {
    my ( $self, $uri, $method, $payload ) = @_;
    my $req = HTTP::Request->new( $method => $uri );
    if ($payload) {
        $req->content($payload);
    }
    $req->content_type('application/json');
    my $nonce = microtime();
    $req->header( 'ACCESS_NONCE' => $nonce );
    $req->header( 'ACCESS_KEY'   => $self->{ro_key} );
    $req->header( 'ACCESS_SIGNATURE' =>
          $self->signReq( $self->{ro_secret}, $nonce, $uri, $req->content() ) );
    return $req;
}

sub signReq {
    my $self = shift;
    my ( $secret, $nonce, $uri, $content ) = @_;
    my $message = qq{$nonce$uri$content};
    my $digest = hmac_sha256_hex( $message, $secret );
    return $digest;
}

sub get {
    my $self    = shift;
    my @path    = @_;
    my $payload = undef;
    if ( ref $path[-1] eq q{HASH} ) {
        $payload = pop @path;
    }

    # croak if there are no params left to define an API call
    croak q{Invalid request} if not @path;
    my $uri = q{get___} . join q{__}, @path;
    return $self->$uri($payload);
}

sub post {
    my $self    = shift;
    my @path    = @_;
    my $payload = undef;
    if ( ref $path[-1] eq q{HASH} ) {
        $payload = pop @path;
    }

    # croak if there are no params left to define an API call
    croak q{Invalid request} if not @path;
    my $uri = q{post___} . join q{__}, @path;
    return $self->$uri($payload);
}

sub put {
    my $self    = shift;
    my @path    = @_;
    my $payload = undef;
    if ( ref $path[-1] eq q{HASH} ) {
        $payload = pop @path;
    }

    # croak if there are no params left to define an API call
    croak q{Invalid request} if not @path;
    my $uri = q{put___} . join q{__}, @path;
    return $self->$uri($payload);
}

sub delete {
    my $self    = shift;
    my @path    = @_;
    my $payload = undef;
    if ( ref $path[-1] eq q{HASH} ) {
        $payload = pop @path;
    }

    # croak if there are no params left to define an API call
    croak q{Invalid request} if not @path;
    my $uri = q{delete___} . join q{__}, @path;
    return $self->$uri($payload);
}

sub microtime { return sprintf "%d%06d", gettimeofday; }

sub DESTROY {
    return;
}

1;

__END__

=pod
 
=head1 NAME

Finance::Coinbase::HMAC256 

=head1 VERSION

This documentation refers to Finance::Coinbase::HMAC256 version 1.0.

=head1 SYNOPSIS
 
        use strict;
        use warnings;
  
        use Finance::Coinbase::HMAC256 ();
 
        my $HOME      = ( getpwuid $> )[7];
        my $config    = qq{$HOME/.api-configs/coinbase.conf};
        my $cb = Finance::Coinbase::HMAC256->new({ config_file => $config });
  
        my $results = JSON::XS->new->utf8->decode($cb->get___transactions({ page => 1 }));
  
        foreach my $txn (@{$results->{transactions}}) {
          my $txnid = $txn->{transaction}->{id};
          printf("%s: %s\n",$txnid,$txn->{transaction}->{status});
          print $cb->get(q{transactions},$txnid);
        }

=head1 DESCRIPTION

This Perl module provides a programatic interface to the Finance::Coinbase::HMAC256 API and
requires the utilization of the HMAC256 signing scheme.

See L<https://coinbase.com/api/doc> for more details about the supported API calls.

=head1 SUBROUTINES/METHODS

The methods are largely AUTOLOAD'd and take the general form of:

        HTTPMETHOD__path__to__resource($request_body_hashref});

Note: double-underscore separates C<HTTPMETHOD> and the beginning of the resource path.

This corresponds to a call of the form:

        HTTPMETHOD /path/to/resource
        { "key1":"val1", "key2":"val2" }

For example,  "get___prices__buy({ qty=>2, currency=>q{USD} }))", corresponds to:

        GET /prices/buy
        { "qty":"2", "currency":"USD" }

=head2 get(qw{path to resource},{ key1=>'val1', key2=>'val2' });

This is a convenience method that translates into the supported AUTOLOAD's translation
scheme.

For example, the following corresponds to /prices/buy + JSON body contents; it is
sent over HTTP GET.

        $cb->get(q{prices},q{buy},{ qty=>2, currency=>q{USD} }));

=head2 post(qw{path to resource},{ key1=>'val1', key2=>'val2' });

Same as C<get>, but for requests that require C<POST>. 

=head2 put(qw{path to resource},{ key1=>'val1', key2=>'val2' });

Same as C<get>, but for requests that require C<PUT>. 

=head2 delete(qw{path to resource},{ key1=>'val1', key2=>'val2' });

Same as C<get>, but for requests that require C<DELETE>. 

=head1 DIAGNOSTICS

The module constructor will croak if not provided a configuration file.

If the request fails, it should croak as well.

=head1 CONFIGURATION AND ENVIRONMENT

This module requires a configuration file an INI configuration compatible
with C<Config::Tiny> that contains the following 3 keys in the root section:

=over 4

=item C<key>

=item C<secret>

=item C<baseurl>

=back

Example,

        baseurl = https://coinbase.com/api/v1
        key = yourkey 
        secret = yoursecretusedforHMAC256 

=head1 DEPENDENCIES

=over 4

=item Carp

=item Time::HiRes

=item Digest::SHA

=item Config::Tiny

=item JSON::XS

=item LWP::UserAgent

=back

=head1 INCOMPATIBILITIES

This module is incompatible with non-Finance::Coinbase::HMAC256 services and will not work
with the depecrecated API.

=head1 BUGS AND LIMITATIONS

None are known, please report. Method calls for POST, PUT, and DELETE have not been 
tested.  Only a handful of GET requests have been tested.

=head1 AUTHOR

B. Estrade <estrabd@gmail.com>

=head1 LICENSE AND COPYRIGHT
 
DWTFUW.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
  
=cut
