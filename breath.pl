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

sub validate_extension {
  my $line = $_[0];

}

sub validate_filename {
}

{
  # 設定ファイルを読み込んだときに格納しておくバッファ
  my @lines;

  # 置換した結果を格納しておくバッファ
  my %replaced = ();

  # extension: と env_vars: に相当するインデント
  # 各ファイルの単位でこのインデントのルールが崩れるとエラー。
  my $fst_indent = 0;

  # 「環境変数：値」の行に相当するインデント
  # 各ファイルの単位でこのインデントのルールが崩れるとエラー。
  my $snd_indent = 0;

  sub check_fst_indent {
    my $indent = $_[0];

    if ( $indent == 0 ) {
      # 1stインデントが来るべきところにインデントがないのでエラー
      return 0;
    }

    if ( $fst_indent == 0 ) {
      # 初回なので登録
      $fst_indent = $indent;
    }
    elsif ( $fst_indent != $indent ) {
      # 登録されているインデントと違うのでエラー
      return 0;
    }

    if ( $snd_indent != 0 and $fst_indent <= $snd_indent ) {
      # 2ndインデントが既に読み取り済みで
      # 1stインデントが2ndインデントより深いか同じなのはエラー
      return 0;
    }

    return 1;
  }

   sub check_snd_indent {
     my $indent = $_[0];

     if ( $fst_indent == 0 ) {
       # 1stインデントよりも先に2ndインデントが来るのはエラー
       return 0;
     }

     if ( $snd_indent == 0 ) {
       # 初回なので登録
       $snd_indent = $indent;
     }
     elsif ( $snd_indent != $indent ) {
       # 登録されているインデントと違うのでエラー
       return 0;
     }

     if ( $snd_indent <= $fst_indent ) {
       # 2ndインデントが1stインデントよりも浅いか同じなのでエラー
       return 0;
     }
     
     return 1;
   }


  # filename を読んだ時点で 1 。これが 1 のときに EOF か次の filename を読むと次のファイル。
  # これが 0 のときに is_read_extension か is_read_env_vars が 1 になるとエラー。
  my $is_read_filename = 0;
  # 今読んでいるファイルの名前
  my $cur_filename;
  # 今読んでいるファイルの設定
  my %cur_store = ();

  # extension: を読んだ時点で 1 。これが 1 のときに「環境変数: 値」の行を読むとエラー。
  # これが 1 のときに次の filename が来るのは別にOK。
  # 次の filename か env_vars: が来ると 0 になる。
  my $is_read_extension = 0;

  # env_vars: を読んだ時点で 1 。これが 1 のときのみ「環境変数：値」の行を読んでいい。
  # 次の filename か extension: が来ると 0 になる。 
  my $is_read_env_vars = 0;  

  sub parse_breath_yml {
    $is_read_filename = 0;
    $fst_indent = 0;
    $snd_indent = 0;

    my $idx = 1;
    foreach my $line (@lines) {
      parse_line($line, $idx, 0);
      $idx += 1;
    }
    parse_line("", $idx, 1);
  }

  sub parse_line {
    # ただのlinefeed
    # 先頭スペースなし & ':'の後に空白文字以外なし -> ファイル名
    # 先頭スペースあり & extension: & ':'の後に文字あり -> 拡張子(第1インデントの深さが記録)
    # 先頭スペースあり & env_vars: & ':'の後に文字なし -> 環境変数の開始(第1インデントの深さが記録)
    # 先頭スペースあり & 任意の文字列: & ':'の後に文字あり -> 環境変数(第2インデントの深さが記録)
    # これ以外は現在予期していないのでエラー

    # パターン
    # 1. (空白)(変数)(空白)(:)(空白)(文字)(値) -> extension:、環境変数 および ファイル名 と env_vars: のエラー（値あり）にマッチ
    #    ただし拡張子で .yml/hoge とか指定されると困るので拡張子に / が含まれていたらあとでエラーにする
    # 2. (空白)(変数)(空白)(:)(空白) -> ファイル名、env_vars: および extension: と 環境変数のエラー（値なし）にマッチ
    # 3. 上記にマッチしないものは対応しない

    # 読み取りの終了条件
    # 1. EOF
    # 2. 次のファイル
    # 3. 他は読み取りを継続

    my $line = $_[0];
    my $idx = $_[1];
    my $finalize = $_[2];

    if ( $finalize ) {
      $replaced{$cur_filename} = %cur_store;
      return;
    }

    #print $line;
    if ( $line =~ m|^(\s*)(\w+)(\s*)(:)(\s*)([\w/.]+)(\s*)(\R)$| ) {
      # パターン 1
      # 拡張子または環境変数
      print "case 1 ", $line;

      my $indent = length $1;
      if ( $indent > 0 ) {
          #print "indent!!\n";
          #print $indent;
      }
      #print "    indent = $1   key = $2\n";

      if ( $2 eq "extension" ) {
        print "!!Extension\n";
      }
      elsif ( $2 eq "env_vars" ) {
        print "!!ENV_VARS\n";
      }
      else {
        print "invalid syntax.\n";
      }
    }
    elsif ( $line =~ m|^(\s*)([\w/.\-]+)(\s*)(:)(\s*)(\R)$| ) {
      # パターン 2
      # print "    key = $2\n";

      my $indent = length $1;

      if ( $2 eq "extension" ) {
        printf "Invalid syntax in line %d: extension must have value.\n", $idx;
        print "$line\n";
      }
      elsif ( $2 eq "env_vars" ) {
        if ( !check_fst_indent($indent) ) {
          printf "Indent error in line %d.\n", $idx;
          print "$line\n";
        }
        $is_read_extension = 0;
        $is_read_env_vars = 1;
      }
      else {
        if ( $indent == 0 ) {
          # 以前に何かファイル設定を読んだか
          if ( $is_read_filename == 0 ) {
            # もっとも最初に到達すべき分岐
            #print "MAYBE filename!!\n";
            if ( exists($replaced{$2}) ) {
              printf "Invalid syntax in line %d: you can't set variables twice to one file.\n", $idx;
              print "$line\n";
            }
            $is_read_filename = 1;
            $cur_filename = $2;
          }
          else {
            # 2つ目以降のファイル設定の開始

            # 今までのファイル設定をストア
            $replaced{$cur_filename} = %cur_store;

            # バッファのリセット
            $is_read_extension = 0;
            $is_read_env_vars = 0;
            $fst_indent = 0;
            $snd_indent = 0;
            $cur_filename = $2;
            %cur_store = ();
          }
        }
        elsif ( $indent > 0 ) {
          printf "Invalid syntax in line %d: environment variable must have value.\n", $idx;
          print "$line\n";
        }
      }

    }
    elsif ( $line =~ m|(\s*)(\R)| ) {
      # 空行なので無視
      return;
    }
    else {
      printf "Invalid syntax in line %d: unknown syntax.\n", $idx;
      print "$line\n";
    }

  }

  sub write_mode {
    print "write mode is selected.\n";

    my $fname = "breath.yml";
    my $file;
    open($file, $fname) or die("Error read in $fname");
    @lines = <$file>;
    close($file);

    &parse_breath_yml;

    print %replaced;
    print "\n";
  }
}

