# -*- perl -*-
#


package Mail::IspMailGate::Filter::VirScan;

require 5.004;
use strict;
require File::Copy;
require File::Basename;
require Symbol;

require Mail::IspMailGate::Filter;

@Mail::IspMailGate::Filter::VirScan::ISA = qw(Mail::IspMailGate::Filter);

sub getSign { "X-ispMailGate-VirScan" }

#####################################################################
#
#   Name:     mustFilter
#
#   Purpose:   determines wether this message must be filtered and
#             allowed to modify $self the message and so on
#             
#   Inputs:   $self   - This class
#             $entity - the whole message
#                       
#
#   Returns:  1 if it must be, else 0
#    
#####################################################################

sub mustFilter ($$) {
    # Always true (consider faked headers!)
    1;
}


#####################################################################
#
#   Name:     hookFilter
#
#   Purpose:  a function which is called after the filtering process
#             
#   Inputs:   $self   - This class
#             $entity - the whole message
#                       
#
#   Returns:  errormessage if any
#    
#####################################################################

sub hookFilter ($$) {
    my($self, $entity) = @_;
    my($head) = $entity->head;
    $head->set($self->getSign(), 'scanned');
    '';
}



#####################################################################
#
#   Name:     createDir
#
#   Purpse:   creates a new directory, under the given
#
#   Inputs:   $self   - This class
#             $attr   - Attributes
#
#   Returns:  the name of the new dir
#    
#####################################################################

sub createDir ($$) {
    my ($self, $attr) = @_;

    my($baseDir) = $attr->{'parser'}->output_dir();
    my($i) = 0;
    my($dir);

    while (-e ($dir = "$baseDir/dir$i")) {
	++$i;
    }
    if (!mkdir $dir, 0700) {
	die "Cannot create directory $dir ($!)";
    }
    $dir;
}


#####################################################################
#
#   Name:     checkDirFiles
#
#   Purpse:   creates a list of files from a certain directory,
#             including subdirectories
#
#   Inputs:   $self   - This instance
#             $dir    - Directory name
#
#   Returns:  File list; dies in case of trouble
#    
#####################################################################

sub checkDirFiles ($$) {
    my($self, $dir) = @_;
    my(@files);

    #
    # Recursively scan directory $dir for files
    #
    my($dirHandle) = Symbol::gensym();
    if (!opendir($dirHandle, $dir)) {
	die "Cannot read directory $dir ($!)";
    }
    my($file);
    while (defined($file = readdir($dirHandle))) {
	if ($file eq '.'  ||  $file eq '..') {
	    next;
	}
	$file = "$dir/$file";
	if (-d $file) {
	    push(@files, $self->checkDirFiles($file));
	} elsif (-f _) {
	    push(@files, $file);
	}
    }
    closedir($dirHandle);

    @files;
}


#####################################################################
#
#   Name:     checkArchive
#
#   Purpse:   creates a new temporary directory and extracts an
#             archive into it; returns a list of files that have
#             been created by calling checkDirFiles
#
#   Inputs:   $self     - This instance
#             $attr     - The $attr argument of filterList
#             $ipath    - The archive path
#             $deflater - An element from the @DEFLATER list that
#                         matches $ipath.
#
#   Returns:  File list; dies in case of trouble
#    
#####################################################################

sub _ShellSafe($) {
    my($str) = @_;
    $str =~ s/[\000-\037]//g;
    $str =~ s/([^a-zA-Z])/\\$1/g;
    $str;
}


sub checkArchive ($$$$) {
    my($self, $attr, $ipath, $deflater) = @_;

    # Create a new directory for extracting the files into it.
    my($idir) = File::Basename::dirname($ipath);
    my($ifile) = File::Basename::basename($ipath);
    my($odir) = $self->createDir($attr);
    my($ofile) = $ifile;
    my($opath) = "$odir/$ofile";
    my($cmd) = $deflater->{'cmd'};
    # no strict 'refs';
    # $cmd =~ s/\$(\w+)/_ShellSafe(${$1})/eg;
    # use strict 'refs';
    $cmd =~ s/\$(\w+)/_ShellSafe(eval "\$$1")/eg;
    system $cmd;

    $self->checkDirFiles($odir);
}


