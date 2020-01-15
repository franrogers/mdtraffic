#!/usr/bin/env perl

use strict;
use warnings;

use HTML::TokeParser::Simple;
use LWP::Simple;
use XML::Twig;


my (@counties, @locs);

while (@ARGV) {
	my $arg = shift @ARGV;
	
	if ($arg eq '-h') {
		print STDERR "usage: $0 [-c COUNTY_REGEX] [LOCATION_REGEX]\n";
		exit 0;
	}
	elsif ($arg eq '-c') {
		push @counties, shift @ARGV;
		push @locs, shift @ARGV;
	}
	else {
		push @counties, undef;
		push @locs, $arg;
	}
}

my $t = XML::Twig->new(twig_handlers => {item => \&item});
my $url = 'https://chart.maryland.gov/rss/ProduceRSS.aspx?Type=TIandRC&filter=ALL';
$t->parse(get($url));

my $count = 0;
sub item {
	my ($t, $item) = @_;
	my $cat = $item->first_child('category')->text;
	my $title = $item->first_child('title')->text;
	my $html = $item->first_child('description')->text;

	my ($county, $loc) = $title =~ /(.+) : (.+)/;

	if (@locs) {
		my $is_match = 0;

		for (my $n = 0; $n < scalar @locs; $n++) {
			if ($counties[$n] && $locs[$n]) {
				$is_match = 1 if ($county =~ /$counties[$n]/i and
					          $loc =~ /$locs[$n]/i);
			}
			elsif ($counties[$n]) {
				$is_match = 1 if $county =~ /$counties[$n]/i;
			}
			elsif ($locs[$n]) {
				$is_match = 1 if $loc =~ /$locs[$n]/i;
			}
		}

		return unless $is_match;
	}

	my ($type, $dir, $date, $desc);
	my $p = HTML::TokeParser::Simple->new(\$html);
	if ($cat eq 'Traffic Incidents') {
		$desc = '';
		while (my $token = $p->get_token) {
			next unless $token->is_text;
			my $text = $token->as_is;

			unless ($type) {
				($type, $dir) = $text =~ /^(.+): .+ (\S+)$/;
				next;
			}

			if ($text =~ /^Created: /) {
				($date) = $text =~ /^Created:  (.+) by/;
			} else {
				$desc .= "\n" if $desc;
				$desc .= $text;
			}
		}
	}
	else {
		$type = 'Closure';
		$desc = '';
		while (my $token = $p->get_token) {
			next unless $token->is_text;
			my $text = $token->as_is;

			next if $text eq 'Direction: ';
			unless ($dir) {
				$dir = $text;
				next;
			}

			if ($text =~ /^Created:  /) {
				($date) = $text =~ /^Created:  (.+) by/;
			} else {
				$desc .= "\n" if $desc;
				$desc .= $text;
			}
		}
	}

	print "%%\n" if $count++;

	print "Location: $loc\n";
	print "County: $county\n" if $county;
	print "Direction: $dir\n" if $dir;
	print "Type: $type\n" if $type;
	print "Date: $date\n" if $date;
	print "\n$desc\n" if $desc;
}
