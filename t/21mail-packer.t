# -*- perl -*-
#
# Check the dummy filter: Feed a mail into it; result must be identical
# with input.
#

use strict;

require MIME::Entity;
require Mail::IspMailGate;
require Mail::IspMailGate::Filter;
require Mail::IspMailGate::Filter::Packer;

&Sys::Syslog::openlog('21mail-packer.t', 'pid,cons', 'daemon');
eval { Sys::Syslog::setlogsock('unix'); };


my($haveGzip) = 0;
my($gzip) = $Mail::IspMailGate::Config::PACKER{'gzip'}
	  = $Mail::IspMailGate::Config::PACKER{'gzip'}; # Make -w happy
if (ref($gzip) eq 'HASH') {
    $gzip = $gzip->{'pos'};
    if ($gzip =~ /(\S+)/) {
	$gzip = $1;
    }
    if (-x $gzip) {
	$haveGzip = 1;
    }
}

$| = 1;
if (!$haveGzip) {
    print "1..0\n";
    exit 0;
}


print "1..7\n";

if (! -d 'output') {
    mkdir 'output', 0775;
}
if (! -d 'output/tmp') {
    mkdir 'output/tmp', 0775;
}

my($inFilter) = Mail::IspMailGate::Filter::Packer->new({
    'packer'    => 'gzip',
    'direction' => 'pos'
});
print (($inFilter ? "" : "not "), "ok 1\n");

my($outFilter) = Mail::IspMailGate::Filter::Packer->new({
    'packer'    => 'gzip',
    'direction' => 'neg'
});
print (($outFilter ? "" : "not "), "ok 2\n");

$Mail::IspMailGate::Config::TMPDIR =
    $Mail::IspMailGate::Config::TMPDIR = 'output/tmp';
@Mail::IspMailGate::Config::RECIPIENTS =
    @Mail::IspMailGate::Config::RECIPIENTS =
        ( { 'recipient' => 'joe-packer-in@ispsoft.de',
	    'filters' => [ $inFilter ] },
	  { 'recipient' => 'joe-packer-out@ispsoft.de',
	    'filters' => [ $outFilter ] }
	);

my($e) = MIME::Entity->build('From' => 'amar@ispsoft.de',
			     'To' => 'joe@ispsoft.de',
			     'Subject' => 'Mail-Attachment',
			     'Type' => 'multipart/mixed');
$e->attach('Path' => 'Makefile',
	   'Type' => 'text/plain',
	   'Encoding' => 'quoted-printable');
$e->attach('Path' => 'ispMailGateD',
	   'Type' => 'application/x-perl',
	   'Encoding' => 'base64');
my($entity) = MIME::Entity->build('From' => 'joe@ispsoft.de',
				  'To' => 'amar@ispsoft.de',
				  'Subject' => 'Re: Mail-Attachment',
				  'Type' => 'multipart/mixed');
$entity->attach('Path' => 'MANIFEST',
		'Type' => 'text/plain',
		'Encoding' => 'quoted-printable');
$entity->add_part($e);
print (($entity ? "" : "not "), "ok 3\n");


my($str) = $entity->as_string();

if (!open(OUT, ">output/21mp.in")  ||  !(print OUT $str)  ||  !close(OUT)) {
    die "Error while creating input file 'output/21mp.in': $!";
}
require Symbol;
my $fh = Symbol::gensym();
if (!open($fh, "<output/21mp.in")) {
    die "Error while opening input file 'output/21mp.in': $!";
}
my($str2) = '';
my($parser) = Mail::IspMailGate->new({'debug' => 1,
				      'tmpDir' => 'output/tmp',
				      'noMails' => \$str2});
print (($parser ? "" : "not "), "ok 4\n");

$parser->Main($fh, 'joe@ispsoft.de', ['joe-packer-in@ispsoft.de']);
undef $fh;
print "ok 5\n";

if (!open(OUT, ">output/21mp.tmp")  ||  !(print OUT $str)  ||  !close(OUT)) {
    die "Error while creating input file 'output/21mp.tmp': $!";
}
$fh = Symbol::gensym();
if (!open($fh, "<output/21mp.tmp")) {
    die "Error while opening input file 'output/21mp.tmp': $!";
}
my($str3) = '';
$parser->{'noMails'} = \$str3;
$parser->Main($fh, 'joe@ispsoft.de', ['joe-packer-out@ispsoft.de']);
undef $fh;
print "ok 6\n";

if ($str eq $str3) {
    print "ok 7\n";
} else {
    print "not ok 7\n";
    if (open(OUT, ">output/21mp.out")) {
	print OUT $str3;
	close(OUT);
    }
}
