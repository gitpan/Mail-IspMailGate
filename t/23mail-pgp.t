# -*- perl -*-
#
# Check the PGP module
#

use strict;

require MIME::Entity;
require Mail::IspMailGate;
require Mail::IspMailGate::Parser;
require Mail::IspMailGate::Filter;
require Mail::IspMailGate::Filter::PGP;

# Find pgp
my($pgp, $dir);
foreach $dir (split(/:/, $ENV{'PATH'})) {
    if (!defined($pgp)  &&  -x "$dir/pgp") {
	$pgp = "$dir/pgp";
    }
}
if (!defined($pgp)) {
    print "1..0\n";
    exit 0;
}

&Sys::Syslog::openlog('23mail-pgp.t', 'pid,cons', 'daemon');
eval { Sys::Syslog::setlogsock('unix'); };


$Mail::IspMailGate::Config::TMPDIR =
    $Mail::IspMailGate::Config::TMPDIR = "output/tmp";
$Mail::IspMailGate::Config::PGP_UID =   # Make -w happy
    $Mail::IspMailGate::Config::PGP_UID = 'Jochen Wiedmann <joe@ispsoft.de>';
$Mail::IspMailGate::Config::PGP_UIDS =
    $Mail::IspMailGate::Config::PGP_UIDS = {
	'Jochen Wiedmann <joe@ispsoft.de>' => 'blafasel'
};
$Mail::IspMailGate::PGP_ENCRYPT_COMMAND =
    $Mail::IspMailGate::PGP_ENCRYPT_COMMAND = "$pgp -fea \$uid +verbose=0";
$Mail::IspMailGate::PGP_DECRYPT_COMMAND =
    $Mail::IspMailGate::PGP_DECRYPT_COMMAND = "$pgp -f +verbose=0";


print "1..5\n";

if (! -d 'output') {
    mkdir 'output', 0775;
}
if (! -d 'output/tmp') {
    mkdir 'output/tmp', 0775;
}

my($inFilter) = Mail::IspMailGate::Filter::PGP->new({
    'uid'       => 'Jochen Wiedmann <joe@ispsoft.de>',
    'direction' => 'pos'
});
print (($inFilter ? "" : "not "), "ok 1\n");

my($outFilter) = Mail::IspMailGate::Filter::Packer->new({
    'packer'    => 'gzip',
    'direction' => 'neg'
});
print (($outFilter ? "" : "not "), "ok 2\n");

@Mail::IspMailGate::Config::RECIPIENTS =
    @Mail::IspMailGate::Config::RECIPIENTS =
        ( { 'recipient' => 'joe-pgp-in@ispsoft.de',
	    'filters' => [ $inFilter ] },
	  { 'recipient' => 'joe-pgp-out@ispsoft.de',
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
my($fh) = IO::Scalar->new(\$str);
my($str2) = '';
my($parser) = Mail::IspMailGate->new({'debug' => 1,
				      'tmpDir' => 'output/tmp',
				      'noMails' => \$str2});
print (($parser ? "" : "not "), "ok 4\n");

$parser->Main($fh, 'joe@ispsoft.de', ['joe-pgp-in@ispsoft.de']);
undef $fh;
print "ok 5\n";

$fh = IO::Scalar->new(\$str2);
my($str3) = '';
$parser->{'noMails'} = \$str3;
$parser->Main($fh, 'joe@ispsoft.de', ['joe-pgp-out@ispsoft.de']);
undef $fh;
print "ok 6\n";

if ($str eq $str3) {
    print "ok 7\n";
} else {
    print "not ok 7\n";
    if (open(OUT, ">output/23mail-pgp.input")) {
	print OUT $str;
	close(OUT);
    }
    if (open(OUT, ">output/23mail-pgp.packed")) {
	print OUT $str2;
	close(OUT);
    }
    if (open(OUT, ">output/21mail-pgp.output")) {
	print OUT $str3;
	close(OUT);
    }
}
