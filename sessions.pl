use warnings;
use strict;

use Prima qw(ComboBox Edit Application Buttons MsgBox);

use Prima::Classes;
use Prima::StdDlg;
use File::Copy;

my $dlg;
my $closeAction = 0;
my $myApp;
my %win = (
	main => 'Main',
	file_open => 'File Open',
	file_save => 'File Save',
	file_saveas => 'File Save As',
);
my $w;

my $win_count = {
	main => 1,
	file_open => 0,
	file_save => 0,
	file_saveas => 0,
};

my $cfg;
$cfg->{comment_char} = '#';
$cfg->{fileName} = "$ENV{HOMEDRIVE}/etc/sessions.ini";
# $cfg->{fileName} = "E:/win/etc/sessions.ini";

package Debug;
sub DEBUG { 1 }
sub Print ($) {
	DEBUG && print shift;
}

package MyOpenDialog;
use vars qw( @ISA);
@ISA = qw( Prima::OpenDialog);

sub ok
{
	$cfg->{fileName} = $_[0]-> Name-> text;
	Launcher::read_config( $cfg );
	$dlg->close;
	Dialog::dec_dia("file_open");
	Dialog::print_conf();
	# use Data::Dumper;
	# print Dumper $cfg;

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

sub populate_domains
{

	my $domain_list = $w->DomainList-> List;
	$domain_list->delete_items( 0..$domain_list->count );
	# print Dumper $domain_list;
	$domain_list->add_items( "Domain..." );
	my $dom_count;
	for my $dom ( sort keys %{$cfg->{data}->{'Domains'}} ) {
		$cfg->{data}->{settings}->{verbose} eq "yes" &&
			print "Add domain: $dom\n";
		$domain_list->add_items( $dom );

#
# See: http://cpansearch.perl.org/src/KARASIK/Prima-1.37/examples/menu.pl 
#
#		$w->menu->insert([
#			[ $dom => [
#			       [ '' => ''],	
#			]]
#		], 'host', 1);
#

	}

	# use Data::Dumper;
	# print Dumper $w->menu;
	

}

sub read_config
{
	# my $cfg = $_[0];
	my $ini = $cfg->{fileName};
	my $ok;

	my $sect = '*** GLOBAL CONFIG ***';
	my $parm;

	my $app = $::application;
	{

		Debug::Print "Reading '$ini'\n";
		open (my $ini_fh, "$ini") || die "Can't read '$ini': $!\n";
		while (defined (my $line = <$ini_fh>)) {

			next if $line =~ /^$cfg->{comment_char}/;

			if ( $line =~ /^\[([^]]+)\]\s+$/ ) {
				$sect = $1;
				$cfg->{sects}->{$sect} = undef;
			}
			elsif ( $line =~ /^\s*([^=]+?)\s*=\s*(.*?)\s*$/ ) {
				$parm = $1;
				$cfg->{data}->{$sect}->{$parm} = $2;
			}

		}
		# close $ini_fh;
		CORE::close $ini_fh;
		populate_domains();
	}

	$::application = $app;
	print $@ unless $ok;

}

package Dialog;

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
	$win_count->{main}--;
	$::application-> close unless $win_count->{main};
}

sub inc_dia ($) {

	my $dia = shift;
	if ( $win_count->{$dia} && $win_count->{$dia} > 0 ) {
		Debug::Print "$win{$dia} dialog extant\n";
		return 2;
	} else {
		Debug::Print "$win{$dia} dialog created\n";
		$w->menu->file->disable; 
		$win_count->{$dia}++;
		return $win_count->{$dia};
		$w->popupItems($w->menuItems);	
	}

}

sub dec_dia ($) {

	my $dia = shift;
	Debug::Print "$win{$dia} dialog destroyed\n";
	$w->menu->file->enable; 
	$win_count->{$dia}--;
	return $win_count->{$dia};

}


sub file_open
{
	# my $open = Prima::OpenDialog-> new(
	#	filter => [
	#		['Ini files' => '*.ini'],
	#		['All' => '*']
	#	]
	#);

	# print "Opened ", $open-> fileName, $/ if $open-> execute;

	if ( inc_dia("file_open") > 1 ) {
		return;
	}
	# $dlg = Prima::OpenDialog-> create(
	$dlg = MyOpenDialog-> create(
		name => 'Launcher',
		# icon => 'Error',
		directory => "$ENV{HOMEDRIVE}/etc",
		filter => [
			['Ini files' => '*.ini'],
			['All files' => '*'],
		],
		onEndModal => sub {
			$closeAction++;
			$dlg->close;
			$closeAction--;
			dec_dia "file_open";
		},
		system => 1,
	);
	my $cl = $dlg-> Cancel;

	$cl-> text('Close');
	$cl-> set(
		onClick => sub {
			$closeAction++;
			$dlg->cancel;
			$closeAction--;
		},
	);
	$dlg-> execute_shared;

	return $dlg;

}

