# -*- perl -*-

use strict;
use ExtUtils::MakeMaker;

my($ok) = 1;
print "Checking for MIME tools, version 4.116 or later ... ";
$@ = '';
eval "use MIME::Tools 4.116";
if ($@) {
    $ok = 0;
    print qq{
You don't have installed the MIME-tools module. I cannot continue
installing the IspMailGate program.
};
} else {
    print "ok\n";
}

print "Checking for IO::Tee, version 0.61 or later ... ";
$@ = '';
eval "use IO::Tee 0.61";
if ($@) {
    $ok = 0;
    print qq{
You don't have installed the IO::Tee module. I cannot continue
installing the IspMailGate program.
};
} else {
    print "ok\n";
}

if (!$ok) {
    exit 1;
}

use lib "lib";
require Mail::IspMailGate::Config;


my($unixSock) = $Mail::IspMailGate::Config::UNIXSOCK;

WriteMakefile(
	      'PREFIX' => $Mail::IspMailGate::Config::PREFIX,
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
                                  'COMPRESS'     => "gzip -9f" },
	      'DEFINE'       => "-DPATH_UNIXSOCK=\\\"$unixSock\\\"",
              'INC'          => '-I$(PERL_INC)',
	      'linkext'      => {'LINKTYPE'     => ''}
	      );


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
