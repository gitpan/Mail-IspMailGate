#!/usr/bin/perl

my($script) = <<'SCRIPT';
~STARTPERL~
#
#    ispMailGate - delivery agent for filtering and scanning E-Mail
#
#
#    This program is designed for being included into a sendmail
#    configuration as a delivery agent. Mail is filtered by the
#    agent and fed into sendmail again for continued processing.
#
#    Currently available filters include
#
#        - a virus scanner (requires apropriate external binary)
#        - PGP en-/decryption
#        - compressing and decompressing with gzip or other external
#          binaries
#
#
#    Authors:    Amar Subramanian
#                Grundstr. 32
#                72810 Gomaringen
#                Germany
#
#                Email: amar@neckar-alb.de
#                Phone: +49 7072 920696
#
#         and    Jochen Wiedmann
#                Am Eisteich 9
#                72555 Metzingen
#                Germany
#
#                Email: joe@ispsoft.de
#                Phone: +49 7123 14887
#
#
#    Version history: 04-Apr-1998	Initial version
#                                       (Amar and Jochen)
#
############################################################################


require 5.004;
use strict;

use constant LIBDIR => "~LIBDIR~";

use lib LIBDIR;
require Sys::Syslog;
require Mail::IspMailGate;


delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};
$ENV{'PATH'} = '/bin:/usr/bin';

my($debugging) = 1;
my(@args) = @ARGV;


sub ErrExit ($) {
    my($str) = shift;
    Sys::Syslog::syslog('err', $str);
    print STDERR $str;
    exit 1;
}


############################################################################
#
#    Name:    Usage
#
#    Purpose: Print usage message
#
#    Inputs:  None
#
#    Result:  Nothing, exits with error status
#
############################################################################

sub Usage () {
    my($tmpDir) = $Mail::IspMailGate::Config::TMPDIR
	= $Mail::IspMailGate::Config::TMPDIR;
    my($pidFile) = $Mail::IspMailGate::Config::PIDFILE;
    my($facility) = $Mail::IspMailGate::Config::FACILITY;
    my($unixSock) = $Mail::IspMailGate::Config::UNIXSOCK;

    print << "EOF";
Usage:
  $0 [options] -s|-server|--server
  $0 [options] -f sender recipient1 [... recipientN]

Possible options are:
  -d | -debug | --debug            Run in debugging mode
  -n | -nomails | --nomails        Do not send mails, but print them to
                                   stdout. This is mainly usefull for
				   debugging purposes.
  -s | -server | --server          Run as a server; default is reading and
                                   processing  a single mail from stdin.
  -t | -tmpdir | --tmpdir          Set directory for temporary files;
                                   defaults to $tmpDir.

Server-mode options are:
  -a | -facility | --facility      Set syslog facility; defaults to
                                   $facility.
  -p | -pidfile | --pidfile        Set path of PID file; defaults to
                                   $pidFile.
  -u | -unixsock | --unixsock      Set path of Unix socket; defaults to
                                   $unixSock.
       -nofork | --nofork          Suppress forking (usefull for debugging
				   only)
EOF

    exit(1);
}


############################################################################
#
#    Name:    ReadClientArray
#
#    Purpose: Read an array of strings from the client
#
#    Inputs:  $sock - Socket to read from
#
#    Returns: Array read by the client; aborts in case of trouble
#
############################################################################

sub ReadClientArray ($) {
    my($sock) = @_;
    my($argSize);
    if (read($sock, $argSize, 32)  &&  $argSize =~ /^(\d+)/) {
	$argSize = $1;
    } else {
	ErrExit("Error while reading array size from client: $!");
    }
    my($argString) = '';
    while (length($argString) < $argSize) {
	my($result) = read($sock, $argString, $argSize - length($argString),
			   length($argString));
	if (!$result) {
	    ErrExit("Error while reading array data: $!");
	}
    }

    # Remove a trailing \0\n from $argString
    $argString =~ s/\0?\n$//s;
    split(/\0/, $argString);
}


############################################################################
#
#    This is main().
#
############################################################################

sub catchChilds {
    my $pid = wait;
    $SIG{CHLD} = \&catchChilds;
}

sub Main ($$$$) {
    my($fh, $from, $recipients, $attr) = @_;
    my($parser) = Mail::IspMailGate->new($attr);
    $parser->Main($fh, $from, $recipients);
}

