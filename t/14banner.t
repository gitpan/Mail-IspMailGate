# -*- perl -*-
#
# Check the banner filter.
#

use strict;

require MIME::Entity;
require Mail::IspMailGate::Parser;
require Mail::IspMailGate::Filter;
require Mail::IspMailGate::Filter::Banner;
require IO::Scalar;
require File::Copy;


$| = 1;
print "1..5\n";

if (! -d 'output') {
    mkdir 'output', 0775;
}
File::Copy::copy("MANIFEST", "output/MANIFEST");


my($parser) = Mail::IspMailGate::Parser->new('output_dir' => 'output',
					     'output_to_core' => 0);
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
$entity->attach('Path' => 'output/MANIFEST',
		'Type' => 'text/plain',
		'Encoding' => 'quoted-printable');

$entity->add_part($e);
print (($entity ? "" : "not "), "ok 2\n");

my $plain_banner = 'Hello, this is the banner!';
my($filter) = Mail::IspMailGate::Filter::Banner->new({
    'plain' => IO::Scalar->new(\"$plain_banner"),
    'html' => IO::Scalar->new(\'<H1>Hello, this is the banner!</H1>')
});
print (($filter ? "" : "not "), "ok 3\n");


my($str1) = $entity->as_string();
my($entity2) = $entity->dup();
my($result) = $filter->doFilter({'entity' => $entity2,
				 'parser' => $parser});
print (($result ? "not " : ""), "ok 4\n");

my($str2) = $entity2->as_string();
if ($str2 =~ /\s*\Q$plain_banner\E\s*/s) {
    print "ok 5\n";
} else {
    print "not ok 5\n";
}

