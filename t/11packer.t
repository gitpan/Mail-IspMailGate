# -*- perl -*-
#
# Check the packer filter: Feed a mail into it for compression; refeed
# it for decompression; result must be identical with input.
#

use strict;

use Mail::IspMailGate::Test;
require Mail::IspMailGate::Filter::Packer;


my $gzip = MiSearch("gzip");
if (!$gzip) { print "1..0\n"; exit 0 };


$| = 1;
print "1..7\n";

%Mail::IspMailGate::Config::PACKER =
    %Mail::IspMailGate::Config::PACKER =
        ( 'gzip' => { 'pos' => "$gzip -c",
		      'neg' => "$gzip -cd" } );


my($parser) = MiParser();

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
MiTest($entity, undef, "Building the entity\n");

my($inFilter) = Mail::IspMailGate::Filter::Packer->new({
    'packer'    => 'gzip',
    'direction' => 'pos'
});
MiTest($inFilter, undef, "Creating the filter\n");

my($outFilter) = Mail::IspMailGate::Filter::Packer->new({
    'packer'    => 'gzip',
    'direction' => 'neg'
});
MiTest($outFilter, undef, "Creating the reverse filter\n");

my($result, $entity2) = MiParse($parser, $inFilter, $entity,
				"11p.in", "11p.tmp");
MiTest(!$result);

my($result2, $entity3) = MiParse($parser, $outFilter, $entity,
				 undef, "11p.out");
MiTest(!$result2);
MiTest($entity->as_string() eq $entity3->as_string());