#####################################################################
#
#   Name:     checkFile
#
#   Purpse:   checks a file (recursively if archive) for virus
#
#   Inputs:   $self   - Instance
#             $attr   - Same as the $attr argument of filterFile
#             $ipath  - the file to check
#
#   Returns:  error message, if any
#    
#####################################################################

sub checkFile ($$$) {
    my ($self, $attr, $ipath) = @_;
    my(@simpleFiles, @checkFiles);
    my($ret) = '';

    @checkFiles = ($ipath);
    my($file);
    while (defined($file = shift @checkFiles)) {
	# Modify the name for use in a shell command
	if ($file =~ /[\000-\037]/) {
	    $ret .= "Suspect file names: $file";
	    next;
	}

	# Check whether file is an archive
	my($deflater);
	foreach $deflater (@Mail::IspMailGate::Config::DEFLATER) {
	    if ($file =~ /$deflater->{'pattern'}/) {
		push(@checkFiles,
		     $self->checkArchive($attr, $file, $deflater));
		undef $file;
		last;
	    }
	}

	# If it isn't, scan it
	if (defined($file)) {
	    push(@simpleFiles, $file);
	}
    }

    if (@simpleFiles) {
	my($cmd) = $Mail::IspMailGate::Config::VIRSCAN;
	my($output);
	if ($cmd =~ /\$ipaths/) {
	    # We may scan all files with a single command
	    my($ipaths) = '';
	    foreach $file (@simpleFiles) {
		$ipaths .= ' ' . _ShellSafe($file);
	    }
	    $cmd =~ s/\$ipaths/$ipaths/;
	    $output = `$cmd`;
	    $ret .= &$Mail::IspMailGate::Config::HASVIRUS($output);
        } else {
	    # We need to scan any file separately
	    foreach $file (@simpleFiles) {
		$ipath = _ShellSafe($file);
		$cmd =~ s/\$ipath/$ipath/;
		$output = `$cmd`;
	        $ret .= &$Mail::IspMailGate::Config::HASVIRUS($output);
	    }
        }
    }
    $ret;
}


#####################################################################
#
#   Name:     filterFile
#
#   Purpse:   do the filter process for one file
#
#   Inputs:   $self   - This class
#             $attr   - hash-ref to filter attribute
#                       1. 'body'
#                       2. 'parser'
#                       3. 'head'
#                       4. 'globHead'
#
#   Returns:  error message, if any
#    
#####################################################################

sub filterFile ($$) {
    my ($self, $attr) = @_;

    my ($body) = $attr->{'body'};
    my ($globHead) = $attr->{'globHead'};
    my ($ifile) = $body->path();
    $attr->{'main'}->Debug("Scanning file $ifile for viruses");
    my ($ret) = 0;
    if($ret = $self->SUPER::filterFile($attr)) {
	$attr->{'main'}->Debug("Returning immediately, result $ret");
	return $ret;
    }

    my ($cmd);
    $cmd = $Mail::IspMailGate::Config::VIRSCAN;
    
    $ret = $self->checkFile($attr, $ifile);
    $attr->{'main'}->Debug("Returning, result $ret");
    $ret;
}


1;

__END__


=pod

=head1 NAME

Mail::IspMailGate::Filter::VirScan  - Scanning emails for Viruses

=head1 SYNOPSIS

 # Create a filter object
 my($scanner) = Mail::IspMailGate::Filter::VirScan->new({});

 # Call it for filtering the MIME entity $entity and pass it a
 # Mail::IspMailGate::Parser object $parser
 my($result) = $scanner->doFilter({
     'entity' => $entity,
     'parser' => $parser
     });
 if ($result) { die "Error: $result"; }