{
    #
    #   Process command line arguments
    #
    my ($arg, $daemon, @recipients);
    my($unixSock) = $Mail::IspMailGate::Config::UNIXSOCK;
    my($facility) = $Mail::IspMailGate::Config::FACILITY;
    my($pidFile) = $Mail::IspMailGate::Config::PIDFILE;
    my($tmpDir);
    my($from, $noMails, $noFork);
    my @args = @ARGV;

    while ($arg = shift @ARGV) {
	if ($arg eq '-s'  ||  $arg eq '-server'  ||  $arg eq '--server') {
	    $daemon = 1;
	} elsif ($arg eq '-u'  ||  $arg eq '-unixsock'
		 ||  $arg eq '--unixsock') {
	    if (!defined($unixSock = shift @ARGV)) {
		print "Option --unixsock without argument.\n";
		Usage();
	    }
	} elsif ($arg eq '-a'  ||  $arg eq '-facility'
		 ||  $arg eq '--facility') {
	    if (!defined($facility = shift @ARGV)) {
		print "Option --facility without argument.\n";
		Usage();
	    }
	} elsif ($arg eq '-n'  ||  $arg eq '-nomails'
		 ||  $arg eq '--nomails') {
	    $noMails = 1;
	} elsif ($arg eq '-nofork'  ||  $arg eq '--nofork') {
	    $noFork = 1;
	} elsif ($arg eq '-p'  ||  $arg eq '-pidfile'
		 ||  $arg eq '--pidfile') {
	    if (!defined($pidFile = shift @ARGV)) {
		print "Option --pidfile without argument.\n";
		Usage();
	    }
	} elsif ($arg eq '-p'  ||  $arg eq '-tmpdir'
		 ||  $arg eq '--tmpdir') {
	    if (!defined($tmpDir = shift @ARGV)) {
		print "Option --tmpdir without argument.\n";
		Usage();
	    }
	} elsif ($arg eq '-f'  ||  $arg eq '-from'  ||  $arg eq '--from') {
	    if (!defined($from = shift @ARGV)) {
		print "Option --from without argument.\n";
		Usage();
	    }
	} elsif ($arg eq '-d'  ||  $arg eq '-debug'  ||  $arg eq '--debug') {
	    $debugging = 1;
	} else {
	    push(@recipients, $arg);
	}
    }

    if ($daemon && (@recipients || $from)) {
	print("Option --server is not compatible with --from or recipient",
	      " lists.\n");
	Usage();
    }
    if (!$daemon  &&  !@recipients) {
	print("Missing recipients.\n");
	Usage();
    }

    my($uid) = $Mail::IspMailGate::Config::USER;
    if ($uid !~ /^\-?\d+$/  &&
	!defined($uid = ((getpwnam($uid))[2]))) {
	ErrExit("Unknown user: " . $Mail::IspMailGate::Config::USER);
    }
    my($gid) = $Mail::IspMailGate::Config::GROUP;
    if ($gid !~ /^\-?\d+$/  &&
	!defined($gid = ((getgrnam($gid))[2]))) {
	ErrExit("Unknown group: " . $Mail::IspMailGate::Config::GROUP);
    }

    if (defined(&Sys::Syslog::setlogsock)) {
	# This fails on some Solaris systems ...
        #eval { Sys::Syslog::setlogsock('unix'); };
        Sys::Syslog::setlogsock('unix');
    }
    &Sys::Syslog::openlog('ispMailGateD', 'pid,cons', $facility);

    my($attr) = {
	'debug' => $debugging
	};
    if ($noMails) {
	$attr->{'noMails'} = 1;
    }
    if ($tmpDir) {
	$attr->{'tmpDir'} = $tmpDir;
    }

    if (!$daemon) {
	$) = $gid;
	$( = $gid;
	$> = $uid;
	$< = $uid;
	if ($debugging) {
	    Sys::Syslog::syslog('debug', "Command line arguments: " . join(" ", @args));
	}
	Main(\*STDIN, $from, \@recipients, $attr);
	exit(0);
    }

    #
    #   This is the servers main part
    #
    Sys::Syslog::syslog('notice', "ispMailGateD starting");
    if (!socket(SERVER, &Socket::AF_UNIX(), &Socket::SOCK_STREAM(), 0)) {
	ErrExit("Cannot create socket: $!");
    }
    unlink $unixSock;
    if (!bind(SERVER, &Socket::sockaddr_un($unixSock))) {
	ErrExit("Cannot bind: $!");
    }
    if (!listen(SERVER, &Socket::SOMAXCONN)) {
	ErrExit("Cannot listen: $!");
    }
    if (!chown $uid, $gid, $unixSock) {
	ErrExit("Cannot change ownership of $unixSock: $!");
    }
    if (!chmod 0660, $unixSock) {
	ErrExit("Cannot change mode of $unixSock: $!");
    }

    if (!$noFork) {
	$SIG{CHLD} = \&catchChilds;

	my $pid;
	if (!defined($pid = fork())) {
	    ErrExit("Cannot fork(): $!");
	}
	if ($pid) {
	    exit 0;
	}

	if (open(PID, ">$pidFile")) {
	    print PID "$$";
	    close(PID);
	}

	open(STDOUT, ">/dev/null");
	open(STDERR, ">&STDOUT");
	open(STDIN, "</dev/null");
    }

    $) = $gid;
    $( = $gid;
    $> = $uid;
    $< = $uid;

    if ($debugging) {
	&Sys::Syslog::syslog('debug',
			     'Waiting for connections at %s', $unixSock);
    }
    while (accept(CLIENT, SERVER)) {
	if ($debugging) {
	    &Sys::Syslog::syslog('debug', 'Server accepting child');
	}

	#
	#  Fork a child
	#
	if (!$noFork) {
	    my $pid;
	    if (!defined($pid = fork())) {
		Sys::Syslog::syslog('err', "Cannot fork: $!");
		print STDERR "Cannot fork: $!";
		next;
	    } elsif ($pid) {
		#
		#  This is the parent
		#
		close(CLIENT);
		next;
	    }
	}

	#
	#  This is the child, read the environment array
	#
	my($path) = $ENV{'PATH'};
	%ENV = ();
	my($arg);
	foreach $arg (ReadClientArray(\*CLIENT)) {
	    if ($arg =~ /(.*?)=(.*)/) {
		$ENV{$1} = $2;
	    }
	}
	delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};
	$ENV{'PATH'} = $path;

	# Read the argument array
	my($from, $getFrom);
	my($recipients) = [];
	foreach $arg (ReadClientArray(\*CLIENT)) {
	    if ($getFrom) {
		$from = $arg;
		undef $getFrom;
	    } else {
		if ($arg eq '-f') {
		    $getFrom = 1;
		} else {
		    push(@$recipients, $arg);
		}
	    }
	}
	if (!@$recipients) {
	    ErrExit('Missing recipients');
	}
	if (!$from) {
	    ErrExit('Missing sender');
	}

	Main(\*CLIENT, $from, $recipients, $attr);
	exit(0);
    }

    ErrExit("No connection: $!");
}
__END__


