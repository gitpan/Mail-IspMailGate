# -*- perl -*-
#

package Mail::IspMailGate::Config;

require 5.004;

require Mail::IspMailGate::Filter;
require Mail::IspMailGate::Filter::Banner;
require Mail::IspMailGate::Filter::Dummy;
require Mail::IspMailGate::Filter::VirScan;


$VERSION = '1.001';
$PREFIX = "/usr/local/IspMailGate-${VERSION}";
$LIBDIR = "${PREFIX}/lib";
$ETCDIR = "${PREFIX}/etc";
$SCRIPTDIR = "${PREFIX}/sbin";
$MANDIR = "${PREFIX}/man";
$TMPDIR = '/var/spool/ispmailgate';
$UNIXSOCK = '/var/run/ispMailGate.sock';
$PIDFILE = '/var/run/ispMailGate.pid';
$FACILITY = 'mail';
$USER = 'daemon';
$GROUP = 'mail';
$POSTMASTER = 'root@ispsoft.de';


#
# the configuration of the packer
#
%PACKER = ( 'gzip' => { 'pos' => '/bin/gzip -c',
			'neg' => '/bin/gzip -cd' } );


#
# configuration for the virus-scanner
#
$VIRSCAN = '/usr/bin/antivir -rs $ipaths';
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
                },
	      { pattern => '\\.(lha|lzx)$',
                cmd => '/usr/bin/lha $ifile w=$odir'
                }     
);


#
# sub which determines by a given string if a virus has been found.
# It returns a non-empty string if a virus has been found, else it
# returns ''
#
$HASVIRUS = sub ($) {
    my $str = shift;
    my $result = join('\n', grep { $_ =~ /\!Virus\!/ } split(/\n/, $str));
    $result ? "Alert: A Virus has been detected:\n\n$result\n" : '';
};



$MAILHOST = 'localhost';

#
# The list of recpients; first match will be used. Any recipient not
# matching one of the elements will be filtered through the
# DEFAULT_FILTER.
#
@DEFAULT_FILTER = (Mail::IspMailGate::Filter::Dummy->new({}));

@RECIPIENTS =
    ( { 'recipient' => '[@\.]ispsoft\.de$',
        'filters' => [ Mail::IspMailGate::Filter::VirScan->new({}) ] },
      { 'sender' => '[@\.]ispsoft.de$',
	'filters' => [ Mail::IspMailGate::Filter::Banner->new
		          ({'plain' => '/etc/mail/banner.plain',
			    'html' => '/etc/mail/banner.html'}) ] }
	     );

1;