=head1 VERSION AND VOLATILITY

    $Revision 1.0 $
    $Date 1998/04/05 18:46:12 $

=head1 DESCRIPTION

This class implements a Virus scanning email filter. It is derived from
the abstract base class Mail::IspMailGate::Filter. For details of an
abstract filter see L<Mail::IspMailGate::Filter>.

The virus scanner class needs an external binary which has the ability
to detect viruses in given files, like VirusX from http://www.antivir.com.
What the module does is extracting files from the email and passing them
to the scanner. Extracting includes dearchiving .zip files, .tar.gz files
and other known archive types by using external dearchiving utilities like
I<unzip>, I<tar> and I<gzip>. Known extensions and dearchivers are
configurable, so you can customize them for your own needs.

=head1 CUSTOMIZATION

The virus scanner module depends on some variables from the
Mail::IspMailGate::Config module:

=over 4

=item $VIRSCAN

A template for calling the external virus scanner; example:

    $VIRSCAN = '/usr/bin/virusx $ipaths';

The template must include either of the variable names $ipath or $ipaths;
the former must be used, if the virus scanner cannot accept more than one
file name with one call. Note the use of single quotes which prevent
expanding the variable name!

=item $HASVIRUS

A anonymous Perl subroutine which receives the virus scanners output as
a string. It must return TRUE, if the output indicates a virus and
FALSE otherwise. Example:

    $HASVIRUS = sub ($) {
        my($str) = shift;
	return (defined($str) && $str eq 'virus detected');
    }

=item @DEFLATER

This is an array of known archive deflaters. Each element of the array
is a hash ref with the attributes C<cmd>, a template for calling the
dearchiver and C<pattern>, a Perl regular expression for detecting
file names which refer to archives that this program might extract.
An example which configures the use of C<unzip>, C<tar> and C<gzip>:

    @DEFLATER =
        ( { pattern => '\\.(tgz|tar\\.gz|tar\\.[zZ])$',
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

Again, note the use of single quotes to prevent variable expansion and
double backslashes for passing a single backslash in the Perl regular
expressions. See L<perlre> for details of regular expressions.

The command template can use the following variables:

=over 8

=item $ipath

Full filename of the archive being deflated

=item $idir

=item $ifile

Directory and file name portion of the archive

=item $odir

Directory where the archive must be extracted to; if your dearchiver
doesn't support an option --directory or something similar, you need
to create a subshell. For example the following might be used for
an LhA deflater:

    { 'pattern' => '\\.(lha|lzx)',
       'cmd' => '(cd $odir; lha x $ipath)'
    }

=item $ofile

=item $opath

Same as $ifile and $odir/$ofile; for example gzip needs this, when it
runs as a standalone deflater and not as a backend of tar.

=back

=back

=head1 PUBLIC INTERFACE

=over 4

=item I<checkFile $ATTR, $FILE>

This function is called for every part of a MIME-message from within
the I<filterFile> method. It receives the arguments $ATTR (same as the
$ATTR argument of filterFile) and $FILE, the filename where the MIME
part is stored. If it detects $FILE to be an archive, it calls
C<checkArchive> for deflating it and building a list of files contained
in the archive. If another archive is found, it calls C<checkArchive>
again.

Finally, after building a list of files, it calls the virus scanner.
If the scanner can handle multiple files, a single call occurs, otherwise
the scanner will be called for any file. See L<CONFIGURATION> above.

=item I<checkArchive $ATTR, $IPATH, $DEFLATER>

This function is called from within I<checkFile> to extract the archive
$IPATH by using the $DEFLATER->{'cmd'} ($DEFLATER is an element from
the @DEFLATER list). The $ATTR argument is the same as in I<checkFile>.

The function creates a new temporary directory and extracts the archive
contents into that directory. Finally it returns a list of files that
have been extracted.

=back

=head1 SEE ALSO

L<ispMailGate>, L<Mail::IspMailGate::Filter>

=cut
