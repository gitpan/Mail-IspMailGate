# -*- perl -*-
#
# Check the dummy filter: Feed a mail into it; result must be identical
# with input.
#

use strict;

require Symbol;
require MIME::Entity;
require Mail::IspMailGate;
require Mail::IspMailGate::Filter;
require Mail::IspMailGate::Filter::Dummy;

&Sys::Syslog::openlog('20mail-dummy.t', 'pid,cons', 'daemon');
eval { Sys::Syslog::setlogsock('unix'); };


$| = 1;
print "1..4\n";

if (! -d 'output') {
    mkdir 'output', 0775;
}
if (! -d 'output/tmp') {
    mkdir 'output/tmp', 0775;
}

$Mail::IspMailGate::Config::TMPDIR =
    $Mail::IspMailGate::Config::TMPDIR = 'output/tmp';
@Mail::IspMailGate::Config::RECIPIENTS =
    @Mail::IspMailGate::Config::RECIPIENTS =
        ( { 'recipient' => 'joe-dummy@ispsoft.de',
	    'filters' => [ Mail::IspMailGate::Filter::Dummy->new({}) ] } );

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
print (($entity ? "" : "not "), "ok 1\n");

my($filter) = Mail::IspMailGate::Filter::Dummy->new({});
print (($filter ? "" : "not "), "ok 2\n");

my($str) = $entity->as_string();
if (!open(OUT, ">output/20md.in")  ||  !(print OUT $str)  ||  !close(OUT)) {
    die "Error while creating input file 'output/20md.in': $!";
}
my $fh = Symbol::gensym();
if (!open($fh, "<output/20md.in")) {
    die "Error while opening input file 'output/20md.in': $!";
}
my($str2) = '';
my($parser) = Mail::IspMailGate->new({'debug' => 1,
				      'tmpDir' => 'output/tmp',
				      'noMails' => \$str2});
print (($parser ? "" : "not "), "ok 3\n");

$parser->Main($fh, 'joe@ispsoft.de', ['joe-dummy@ispsoft.de']);

if ($str eq $str2) {
    print "ok 4\n";
} else {
    print "not ok 4\n";
    if (open(OUT, ">output/20md.out")) {
	print OUT $str2;
	close(OUT);
    }
}