=head1 NAME

ispMailGate - a general purpose filtering MDA for sendmail


=head1 WARNING! WARNING! WARNING!

This is an alpha release! What you are using now is tested by using a
comparatively small test suite in our local environment. You are perhaps
planning to include this software in a production environment. We don't
discourage to do so, but we strongly advise you to be extremely carefull.
In particular, start by filtering only mails for a very small number of email
adresses, perhaps your own and something similar. That is, be extremely
cautios when modifying your sendmail configuration.

See INSTALLATION and SENDMAIL CONFIGURATION below for a detailed description
of your sendmail setup.


=head1 SYNOPSIS

For running standalone:

    ispMailGateD -f <sender> <recipient1> [... <recipientN>]

For running as a daemon (not yet possible, as the wrapper is still
missing):

    ispMailGateD -s [-d] [-t <tmpdir>] [-a <facility>] [-p <pidfile>]
        [-u <unixsock>]

=head1 DESCRIPTION

IspMailGate is a general purpose email filtering system. The program gets
included into a sendmail configuration as a delivery agent (MDA) and the
usual sendmail rules can be applied for deciding which emails to feed into
ispMailGate. The true filters are implemented as modules, so its easy to
extend the possibilities of ispMailGate. Current modules offer automatic
compression and decompression, encryption, decryption and certification
with PGP or virus scanning.

The program can run in a usual standalone mode, but that's not recommended,
except for debugging and similar tasks. The recommended mode will be
running the program as a server, completely independent from sendmail.
A small C program (called a wrapper) will instead be configured as
sendmails MDA. This wrapper connects to the server via a well known Unix
socket (by default ~UNIX_SOCK~), passes its command line arguments and
standard input to the server and disconnects. Obviously this second
solution has much better performance as you load the Perl interpreter
only once.

Unfortunately the wrapper is not yet available, due to some problems with
Perl's I/O. (Perl won't notice EOF on the socket as long as the client
doesn't close the connection. On the other hand the client has to hold
the connection open for receiving error messages which will be written
to stderr so that sendmail recognizes them. We are thankfull for any
suggestion to solve this.


=head2 Command Line Interface

The following options affect ispMailGate's behaviour:

=over 4

=item -a <fac>, -facilty <fac>, --facility <fac>

