# -*- perl -*-

require 5.004;
use strict;


require Mail::IspMailGate::Config;
require MIME::Parser;
require File::Basename;


package Mail::IspMailGate::Parser;

$Mail::IspMailGate::Parser::VERSION = '0.01';
@Mail::IspMailGate::Parser::ISA = qw(MIME::Parser);

sub new ($$) {
    my($class, $attr) = @_;
    my($self) = $class->SUPER::new
	( 'output_dir' => $Mail::IspMailGate::Config::TMPDIR,
	  'output_prefix' => 'part',
	  'output_to_core' => 'NONE');
    $self;
}

sub output_path ($$) {
    my($self, $head) = @_;
    my($path) = $self->SUPER::output_path($head);
    my($i) = 0;
    my($opath) = $path;
    while (-f $path) {
	$path = File::Basename::dirname($opath) . "/$i" .
	    File::Basename::basename($opath);
	++$i;
    }
    $path;
}


1;
