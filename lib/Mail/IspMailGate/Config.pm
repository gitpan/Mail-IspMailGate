# -*- perl -*-
#

package Mail::IspMailGate::Config;

require 5.004;

require Mail::IspMailGate::Filter;
require Mail::IspMailGate::Filter::Packer;
require Mail::IspMailGate::Filter::Dummy;
require Mail::IspMailGate::Filter::VirScan;

$VERSION = '1.000';
$PREFIX = "/usr/local/IspMailGate-${VERSION}";
$LIBDIR = "${PREFIX}/lib";
$ETCDIR = "${PREFIX}/etc";
$SCRIPTDIR = "${PREFIX}/sbin";
$MANDIR = "${PREFIX}/man";
$TMPDIR = '/var/spool/IspMailgate';
$UNIXSOCK = '/var/run/ispMailGate.sock';
$PIDFILE = '/var/run/ispMailGate.pid';
$FACILITY = 'mail';
$USER = 'daemon';
$GROUP = 'mail';

#
# the configuration of the packer
#
%PACKER = ( 'gzip' => { 'pos' => '/bin/gzip -c',
			'neg' => '/bin/gzip -cd' } );


#
# configuration for the virus-scanner
#
$VIRSCAN = 't/virscan $ipaths';
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


$MAILHOST = 'localhost';

#
# The list of recpients; first match will be used. Any recipient not
# matching one of the elements will be filtered through the
# DEFAULT_FILTER.
#
@DEFAULT_FILTER = (Mail::IspMailGate::Filter::Dummy->new({}));

@RECIPIENTS =
    ({ 'recipient' => 'joe-packer\\@laptop\\.ispsoft\\.de',
       'filters' => [ Mail::IspMailGate::Filter::Packer->new({'packer' => 'gzip'}) ] },
     { 'recipient' => 'joe-depacker\\@laptop\\.ispsoft\\.de',
       'filters' => [ Mail::IspMailGate::Filter::Packer->new({'packer' => 'gzip', 'direction' => 'neg'}) ] },
     { 'recipient' => 'joe-virok\\@laptop\\.ispsoft\\.de',
       'filters' => [ Mail::IspMailGate::Filter::VirScan->new({}) ] },
     { 'recipient' => 'joe-virfound\\@laptop\\.ispsoft\\.de',
       'filters' => [ Mail::IspMailGate::Filter::VirScan->new({}) ] },
     );

1;