Advices the ispMailGate to use syslog facility <fac>. By default syslog
entries are written as facility ~FACILITY~. 

=item -d, -debug, --debug

The program runs in debugging mode, logging information into the syslog.
Perhaps more information than you like ... :-)

=item -f <sender>, -from <sender>, --from <sender>

Sets a mails sender.

=item -s, -server, --server

Tells the program not to run in standalone mode and instead detach from
the shell to enter server mode. This mode is currently not usable, as
the wrapper is not yet available.

=item -t <dir>, -tmpdir <dir>, --tmpdir <dir>

Sets the programs directory for temporary files to <dir>. When unpacking
a complex and big multipart mail, the ispMailGate may need surprisingly
much space. By default ~TMPDIR~ is used.

=item -u <sock>, -unixsock <sock>, --unixsocket <sock>

Tells the server to listen on file <sock> for unix socket connections.
By default the server uses ~UNIXSOCK~.

=back


=head1 INSTALLATION

=head2 Requirements

To start with the requirements: You need

1.) A running sendmail (recommended: 8.8.5 or later); if you don't have
sendmail or an older version, you find the current release at

    ftp://ftp.sendmail.org/pub/sendmail

2.) A late version of Perl (recommended: 5.004 or later); if you don't
have Perl, shoot yourself in the foot (;-) or get it from any CPAN
mirror, for example

    ftp://ftp.funet.fi/pub/languages/perl/CPAN/src/5.0

3.) The MIME-tools module (version 4.116 or later), its prerequired
modules (MailTools, MIME-Base64 and IO-Stringy) and the IO::Tee
module (version 0.61 or later). All these modules are available from
any CPAN mirror, for example

    ftp://ftp.funet.fi/pub/languages/perl/CPAN/modules/Mail
    ftp://ftp.funet.fi/pub/languages/perl/CPAN/modules/MIME
    ftp://ftp.funet.fi/pub/languages/perl/CPAN/modules/IO

Installing a Perl module is quite easy, btw. Either you use the
automatic CPAN interface (requires an Internet connection or
something similar) by executing

    perl -MCPAN -e shell

or you fetch the modules with FTP, extract the tar.gz files, go into
the distribution directory (for example MIME-tools-4.116) and do a

    perl Makefile.PL
    make
    make test
    make install

You'll like it! :-)

=head2 System preparation

Although ispMailGate is usually started as root, because certain
initialization setting need root permissions, it must not continue
running as root. Instead it impersonates itself to a user ID that
you select. I recommend creating a separate user C<ispmailgate> and
a separate group C<ispmailgate>.

IspMailGate needs its own directory for creating temporary files.
Usually this could be C</var/spool/IspMailGate> or something
similar. Make sure that the ispmailgate user (but noone else) has
access to this directory:

    mkdir /var/spool/IspMailGate
    chown ispmailgate /var/spool/IspMailGate
    chgrp ispmailgate /var/spool/IspMailGate
    chmod 700 /var/spool/IspMailGate

=head2 Program installation

The program is installable like any other Perl module. However, you cannot
use the automatic CPAN installation in that case. Instead, fetch the
current archive from any CPAN mirror, for example

    ftp://ftp.funet.fi/pub/languages/perl/CPAN/authors/id/JWIED

extract the archive with

    gzip -cd Mail-IspMailGate-<version>.tar.gz | tar xf -

After that, do a

    cd Mail-IspMailGate-<version>

and start with editing the Configuration module

    lib/Mail/IspMailGate/Config.pm

In particular you might like to modify the installation directories.
For example, to install into /usr/local/IspMailGate/sbin,
/usr/local/IspMailGate/lib and so on, you'd change the variable

    $PREFIX = "/usr/local/IspMailGate";

For a detailed description of the configuration file see
L<CONFIGURATION FILE> below. Once this is done, install the program
with

    perl -Ilib Makefile.PL
    make
    make test
    make install

Finally make sure that the ispMailGate binary can connect to the server.
Assuming that you have installed in /usr/local/IspMailGate and that your
sendmail is running as group C<mail>, do the following:

    chown ispmailgate /usr/local/IspMailGate/sbin/ispMailGate
    chgrp mail /usr/local/IspMailGate/sbin/ispMailGate
    chmod 4750 /usr/local/IspMailGate/sbin/ispMailGate

=head1 SENDMAIL CONFIGURATION

Before modifying your sendmail configuration, think about the following:
The crucial problem of using IspMailGate without damage is that you
are working in a number of different steps. For example:

=over 4

=item second sendmail.cf

