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


$| = 1;
print "1..7\n";

if (! -d "output") {
    mkdir "output", 0775;
}
if (! -d "output/tmp") {
    mkdir "output/tmp", 0775;
}
&Sys::Syslog::openlog('13pgp.t', 'pid,cons', 'daemon');
eval { Sys::Syslog::setlogsock('unix'); };

my($parser) = Mail::IspMailGate::Parser->new();
print (($parser ? "" : "not "), "ok 1\n");

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
$entity->add_part($e, -1);
print (($entity ? "" : "not "), "ok 2\n");
	    
my($inFilter) = Mail::IspMailGate::Filter::PGP->new({'direction' => 'pos'});
print (($inFilter ? "" : "not "), "ok 3\n");

my($outFilter) = Mail::IspMailGate::Filter::PGP->new({'direction' => 'neg'});
print (($outFilter ? "" : "not "), "ok 4\n");

my($entity2) = $entity->dup();
my($main) = Mail::IspMailGate->new({'debug' => 1,
                                    'tmpDir' => 'output/tmp'});
$@ = '';
my($result);
eval { $result = $inFilter->doFilter({'entity' => $entity2,
				      'parser' => $parser,
				      'main' => $main});
   };
if ($@ =~ /method \"head\" without a package or object/) {
    print STDERR q{

Your MIME-tools seem to have a minor bug that makes the MIME::Decoder::PGP
module fail. Please apply the patch described in the docs, reinstall the
MIME-modules and reinstall the test. See

    perldoc lib/Mail/IspMailGate/Filter/PGP.pm

for details.

};
}
print (($result ? "not " : ""), "ok 5\n");

my($entity3) = $entity2->dup();
eval { $result = $outFilter->doFilter({'entity' => $entity3,
				       'parser' => $parser,
				       'main' => $main});
   };
if ($@ =~ /method \"head\" without a package or object reference/) {
    print STDERR q{

Your MIME-tools seem to have a minor bug that makes the MIME::Decoder::PGP
module fail. Please apply the patch described in the docs, reinstall the
MIME-modules and reinstall the test. See

    perldoc lib/Mail/IspMailGate/Filter/PGP.pm

for details.

};
    print "not ok 6\n";
} else {
    print (($result ? "not " : ""), "ok 6\n");
}


my($str1) = $entity->as_string();
my($str2) = $entity3->as_string();
if ($str1 eq $str2) {
    print "ok 7\n";
} else {
    print "not ok 7\n";

    if (open(OUT, ">output/13pgp.input")) {
	print OUT $str1;
	close(OUT);
    }
    if (open(OUT, ">output/13pgp.encrypted")) {
	print OUT $entity2->as_string();
	close(OUT);
    }
    if (open(OUT, ">output/13pgp.output")) {
	print OUT $str2;
	close(OUT);
    }
}
