use warnings;
use strict;

use Prima qw(Application MsgBox);

use Prima::Classes;
use Prima::StdDlg;

my $dlg;
my $closeAction = 0;
my $myApp;
my $winCount = 1;

package MyOpenDialog;
use vars qw( @ISA);
@ISA = qw( Prima::OpenDialog);

sub ok
{
	Launcher::read_config( $_[0]-> Name-> text);
}

package MyApp;
use vars qw( @ISA);
@ISA = qw( Prima::Application);

package Prima::Application;

sub create
{
	my $x = shift;
	return $myApp ? $myApp : $x-> SUPER::create( @_);
}

package Launcher;

sub read_config
{
	my $ini = $_[0];
	my $ok;
	my $app = $::application;
	{

		print "Opening '$ini'\n";
		open (my $ini_fh, "$ini") || die "Can't read '$ini': $!\n";
		while (defined (my $line = <$ini_fh>)) {
		
			#
			print $line;

		}
	        close $ini_fh;
	        Prima::MsgBox::message('Opened ' . $ini);
	}

	$::application = $app;
	print $@ unless $ok;

	$dlg->close;

}

package Generic;

sub close
{
	$_[0]-> SUPER::close if $closeAction;
}

sub destroy
{
	$_[0]-> SUPER::destroy if $closeAction;
}

sub sess_destroy
{
	$winCount--;
	$::application-> close unless $winCount;
}

sub f_open
{

	$dlg = MyOpenDialog-> create(
		name   => 'Launcher',
		filter => [
			['All files' => '*'],
			['Scripts' => '*.pl'],
                        ['Perl modules' => '*.pm'],
		],
		onEndModal => sub {
			$closeAction++;
			$dlg->close;
			$closeAction--;
		},
	);
	my $cl = $dlg-> Cancel;

	$cl-> text('Close');
	$cl-> set(
		onClick => sub {
			$closeAction++;
			$dlg-> cancel;
			$closeAction--;
		},
	);
	$dlg-> execute_shared;

	# my $i   = $dlg-> load( progressViewer => $self);

	# if ( $i) {
	# 	menuadd( $_[0]);
	# 	$self-> image( $i);
	# 	$self-> {fileName} = $dlg-> fileName;
	# 	status( $_[0]);
	# }
}

sub f_save
{
	my $iv = $_[0]-> IV;
	Prima::MsgBox::message('Cannot save '.$iv-> {fileName}. ":$@")
		unless $iv-> image-> save( $iv-> {fileName});
}

sub f_saveas
{
	my $iv = $_[0]-> IV;
	my $dlg  = Prima::ImageSaveDialog-> create( image => $iv-> image);
	$iv-> {fileName} = $dlg-> fileName if $dlg-> save( $iv-> image);
	$dlg-> destroy;
}

# my $w = Prima::Window-> create(
my $w = Prima::MainWindow-> new( 
        text => 'Sessions',
	size => [ 300, 300],
	onDestroy => \&sess_destroy,
	onMouseWheel => sub { iv_mousewheel( shift-> IV, @_)},
	menuItems => [
	[ file => '~File' => [
                [ '~Open', 'Ctrl+O', '^O', \&f_open ],
                [ '~Save', 'Ctrl+S', '^S', \&f_save ],
                [ 'Save ~as...', \&f_saveas ],
		[],
#		[ 'E~xit' => 'Alt+X' => '@X' => sub {$::application-> close} ],
                ['~Exit', 'Alt+X', km::Alt | ord('X'), sub { shift-> close } ],
	]],
	],
);

run Prima;