In the first step you leave your /etc/sendmail.cf completely untouched.
Instead you create a second file /etc/sendmail.cf.new, create files
containing email messages (for example by saving them from your
preferred email client) and then feed them into sendmail by using the
following command:

    cat mymail | sendmail -v -i -f<sender> <recipient>

=item single user action

If the first step seems to look good, you can go on modifying your
true sendmail.cf. But don't let all mails be filtered! Instead let
sendmail filter only mails for or from some selected people, that are
aware of potential problems, for example your own mail. (You know of
things that might happen, don't you? :-)

Stay in this stage for at least a week or two. Contact different kind
of people using all sort of email clients, send them mails and advise
them to reply with all possible kinds of emails: Simple text documents,
multipart messages, word documents (interesting thing if you verify
the virus scanner ... ;-)

=item Final stage

Finally if all seems to be working well, you can enter the final stage
and do the things you really want.

=back

=head2 Selecting the mails to feed into sendmail

The main problem with sendmail is that ruleset 0 (the set of rules deciding
about how to handle an email) decides by looking at the recipient only.
(At least I don't know of other possibilities, perhaps someone can tell?)
IspMailGate is smarter and can make decisions based on both sender and
recipients. However, it cannot decide on mails that don't reach it,
thus you probably must feed mails into IspMailGate that aren't really
interesting for it. For example, if you have an IspMailGate rule concerning
mails sent from joe@ispsoft.de to *@perl.com then you must feed all
mails into IspMailGate that have *@perl.com as recipient, regardless
of the sender. IspMailGate fixes this problem by just ignoring such mails
and just feeding them back into sendmail. However, a performance problem
is still remaining.

Another problem is, that IspMailGate rules are based on Perl regular
expressions. Of course they have a much finer granularity than sendmail
rules have, but that may rarely be a problem in practice.

To sum it up: Sendmail must be configured to feed any mail into
IspMailGate that has a recipient which *might* receive a mail that ought
to be filtered via IspMailGate. In the extreme case this can mean that
sendmail must feed all email traffic into IspMailGate before really
delivering it.

Now for the real stuff. In what follows I assume some knowledge of
sendmail configuration. In particular you should be able to configure
sendmail based on m4 macros, a detailed explanation of this process
is contained in the file cf/README of the sendmail sources. Additionally
you should know the concept of sendmail classes and how to work with
them.

We start with creating a file that holds a new sendmail class,
called IMGR. The file might look as follows:

    # perlbug@perl.org is a possible IspMailGate recipient.
    perlbug@perl.org    :ispmailgate
    # Any mail going to *@ispsoft.de will be feed into IspMailGate
    @ispsoft.de         :ispmailgate
    # And finally *@*.uni-tuebingen.de
    .uni-tuebingen.de   :ispmailgate

In what follows I assume that this file is stored as
/etc/ispMailGateRecipients. Now we add the following section to
sendmail.mc:

    define(`ISPMAILGATE_MAILER_PATH', `/usr/local/bin/ispMailGateD')
    define(`ISPMAILGATE_MAILER_FLAGS', `fgmDFMu')
    define(`ISPMAILGATE_MAILER_ARGS', `ispMailGateD $f $u')

    MAILER_DEFINITIONS
    ##################################################
    ###   IspMailGate Mailer specification         ###
    ##################################################

    Mispmailgate, P=ISPMAILGATE_MAILER_PATH, F=ISPMAILGATE_MAILER_FLAGS,
	S=11/31, R=21/31, T=DNS/RFC822/X-Unix, A=ISPMAILGATE_MAILER_ARGS

    LOCAL_CONFIG
    KIMGR hash -o /etc/mail/ispMailGateRecipients
    CPISPMAILGATE

    LOCAL_RULE_0
    # Make "user < @ host >" to "<user @ host > user < @ host . >"
    R$* < @ $+ > $*			$: < $1 @ $2 > $1 < @ $2 > $3
    # At this point we might have "< user @ host . > user < @ host . >"
    # Remove the dot from the host part, if any.
    R< $+ . > $* < $+ > $*		$: < $1 > $2 < $3 > $4

    # Is "user@host" in /etc/mail/ispMailGateRecipients?
    R< $* @ $+ > $* < $+ > $*
		$: < $1 @ $2 $(IMGR $1 @ $2 $: $) > $3 < $4 > $5
    # Is "@host" in /etc/mail/ispMailGateRecipients?
    R< $* @ $+ > $* < $+ > $*
		$: < $1 @ $2 $(IMGR @ $2 $: $) > $3 < $4 > $5
    # Is "host" = "@any.domain" with "domain" in
    # /etc/mail/ispMailGateRecipients?
    R< $* @ $+ . $+ > $* < $+ > $*
		$: < $1 @ $2 . $3 $(IMGR . $3 $: $) > $4 < $5 > $6
    # Did any of the last three rules match? If so, call IspMailGate
    R< $* @ $+ : ispmailgate > $* < $+ > $*
		$# ispmailgate $@ $2 $: $1 < @ $2 >

    # Remove the preceding < user @ host >
    R< $* @ $+ > $* < $+ > $*	$: $3 < $4 > $5
    # Remove a .ISPMAILGATE, if present; call ruleset 3 for
    # canonicalization
    R$* < @ $+ .ISPMAILGATE. > $*	$: $>3 $1 @ $2


If you do not know too much about sendmail.cf, you should at least note
the following: In the above example we have typically three kinds of lines:
Lines beginning with a '#' are comments. The LOCAL_CONFIG and LOCAL_RULE_0
lines are m4 macros, the rest are so-called sendmail rules. These consist
of a left hand and a right hand side (LHS and RHS), separated by tabs.
If the lines become too long, you may use continutation lines, starting
with a blank or tab. In the above example there are three rules using
line continuation: The LHS is on the first line, the RHS (introduced with
two tabs) is on the second line.

But what does the above example mean? For understanding that, you have two
know that sendmail starts with bringing the recipient address into a
canonical form, looking like

    user<@host> other information

The host part might have a trailing dot, so the above may indeed be

    user<@host.> other information

So the first lines modify the above to

    <user@host>user<@host> other information

or

    <user@host>user<@host.> other information

The idea is that we work with the first part and may fall back to the
original information by just dropping the part <user@host>.

The three rules using the IMGR map verify whether "user@host" has a match
in the recipient list of IspMailGate. If so, the RHS of the map in
/etc/mail/ispMailGateRecipients is added and we receive

    <user@host:ispmailgate>user<@host.> other information

which will be sent to the ispmailgate mailer. Finally the first part is
removed. But what does the last rule do?

When a mail is sent to IspMailGate, it may do something with the mail,
but finally it is passed back to sendmail for true delivery. To avoid
loops, we have to tell sendmail that the mail must not be processed by
IspMailGate a second time. To achieve that we modify the recipient from
user@host to user@host.ispmailgate. That guarantees, that the maps in
/etc/mail/ispMailGateRecipients don't match thus we are guaranteed that
the last rule of the above example will be applied finally. All it does
is removing this .ispmailgate, if any. (Sometimes I agree, that
sendmail configuration is a tedious thing ...)

=head1 CONFIGURATION FILE

The program depends on a local configuration file, read as the
Mail::IspMailGate::Config module. In other words, this configuration file
is pure Perl code defining certain variables under the name space
Mail::IspMailGate::Config. The module is read from the file
~LIBDIR~/Mail/IspMailGate/Config.pm.

The following variables are meaningfull to the program:

=over 4

=item $VERSION

The programs version; do not modify without a good reason.

=item $PREFIX

The installation prefix; typically the program files are stored in the
directories $PREFIX/sbin, $PREFIX/lib, $PREFIX/man and so on. (Modifiable,
see below.) The current prefix is ~PREFIX~.

=item $LIBDIR

The directory where the program's own perl modules are stored, currently
~LIBDIR~.

=item $SCRIPTDIR

A directory for storing the executable Perl files, currently ~SCRIPTDIR~.

=item $MANDIR

The program's man pages are stored here, currently ~MANDIR~.

=item $TMPDIR

Set's the default directory for creating temporary files, currently
~TMPDIR~. You can modify this with the C<--tmpdir> directive, see
above.

=item $UNIXSOCK

The unix socket that the client connects to, currently ~UNIXSOCK~.
You can use the C<--unixsock> argument for overwriting the default.

=item $PIDFILE

The PID file where a running server stores its PID, currently ~PIDFILE~.
You can use the C<--pidfile> argument for overwriting the default.

=item $USER

=item $GROUP

IspMailGate is running as this user and group, ~USER~ and ~GROUP~.

=item $MAILHOST

The host to use for passing mails after processing them by the
mail filter. By default 'localhost' is used, in other words, the
mails are immediately passed back to sendmail.

To omit a possible loop problem, sendmail must be ready for handling
email addresses like user@domain.ispmailgate. For such addresses it
must rip off the .ispmailgate and guarantee not to feed the mails
back into ispMailGate. See L<SENDMAIL CONFIGURATION> below.

=item @RECIPIENTS

A list of possible recipients/senders and filter lists that describe
how to handle mails being sent from the senders to the recipients.

Each element of the list is a hash ref with the following elements:

=over 4

=item recipient

A regular expression (Perl regular expression, that is) for matching
the recipient address. An empty string matches any recipient.

=item sender

A regular expression (Perl regular expression, again) for matching
the sender address. An empty string matches any sender.

=item filters

An array ref to a list of filters. A mail will be fed into that list
(from the left to the right) and the final result will be returned to
sendmail. See L<Mail::IspMailGate::Filter(3)> for a description of
creating filters.

=back

The recipient list will be read top to bottom, the first match decides
which rule to choose. See the example configuration below for some
example rules.

=item @DEFAULT_FILTER

If no element of the @RECIPIENTS list matches an emails senders and
recipients, the filters from this variable will be choosen. By default
it contains a dummy filter.

=item %PACKER

This variable belongs to the Packer module. See
L<Mail::IspMailGate::Packer(3)> for details.

=item $VIRSCAN

=item %DEFLATER

=item $HAS_VIRUS

These belong to the VirScan module. See L<Mail::IspMailGate::VirScan(3)>.

=item $PGP_UID

=item $PGP_UIDS

=item $PGP_ENCRYPT_COMMAND

=item $PCP_DECRYPT_COMMAND

These belong to the PGP module. See L<Mail::IspMailGate::PGP(3)> for
details.

=back


=head2 Example Configuration

It might help to look at a commented example of the configuration file:

    # Yes, this is a module. Thus we have to introduce the file with
    # forcing the modules namespace.
    package Mail::IspMailGate::Config;

    # We load the modules here that will later be used for
    # creating recipient lists.
    require Mail::IspMailGate::Filter::Packer;
    require Mail::IspMailGate::Filter::Dummy;
    require Mail::IspMailGate::Filter::VirScan;
    require Mail::IspMailGate::Filter::PGP;

    # Directory settings and the like
    $VERSION = '1.000';
    $PREFIX = "/usr/local/IspMailGate-${VERSION}";
    $LIBDIR = "${PREFIX}/lib";
    $ETCDIR = "${PREFIX}/etc";
    $SCRIPTDIR = "${PREFIX}/sbin";
    $MANDIR = "${PREFIX}/man";
    $TMPDIR = '/var/spool/IspMailgate';
    $UNIXSOCK = '/var/run/ispMailGate.sock';
    $PIDFILE = '/var/run/ispMailGate.pid';
    $USER = 'daemon';
    $GROUP = 'mail';
    $MAILHOST = 'localhost';

    #
    # The packer module's configuration
    #
    %PACKER = ( 'gzip' => { 'pos' => '/bin/gzip -c',
			    'neg' => '/bin/gzip -cd' } );


    #
    # The virus scanner's configuration
    #
    $VIRSCAN = '/usr/local/bin/virusx $ipaths';
    @DEFLATER = ( { pattern => '\\.(tgz|tar\\.gz|tar\\.[zZ])$',
                    cmd => '/bin/gzip -cd $ipath | /bin/tar -xf -C $odir'
                  },
                  { pattern => '\\.tar$',
                    cmd => '/bin/tar -xf -C $odir'
		  },
	          { pattern => '\\.(gz|[zZ])$',
                    cmd => '/bin/gzip -cd $ipath >$opath'
                  },
                  { pattern => '\\.zip$',
                    cmd => '/usr/bin/unzip $ifile -d $odir'
                  }
                );

    #
    # sub which determines by a given string if a virus has been found.
    # It returns a non-empty string if a virus has been found, else it
    # returns ''
    #
    $HASVIRUS = sub ($) {
        my($str) = @_;
        if($str ne '') {
	    return "Virus has been found: $str";
        } else {
	    return '';
        }
    };


    #
    # The list of recpients; first match will be used. Any recipient not
    # matching one of the elements will be filtered through the
    # DEFAULT_FILTER.
    #
    @DEFAULT_FILTER = (Mail::IspMailGate::Filter::Dummy->new({}));

    #
    # Now the list of email senders/recipients that will handled by the
    # filter.
    #
    my($pgp) = 'Mail::IspMailGate::Filter::PGP';
    my($packer) = 'Mail::IspMailGate::Filter::Packer';
    @RECIPIENTS = (
        # Mail to hamburg.company.com (our branch in Hamburg, say)
        # will be compressed with gzip and encrypted with PGP, key
        # 'stuttgart.company.com'
        { 'recipient' => '\\@muenchen\\.company\\.com$',
          'filters' => [ $packer->new({'packer' => 'gzip',
                                       'direction' => 'pos'}),
                         $pgp->new({'uid' => 'stuttgart\\.company\\.com',
                                    'direction' => 'pos'}) ]
        },

        # The departure in munich doesn't use IspMailGate, but all
        # clients have AK-Mail installed. Mail to muenchen.company.com
        # (our branch in munich, say) will be encrypted with PGP, user
        # ID 'stuttgart.company.com'.
        { 'recipient' => '\\@muenchen\\.company\\.com$',
          'filters' => [ $pgp->new({'uid' => 'stuttgart\\.company\\.com',
                                    'direction' => 'pos'}) ]
        },

        # Mail from muenchen.company.com or hamburg.company.com to
        # stuttgart.company.com (incoming mail from the munich branch,
        # say) will be decompressed and decrypted. Note we handle both
        # sources with a single rule: The Packer module detects if a
        # mail is not compressed.
        { 'recipient' => '\\@stuttgart\\.company\\.com',
          'sender'    => '\\@(muenchen|hamburg)\\.company\\.com',
          'filters'   => [ $packer->new({'direction' => 'neg'}),
                           $pgp->new({'direction' => 'neg'}) ]
        },

        # joe@ispsoft.de is a very special user. We send him an
        # email bomb. (Filter to be being written. :-)
        { 'recipient' => 'joe\\@ispsoft\\.de'
          'filters'   => [ Mail::IspMailGate::Filter::Bomb->new({
                               'file' => 'X11R6.tar.gz' }) ]
        }
    );

    1;


=head1 AUTHORS, COPYRIGHT AND LICENSE

This module is

    Copyright (C) 1998         Amar Subramanian
                               Grundstr. 32
                               72810 Gomaringen
                               Germany

                               Email: amar@neckar-alb.de
                               Phone: +49 7072 920696


                       and     Jochen Wiedmann
                               Am Eisteich 9
                               72555 Metzingen
                               Germany

                               Email: joe@ispsoft.de
                               Phone: +49 7123 14887

    All Rights Reserved.

Permission to use, copy and modify this software and its documentation, 
is hereby granted to non-commercial entities without fee, provided that
this license information and copyright notice appear in all copies.

A "non-commercial entity" is defined within the scope of this license as
an educational institution (excluding a commercial training organisation), 
non-commercial research organisation, registered charity, registered 
not-for-profit organisation, or full-time student.

Use of this software by any other person or organisation for any purpose
requires that a usage license be obtained from the authors for that person
or organisation.  

Commercial redistribution of this software, by itself or as part of
another application is allowed only under express written permission of
the authors.

AMAR SUBRAMANIAN AND JOCHEN WIEDMANN DISCLAIM ALL WARRANTIES WITH 
REGARD TO THIS SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS, IN NO EVENT SHALL AMAR SUBRAMANIAN OR JOCHEN WIEDMANN BE 
LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES 
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN 
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR 
IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.


=head2 The Plain English Version

You can use this software free of charge if you are an educational 
institution (excluding commercial training organisations), non-commercial 
research organisation, registered charity, registered not-for-profit 
organisation, or full-time student.

If you want to use it and you do not fit into any of the above listed
categories, you must register your copy using the invoice form provided.

You cannot sell IspMailGate or bundle it with a product you develop without
obtaining written persmission and a "Commercial Redistribution License"
from us.

If something goes wrong and you lose data, system uptime, CPU cycles,
profits or anything else, neither of us is responsible.


=head2 The future of this license

It might well happen that this program will be distributed under the
GPL or the Perl Artistic License in a future version. Even (Even? No,
cut that word. :-) as professional software developers we are using
and recommending a lot of free software, including sendmail, Perl or
the MIME::Entity modules which are the base of this product. We beg
to understand, that we first would like to be payed for the time we
have put into IspMailGate. We'll see what happens.


=head1 SEE ALSO

L<Mail::IspMailGate::Filter(3)>, L<Mail::IspMailGate::Packer(3)>,
L<Mail::IspMailGate::VirScan(3)>, L<Mail::IspMailGate::PGP(3)> and
L<MIME::Entity(3)>


SCRIPT

use lib "lib";

require Config;
require Mail::IspMailGate::Config;
#$Mail::IspMailGate::Config::STARTPERL = $Config::Config{'startperl'} . " -wT";
$Mail::IspMailGate::Config::STARTPERL = $Config::Config{'startperl'} . " -w";
$script =~ s/\~(\w+)\~/${"Mail::IspMailGate::Config::" . $1}/eg;


if (!open(FILE, ">ispMailGateD")) {
    die "Cannot open ispMailGate for writing: $!";
}



if (!(print FILE $script)  ||  !close(FILE)) {
    die "Error while writing $script: $!";
}
