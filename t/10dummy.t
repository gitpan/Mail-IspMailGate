# -*- perl
#
# Check the dummy filter: Feed a mail into it; result must be identical
# with input.
#

use strict;

require MIME::Entity;
require Mail::IspMailGate::Parser;
require Mail::IspMailGate::Filter;
require Mail::IspMailGate::Filter::Dummy;

$| = 1;
print "1..5\n";

if (! -d 'output') {
    mkdir 'output', 0775;
}

my($parser) = Mail::IspMailGate::Parser->new({ 'output_dir' => 'output',
					       'output_to_core' => 0
					       });
print (($parser ? "" : "not "), "ok 1\n");

my($e) = MIME::Entity->build('From' => 'amar@ispsoft.de',
			     'To' => 'joe@ispsoft.de',
			     'Subject' => 'Mail-Attachment',
			     'Path' => 'Makefile',
			     'Type' => 'text/plain',
			     'Encoding' => 'quoted-printable');
$e->attach('Path' => 'ispMailGateD',
	   'Type' => 'application/x-perl',
	   'Encoding' => 'base64');
my($entity) = MIME::Entity->build('From' => 'joe@ispsoft.de',
				  'To' => 'amar@ispsoft.de',
				  'Subject' => 'Re: Mail-Attachment',
				  'Path' => 'MANIFEST',
				  'Type' => 'text/plain',
				  'Encoding' => 'quoted-printable');
$entity->add_part($e);
print (($entity ? "" : "not "), "ok 2\n");

my($filter) = Mail::IspMailGate::Filter::Dummy->new({});
print (($filter ? "" : "not "), "ok 3\n");

my($entity2) = $entity->dup();
my($result) = $filter->doFilter({'entity' => $entity2,
				 'parser' => $parser});
print (($result ? "not " : ""), "ok 4\n");

my($str1) = $entity->as_string();
my($str2) = $entity2->as_string();
print ((($str1 eq $str2) ? "" : "not "), "ok 5\n");
