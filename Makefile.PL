# -*- perl -*-

use strict;
use ExtUtils::MakeMaker;

my %prereq;
sub CheckModule ($;$$) {
    my($module, $version, $package) = @_;
    $package ||= $module;
    $prereq{$module} = $version || 0;
    if ($version) {
        print "Checking for $package, $version or later ... ";
        eval "use $module $version";
        if ($@) {
            print("\nYou don't have installed the $package package,",
                  " version $version or later.\n");
            return 0;
        }
    } else {
        print "Checking for $package ... ";
        eval "use $module";
        if ($@) {
            print("\nYou don't have installed the $package package.\n");
            return 0;
        }
    }
    print "ok\n";
    return 1;
}

my $ok = 1;
$ok &&= CheckModule("MIME::Tools", 4.116);
$ok &&= CheckModule("IO::Tee", 0.61);

if (!$ok) {
    print <<"MESSAGE";

Missing modules are available from any CPAN mirror, for example
        ftp://ftp.funet.fi/pub/languages/perl/CPAN/modules/by-module

MESSAGE
    exit 1;
}

use lib "lib";
require Mail::IspMailGate::Config;


my($unixSock) = $Mail::IspMailGate::Config::UNIXSOCK;


my %opts =
    ('PREFIX' => $Mail::IspMailGate::Config::PREFIX,
     'LIB' => $Mail::IspMailGate::Config::LIBDIR,
     'INSTALLSCRIPT' => $Mail::IspMailGate::Config::SCRIPTDIR,
     'INSTALLBIN' => $Mail::IspMailGate::Config::SCRIPTDIR,
     'INSTALLMAN1DIR' => "$Mail::IspMailGate::Config::MANDIR/man1",
     'INSTALLMAN3DIR' => "$Mail::IspMailGate::Config::MANDIR/man3",
     'NAME' => 'Mail::IspMailGate',
     'EXE_FILES' => ['ispMailGateD'],
     'VERSION_FROM' => 'lib/Mail/IspMailGate/Config.pm',
     'dist'         => { 'SUFFIX'       => ".gz",
			 'DIST_DEFAULT' => 'all tardist',
			 'COMPRESS'     => "gzip -9vf" },
     'DEFINE'       => "-DPATH_UNIXSOCK=\\\"$unixSock\\\"",
     'INC'          => '-I$(PERL_INC)',
     'linkext'      => {'LINKTYPE'     => ''}
     );

if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
    $opts{'ABSTRACT'} = "A general purpose filtering MDA for sendmail";
    $opts{'AUTHOR'} = 'Amar Subramanian (subraman@informatik.uni-tuebingen.de) and Jochen Wiedmann (joe@ispsoft.de)';
    $opts{'PREREQ_PM'} = \%prereq;
}

WriteMakefile(%opts);


package MY;

sub postamble {
    "pm_to_blib: README LICENSE\n\n"
    . "README: ispMailGateD\n"
    . "\tperldoc -t ispMailGateD >README\n\n"
    . "LICENSE: README\n"
    . "\tcat README | perl -e 'while(\$\$line = <STDIN>) { if (\$\$line =~ /^AUTHORS/) { \$\$out=1 } elsif (\$\$line =~ /SEE ALSO/) { \$\$out = 0 } if (\$\$out) { print \$\$line } }' >LICENSE\n\n"
#    . "ispMailGate: ispMailGate.o \$(INST_BIN)/.exists\n"
#    . "\t\$(LD) \$(LDFLAGS) -o ispMailGate ispMailGate.o\n\n"
#    . "\$(INST_BIN)/ispMailGate: ispMailGate\n\n"
#    . "\t\@rm -f \$(INST_BIN)/ispMailGate\n"
#    . "\tcp ispMailGate \$(INST_BIN)/ispMailGate\n\n"
#    . "ispMailGate.o: lib/Mail/IspMailGate/Config.pm\n\n"
	;
}

# sub installbin {
#     my($self) = shift;
#     my($str) = "\n\$(INST_BIN)/.exists :: \$(PERL_INC)/perl.h\n"
# 	. "\t\@\$(MKPATH) \$(INST_BIN)\n"
# 	. "\t\@\$(EQUALIZE_TIMESTAMP) \$(PERL_INC)/perl.h \$(INST_BIN)/.exists\n\n"
# 	. $self->SUPER::installbin();
#     $str =~ s/(all ::.*)/$1 \$(INST_BIN)\/ispMailGate/m;
#     $str;
# }

sub constants {
    my($self) = shift;
    my($str) = $self->SUPER::constants();
    my($scriptDir) = $Mail::IspMailGate::Config::SCRIPTDIR;
    $str =~ s/^(INSTALLBIN *= *).*/$1$scriptDir/m;
    $str =~ s/^(INSTALLSCRIPT *= *).*/$1$scriptDir/m;
    $str;
}


package MY;

sub libscan {
    my($self, $path) = @_;
    ($path =~ /\~$/) ? undef : $path;
}
