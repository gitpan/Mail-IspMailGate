# -*- perl -*-
#
# Check the packer filter: Feed a mail into it for compression; refeed
# it for decompression; result must be identical with input.
#

use strict;

require MIME::Entity;
require Mail::IspMailGate::Parser;
require Mail::IspMailGate::Filter;
require Mail::IspMailGate::Filter::Packer;

my($gzip, $dir);
foreach $dir (split(/:/, $ENV{'PATH'})) {
    if (!defined($gzip)  &&  -x "$dir/gzip") {
	$gzip = "$dir/gzip";
    }
}
if (!defined($gzip)) {
    print "1..0\n";
}

%Mail::IspMailGate::Config::PACKER =
    %Mail::IspMailGate::Config::PACKER =
        ( 'gzip' => { 'pos' => "$gzip -c",
		      'neg' => "$gzip -cd" } );

$| = 1;
print "1..7\n";

if (! -d "output") {
    mkdir "output", 0775;
}

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

my($inFilter) = Mail::IspMailGate::Filter::Packer->new({
    'packer'    => 'gzip',
    'direction' => 'pos'
});
print (($inFilter ? "" : "not "), "ok 3\n");

my($outFilter) = Mail::IspMailGate::Filter::Packer->new({
    'packer'    => 'gzip',
    'direction' => 'neg'
});
print (($outFilter ? "" : "not "), "ok 4\n");

my($entity2) = $entity->dup();
my($result) = $inFilter->doFilter({'entity' => $entity2,
				   'parser' => $parser});
print (($result ? "not " : ""), "ok 5\n");

my($entity3) = $entity2->dup();
$result = $outFilter->doFilter({'entity' => $entity3,
				'parser' => $parser});
print (($result ? "not " : ""), "ok 6\n");

my($str1) = $entity->as_string();
my($str2) = $entity3->as_string();
if ($str1 eq $str2) {
    print "ok 7\n";
} else {
    print "not ok 7\n";
    if (open(OUT, ">output/11packer.input")) {
	print OUT $str1;
	close(OUT);
    }
    if (open(OUT, ">output/11packer.packed")) {
	print OUT $entity2->as_string();
	close(OUT);
    }
    if (open(OUT, ">output/11packer.output")) {
	print OUT $str2;
	close(OUT);
    }
}

