# -*- perl -*-
#
# Check the virus scanner.
#

use strict;

require MIME::Entity;
require Mail::IspMailGate;
require Mail::IspMailGate::Parser;
require Mail::IspMailGate::Filter;
require Mail::IspMailGate::Filter::VirScan;

$Mail::IspMailGate::Config::TMPDIR =
    $Mail::IspMailGate::Config::TMPDIR = "output/tmp";
$Mail::IspMailGate::Config::VIRSCAN = 
    $Mail::IspMailGate::Config::VIRSCAN = 't/virscan $ipaths'; # Make -w happy
$Mail::IspMailGate::Config::HASVIRUS =
    $Mail::IspMailGate::Config::HASVIRUS = sub ($) {
    my($str) = @_;
    if(defined($str) && $str ne '') {
        return "Virus has been found: $str";
    } else {
        return '';
    }             
};


# Find tar, gzip or compress
my($gzip, $tar, $compress, $dir, $extension);
foreach $dir (split(/:/, $ENV{'PATH'})) {
    if (!defined($gzip)  &&  -x "$dir/gzip") {
	$gzip = "$dir/gzip";
    }
    if (!defined($tar)  &&  -x "$dir/tar") {
	$tar = "$dir/tar"; }
    if (!defined($compress)  &&  -x "$dir/compress") {
	$compress = "$dir/compress";
    }
}
if (defined($tar)) {
    if (defined($gzip)) {
	$extension = '.gz';
    } elsif (defined($compress)) {
	$extension = '.Z';
	$gzip = $compress;
    }
}


$| = 1;
if (defined($extension)) {
    print "1..8\n";
} else {
    print "1..5\n";
}

@Mail::IspMailGate::Config::DEFLATER =
    @Mail::IspMailGate::Config::DEFLATER = (
    { pattern => '\\.(tgz|tar\\.gz|tar\\.[zZ])$',
      cmd => "$gzip -cd \$ipath | /bin/tar xCf \$odir -"
      }
);

if (! -d "output") {
    mkdir "output", 0775;
}
if (! -d "output/tmp") {
    mkdir "output/tmp", 0775;
}
&Sys::Syslog::openlog('12virscan.t', 'pid,cons', 'daemon');
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
					    
my($filter) = Mail::IspMailGate::Filter::VirScan->new({});

print (($filter ? "" : "not "), "ok 3\n");

my($entity2) = $entity->dup();

my($main) = Mail::IspMailGate->new({'debug' => 1,
                                    'tmpDir' => 'output/tmp'});
my($result) = $filter->doFilter({'entity' => $entity2,
				 'parser' => $parser,
			         'main' => $main});
print (($result ? "not " : ""), "ok 4\n");

my($entity3) = $entity2->dup();
$entity3->attach('Path' => 't/virscan',
		'Type' => 'text/plain',
		'Encoding' => 'base64');
$result = $filter->doFilter({'entity' => $entity3,
			     'parser' => $parser,
			     'main' => $main});
print (($result ? "" : "not "), "ok 5\n");


if (defined($extension)) {
    system "$tar cf output/t.tar t; $gzip -f output/t.tar";
    system "$tar cf output/examples.tar examples;"
	. " $gzip -f output/examples.tar";
    system "$tar cf output/t2.tar examples output/t.tar$extension;"
	. " $gzip -f output/t2.tar";


    $entity3 = $entity2->dup();
    $entity3->attach('Path' => "output/t.tar$extension",
		     'Type' => 'application/x-tar',
		     'Encoding' => 'base64');
    $result = $filter->doFilter({'entity' => $entity3,
				 'parser' => $parser,
				 'main' => $main});
    print (($result ? "" : "not "), "ok 6\n");

    $entity3 = $entity2->dup();
    $entity3->attach('Path' => "output/examples.tar$extension",
		     'Type' => 'application/x-tar',
		     'Encoding' => 'base64');
    $result = $filter->doFilter({'entity' => $entity3,
				 'parser' => $parser,
				 'main' => $main});
    print (($result ? "not " : ""), "ok 7\n");

    $entity3 = $entity2->dup();
    $entity3->attach('Path' => "output/t2.tar$extension",
		     'Type' => 'application/x-tar',
		     'Encoding' => 'base64');
    $result = $filter->doFilter({'entity' => $entity3,
				 'parser' => $parser,
				 'main' => $main});
    print (($result ? "" : "not "), "ok 8\n");
}
