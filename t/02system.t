# -*- perl -*-

use Mail::IspMailGate::Config;


print "1..2\n";


my $tmpdir = $Mail::IspMailGate::Config::TMPDIR
           = $Mail::IspMailGate::Config::TMPDIR; # -w
if (-d $tmpdir) {
    print "ok 1\n";
} else {
    print STDERR ("The directory for temporary files, $tmpdir, doesn't",
		  " exist.\n");
    print "not ok 1\n";
}

my $filename = "testaaaa";
while (-d "$tmpdir/$filename") {
    ++$filename;
}
if (open(FILE, ">$tmpdir/$filename")) {
    print "ok 2\n";
    close(FILE);
    unlink "$tmpdir/$filename";
} else {
    print STDERR ("Cannot create a file in $tmpdir, check permissions.\n");
    print "not ok 2\n";
}
