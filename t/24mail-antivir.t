# -*- perl -*-
#
# Check the virus scanner.
#

use strict;

# Find antivir
my $antivir;
{
    my $dir;
    foreach $dir (split(/:/, $ENV{'PATH'})) {
	if (!defined($antivir)  &&  -x "$dir/antivir") {
	    $antivir = "$dir/antivir";
	}
    }
    if (!defined($antivir)) {
	print "1..0\n";
	exit 0;
    }
}


require Symbol;
require MIME::Entity;
require Mail::IspMailGate;
require Mail::IspMailGate::Filter;
require Mail::IspMailGate::Filter::VirScan;

my $numFiles = 0;

sub VScan ($$$) {
    my($entity, $expect, $num) = @_;
    my($input) = $entity->as_string();
    my $fh = Symbol::gensym();
    ++$numFiles;
    my $fname = "output/24ma$numFiles.in";
    if (!open($fh, ">$fname")  ||  !(print $fh $input)  ||  !close($fh)) {
	die "Error while creating input file $fname: $!";
    }
    if (!open($fh, "<$fname")) {
        die "Error while opening input file $fname: $!";
    }
    my($output) = '';
    if (! -d "output/tmp") {
	mkdir "output/tmp", 0775;
    }
    my($parser) = Mail::IspMailGate->new({'debug' => 1,
					  'tmpDir' => 'output/tmp',
					  'noMails' => \$output});
    $parser->Main($fh, 'joe@ispsoft.de', ['joe-virscan@ispsoft.de']);
    if ($output =~ /\!Virus\!/) {
	print (($expect ? "" : "not "), "ok $num\n");
    } else {
	print (($expect ? "not " : ""), "ok $num\n");
    }
    if (open($fh, ">output/24ma$numFiles.out")) {
        print $fh $output;
    }
}


&Sys::Syslog::openlog('24mail-antivir.t', 'pid,cons', 'daemon');
eval { Sys::Syslog::setlogsock('unix'); };


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
if (!defined($extension)) {
    print "1..4\n";
} else {
    print "1..7\n";
}



if (! -d "output") {
    mkdir "output", 0775;
}


$Mail::IspMailGate::Config::TMPDIR =
    $Mail::IspMailGate::Config::TMPDIR = "output/tmp"; # -w
$Mail::IspMailGate::Config::VIRSCAN = 
    $Mail::IspMailGate::Config::VIRSCAN = $antivir . ' -rs $ipaths';
$Mail::IspMailGate::Config::HASVIRUS =
    $Mail::IspMailGate::Config::HASVIRUS = sub ($) {
    my($str) = @_;
    my $result = join('\n', grep { $_ =~ /\!Virus\!/ } split(/\n/, $str));
    $result ? "$result\n" : '';
};

if (defined($extension)) {
    @Mail::IspMailGate::Config::DEFLATER =
	@Mail::IspMailGate::Config::DEFLATER = (
	    { pattern => '\\.(tgz|tar\\.gz|tar\\.[zZ])$',
              cmd => "$gzip -cd \$ipath | /bin/tar xCf \$odir -"
            }
        );
}
my($filter) = Mail::IspMailGate::Filter::VirScan->new({});
@Mail::IspMailGate::Config::RECIPIENTS =
    @Mail::IspMailGate::Config::RECIPIENTS =
        ( { 'recipient' => 'joe-virscan@ispsoft.de',
	    'filters' => [ $filter ] }
	);
print (($filter ? "" : "not "), "ok 1\n");


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
print (($entity ? "" : "not "), "ok 2\n");
VScan($entity, 0, 3);

my($entity2) = $entity->dup();
$entity2->attach('Path' => 't/eicar.com',
		 'Type' => 'application/x-dos-binary',
		 'Encoding' => 'base64');
VScan($entity2, 1, 4);


if (defined($extension)) {
    system "$tar cf output/t.tar t; $gzip -f output/t.tar";
    system "$tar cf output/examples.tar examples;"
	. " $gzip -f output/examples.tar";
    system "$tar cf output/t2.tar examples output/t.tar$extension;"
	. " $gzip -f output/t2.tar";


    $entity2 = $entity->dup();
    $entity2->attach('Path' => "output/t.tar$extension",
		     'Type' => 'application/x-tar',
		     'Encoding' => 'base64');
    VScan($entity2, 1, 5);

    $entity2 = $entity->dup();
    $entity2->attach('Path' => "output/examples.tar$extension",
		     'Type' => 'application/x-tar',
		     'Encoding' => 'base64');
    VScan($entity2, 0, 6);

    $entity2 = $entity->dup();
    $entity2->attach('Path' => "output/t2.tar$extension",
		     'Type' => 'application/x-tar',
		     'Encoding' => 'base64');
    VScan($entity2, 1, 7);
}
