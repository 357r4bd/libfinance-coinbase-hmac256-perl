#!/usr/bin/perl
 
use strict;
use warnings;

use Coinbase ();

my $HOME      = ( getpwuid $> )[7];
my $config    = qq{$HOME/.api-configs/coinbase.conf};

my $cb = Coinbase->new({ config_file => $config });

printf("%s\n",$cb->get('prices','spot_rate'));
#printf("%s\n",$cb->get___account__balance());

# dynamically build subroutine to AUTOLOAD
#my $x = q{authorization};
#my $uri = qq{get___$x};
#printf("%s\n",$cb->$uri);
# with body
printf("%s\n",$cb->get___prices__buy({ qty=>2, currency=>q{USD} }));
printf("%s\n",$cb->get(q{prices},q{buy},{ qty=>2, currency=>q{USD} }));

__END__

my $results = JSON::XS->new->utf8->decode($cb->get___transactions({ page => 1 }));

foreach my $txn (@{$results->{transactions}}) {
  my $txnid = $txn->{transaction}->{id};
  printf("%s: %s\n",$txnid,$txn->{transaction}->{status});
  print $cb->get(q{transactions},$txnid);
}

