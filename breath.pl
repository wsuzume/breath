use strict;
use warnings;

use Cwd 'getcwd';
use File::Find;

my $cwd = getcwd;
#print $cwd, "\n";

if ( $#ARGV + 1 == 0 ) {
  print "Please choose mode: read or write.\n";
  exit(1);
}

my $mode = $ARGV[0];

if ( $mode eq "read" ) {
  &read_mode;
}
elsif ( $mode eq "write" ) {
  &write_mode;
}
else {
  print "mode should be read or write\n";
  exit(1);
}

sub read_mode {
  print "read mode is selected.\n";

  #find( \&print_file_name, "./" );
  #find( { wanted => \&print_breath_file, no_chdir => 1 }, "./" );
  find( { wanted => \&read_breath_file, no_chdir => 1 }, "./" );
  
  &print_whole_env;
  &dump_whole_env;
}

{
  my @whole_env = ();

  sub print_whole_env {
    print @whole_env;
  }

  sub dump_whole_env {
    my $file;
    open($file, "> breath.yml");
    print $file @whole_env;
    close($file);
  }

  sub read_breath_file {
    my $fname = $File::Find::name;

    my $file;

    if ( -d $fname ) {
      return;
    }

    if ( $fname =~ m|\.breath$| ) {
      print "breath file ", $fname, "\n";
      open($file, $fname) or die("Error in read file $fname");
      my @lines = <$file>;
      close($file);

      my %env_vars = ();
      my $var_number = 1;
      foreach my $line (@lines) {
        #print $line;
        while ( $line =~ m|(\{\{\{)(.+?)(\}\}\})|g ) {
          #print $2;
          if ( !exists($env_vars{$2}) ) {
            $env_vars{$2} = $var_number;
            $var_number += 1;
          }
        }
      }

      push(@whole_env, "$fname:\n");
      push(@whole_env, "  extension:\n");
      push(@whole_env, "  env_vars: \n");
      foreach my $key (sort {$env_vars{$a} <=> $env_vars{$b}} keys %env_vars) {
        #print $key, "\n";
        #print "    $key:$env_vars{$key}\n";
        push(@whole_env, "    $key:\n");
      }
      push(@whole_env, "\n");
    }
  }
}

sub validate_breath_yml {
}

sub write_mode {
  print "write mode is selected.\n";

  my $fname = "breath.yml";
  my $file;
  open($file, $fname) or die("Error read in $fname");

  close($file);

}