sub file_save
{

	if ( ! $cfg->{data} ) {
		Prima::MsgBox::message("No data in INI file yet!");
		return;
	}

	if ( ! $cfg->{fileName} ) {
		Prima::MsgBox::message("INI file not defined: $@");
		return;
	}
	my $file_name = $cfg->{fileName};

	open (my $save_fh, '>', $file_name) or Prima::MsgBox::message("Can't save '$file_name':$@");
	for my $sect ( keys %{$cfg->{sects}} ) {
		print $save_fh "[$sect]\n";
		for my $parm ( keys %{$cfg->{data}->{$sect}} ) {
			print $save_fh "$parm = $cfg->{data}->{$sect}->{$parm}\n";
		}
		print $save_fh $/;
	}
	my $ignore = {
		data => 1,
		sects => 1,
	};
	for my $key ( keys %{$cfg} ) {
		next if $ignore->{$key};
		print $save_fh "# $key = $cfg->{$key}\n";
	}
	CORE::close $save_fh;

	$cfg->{data}->{settings}->{verbose} eq "yes" &&
		print "Saved '$file_name'\n";

}

sub file_save_as
{
	# my $save = $_[0];

	my $fileName = $cfg->{fileName};
	if ( File::Copy::copy("$fileName", "$fileName.old") ) {

		$cfg->{data}->{settings}->{verbose} eq "yes" &&
			print "`$fileName' -> `$fileName.old'\n";

	} else {

		Prima::MsgBox::message("Can't back up '$fileName'");
		exit 1;

	}

	# save a file
	my $save = Prima::SaveDialog-> new(
		fileName => $fileName,
	);
	if ( $save->execute ) {
		$cfg->{data}->{settings}->{verbose} eq "yes" &&
			print "Saving to: ", $save->fileName, $/;
	} else {
		die "Can't save to that name\n";
	}
	my $file_name = $save->fileName;
	$cfg->{fileName} = $file_name;

	file_save;

	# Prima::MsgBox::message("Can't save ".$save-> {fileName}. ":$@")
 	# 	unless $save->save( $save-> {fileName});

	# print Dumper $save;

}

sub edit_conf
{

	my @args = (
		$cfg->{data}->{settings}->{editor}, $cfg->{fileName}
	);

	$cfg->{data}->{settings}->{verbose} eq "yes" &&
		print join " ", @args, $/;

	my $msg = "";
	system(1,@args);
	if ($? == -1) {
		$msg = sprintf "Failed to execute: $!\n";
	}
	Prima::MsgBox::message($msg) if $msg;

}

sub trash_conf
{

	print "#\n# Trashing config...\n#\n";

	for my $sect ( keys %{$cfg->{sects}} ) {
		next if $sect eq 'settings';
		print "Deleting $sect\n";
		delete $cfg->{sects}->{$sect};
		delete $cfg->{data}->{$sect};
	}
	# use Data::Dumper;
	# Launcher::populate_domains();
	my $domain_list = $w->DomainList-> List;
	# print Dumper $domain_list;
	#
	$domain_list->add_items("Load new config...");
	Launcher::populate_domains();
	# $w->DomainList->text = "Load new config...";
	# $domain_list->{edit}->text("Fred");

}

sub print_conf
{

	print "#\n# Config:\n#\n";

	for my $sect ( keys %{$cfg->{sects}} ) {
		print "[$sect]\n";
		for my $parm ( keys %{$cfg->{data}->{$sect}} ) {
			print "$parm = $cfg->{data}->{$sect}->{$parm}\n";
		}
		print $/;
	}
	my $ignore = {
		data => 1,
		sects => 1,
	};
	for my $key ( keys %{$cfg} ) {
		next if $ignore->{$key};
		print "# $key = $cfg->{$key}\n";
	}
	for my $key ( keys %ENV ) {
		$cfg->{data}->{settings}->{verbose} eq "yes" &&
			print "$key : $ENV{$key}\n";
	}

}

sub system_save_file_dialog
{
	my %profile = @_;

	# use Data::Dumper;
	# print Dumper \%profile;

	Prima::open_file;

}

sub add_host
{
	$w->HostList->List->add_items($w->NewHost->text);
}

sub populate_groups
{

	my $group_list = $w->GroupList-> List;
	$group_list->delete_items( 0..$group_list->count );
	my $domain = $w->DomainList->text;
	# use Data::Dumper;
	# print Dumper $domain;
	for my $group ( sort keys %{$cfg->{data}->{$domain}} ) {
		$cfg->{data}->{settings}->{verbose} eq "yes" &&
			print "Add group: $group\n";
		$group_list->add_items( $group );
		$w->menu->insert([
			[ $domain => [
			       [ $group => $group],	
			]]
		], 'host', 1);
	}

}

sub populate_hosts
{

	# use Data::Dumper;
	# print Dumper $cfg;
	my $host_list = $w->HostList-> List;
	$host_list->delete_items( 0..$host_list->count );
	# print Dumper $host_list;
	my $domain = $w->DomainList->text;
	my $group = $w->GroupList->text;
	for my $host ( split (/\s+/, $cfg->{data}->{$domain}->{$group}) ) {
		$cfg->{data}->{settings}->{verbose} eq "yes" &&
			print "Add host: $host\n";
		$host_list->add_items( $host );
	}

}

sub launch_putty
{

	my $host = $w->HostList->text;
	my $location = $cfg->{data}->{settings}->{location};
	my %ldom = map { $_ => 1 } split(' ', $cfg->{data}->{LocalDomains}->{$location});

	my $domain = $cfg->{data}->{Domains}->{ $w->DomainList->text };
	
	if ( ! $ldom{$domain} ) {
		$host = "$host.$domain";
	}

	# Prima::MsgBox::message( $host );

	my $user_at_host;

	if ( $host =~ /@/ ) {
		$user_at_host = $host;
	} else {
		$user_at_host = $cfg->{data}->{settings}->{user} . 
		'@'.
		$host;
	}

	my @args = (
		$cfg->{data}->{settings}->{putty}, "-ssh", $user_at_host
	);

	$cfg->{data}->{settings}->{verbose} eq "yes" &&
		print join " ", @args, $/;

	my $msg = "";
	system(1,@args);
	if ($? == -1) {
		$msg = sprintf "Failed to execute: $!\n";
	}
#	elsif ($? & 127) {
#		$msg = sprintf "Child died with signal %d, %s coredump\n",
#			($? & 127), ($? & 128) ? 'with' : 'without';
#	}
#	else {
#		$msg = sprintf "Child exited with value %d\n", $? >> 8
#			if $cfg->{data}->{settings}->{verbose} eq "yes";
#	}
	Prima::MsgBox::message($msg) if $msg;

}

# my $w = Prima::Window-> create(
$w = Prima::MainWindow-> new( 
	text => 'Sessions',
	size => [ 500, 300],
	onDestroy => \&sess_destroy,
	# onMouseWheel => sub { iv_mousewheel( shift-> IV, @_)},
	menuItems => [
	[ file => '~File' => [
		[ '~Open', 'Ctrl+O', '^O', \&file_open ],
#		[ '~Test', 'Ctrl+T', '^T', \&system_save_file ],
		[ '~Save', 'Ctrl+S', '^S', \&file_save ],
		[ 'Save ~as...', \&file_save_as ],
		[],
		[ '~Edit config', 'Ctrl+E', '^E', \&edit_conf ],
		[ '~Print config', 'Ctrl+P', '^P', \&print_conf ],
		[ '~Trash config', 'Ctrl+T', '^T', \&trash_conf ],
		[],
#		[ 'E~xit' => 'Alt+X' => '@X' => sub {$::application-> close} ],
		['E~xit', 'Alt+X', km::Alt | ord('X'), sub { shift-> close } ],
	]],
	[ host => '~Host' => [
		[],
	]],
	],
);

$w->insert( "ComboBox",
	name => 'DomainList',
	text => 'Domain...',
	items => ['Domains...'],
	pack => { side => 'left', expand => 1, fill => 'both', padx => 20, pady => 20},
	onChange => sub { populate_groups( $w->GroupList, @_)},
);
$w->DomainList->style(cs::DropDownList);

$w-> insert( "ComboBox",
	name => 'GroupList',
	text => 'Group...',
	items => ['Group...'],
	pack => { side => 'left', expand => 1, fill => 'both', padx => 20, pady => 20},
	onChange => sub { populate_hosts( $w->HostList, @_)},
);
$w->GroupList->style(cs::DropDownList);

$w-> insert( "ComboBox",
	name => 'HostList',
	text => 'Host...',
	size => [ 100, 100 ],	
	items => ['Host...'],
	pack => { side => 'left', expand => 1, fill => 'both', padx => 20, pady => 20},
	onChange => sub { launch_putty() },
);
$w->HostList->style(cs::DropDownList);
# $w->HostList->style(cs::DropDown);

# $w-> insert( Button =>
# 	text     => 'Go',
# 	growMode => gm::Center,
# 	onClick  => sub { Prima::message("Went!") }
# );
$w-> insert( Button =>
	text     => 'Quit',
	growMode => gm::Center,
	# pack => { expand => 1, fill => 'both', padx => 20, pady => 20},
	onClick  => sub { exit }
);

# $w-> insert("NewHost", pack => {side => 'bottom', fill => 'x', padx => 20, pady => 20 });

Launcher::read_config( $cfg );

run Prima;

