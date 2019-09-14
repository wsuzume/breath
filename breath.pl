use strict;
use warnings;

use Cwd 'getcwd';
use File::Find;
use Data::Dumper;

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

  if ( -e "breath.yml" ) {
    print "Error: breath.yml already exists.\n";
    exit(1);
  }

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
      push(@whole_env, "  env_vars:\n");
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
  my $ext = $_[0];

  if ( $ext =~ m|^(\.)([\w.\-]+)$| ) {
    return (1, $ext);
  }
  elsif ( $ext =~ m|^([\w.\-]+)$| ) {
    return (1, "." . $ext);
  }
  
  return (0, "");
}

sub validate_filename {
}

{
  # 設定ファイルを読み込んだときに格納しておくバッファ
  my @lines;

  # 書き込みを許可できないエラーが発生した
  my $error_occured;

  # 置換した結果を格納しておくバッファ
  my %replaced;

  # extension: と env_vars: に相当するインデント
  # 各ファイルの単位でこのインデントのルールが崩れるとエラー。
  my $fst_indent;

  # 「環境変数：値」の行に相当するインデント
  # 各ファイルの単位でこのインデントのルールが崩れるとエラー。
  my $snd_indent;

  sub check_fst_indent {
    my $indent = $_[0];

    if ( $indent == 0 ) {
      # 1stインデントが来るべきところにインデントがないのでエラー
      $error_occured = 1;
      return 0;
    }

    if ( $fst_indent == 0 ) {
      # 初回なので登録
      $fst_indent = $indent;
    }
    elsif ( $fst_indent != $indent ) {
      # 登録されているインデントと違うのでエラー
      $error_occured = 1;
      return 0;
    }

    if ( $snd_indent != 0 and $fst_indent <= $snd_indent ) {
      # 2ndインデントが既に読み取り済みで
      # 1stインデントが2ndインデントより深いか同じなのはエラー
      $error_occured = 1;
      return 0;
    }

    return 1;
  }

  sub check_snd_indent {
    my $indent = $_[0];

    if ( $fst_indent == 0 ) {
      # 1stインデントよりも先に2ndインデントが来るのはエラー
      $error_occured = 1;
      return 0;
    }

    if ( $snd_indent == 0 ) {
      # 初回なので登録
      $snd_indent = $indent;
    }
    elsif ( $snd_indent != $indent ) {
      # 登録されているインデントと違うのでエラー
      $error_occured = 1;
      return 0;
    }

    if ( $snd_indent <= $fst_indent ) {
      # 2ndインデントが1stインデントよりも浅いか同じなのでエラー
      $error_occured = 1;
      return 0;
    }

    return 1;
  }


  # filename を読んだ時点で 1 。これが 1 のときに EOF か次の filename を読むと次のファイル。
  # これが 0 のときに is_read_extension か is_read_env_vars が 1 になるとエラー。
  my $is_read_filename;
  # 今読んでいるファイルの名前
  my $cur_filename;
  # 今読んでいるファイルの設定
  my %cur_store;
  # 今読んでいるファイルの環境変数
  my %cur_env_vars;

  # extension: を読んだ時点で 1 。これが 1 のときに「環境変数: 値」の行を読むとエラー。
  # これが 1 のときに次の filename が来るのは別にOK。
  # 次の filename か env_vars: が来ると 0 になる。
  my $is_read_extension;

  # env_vars: を読んだ時点で 1 。これが 1 のときのみ「環境変数：値」の行を読んでいい。
  # 次の filename か extension: が来ると 0 になる。 
  my $is_read_env_vars;  

  sub parse_breath_yml {
    %replaced = ();

    $error_occured = 0;

    $is_read_filename = 0;
    $is_read_extension = 0;
    $is_read_env_vars = 0;
    $fst_indent = 0;
    $snd_indent = 0;

    %cur_store = ();
    %cur_env_vars = ();

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
      my %env_vars_buf = %cur_env_vars;
      $cur_store{"env_vars"} = \%env_vars_buf;
      my %store_buf = %cur_store;
      $replaced{$cur_filename} = \%store_buf;
      return;
    }

    print $line;
    if ( $line =~ m|^(\s*)(\w+)(\s*)(:)(\s*)([\S]+)(\s*)(\R)$| ) {
      # パターン 1
      # 拡張子または環境変数
      print "pattern 1\n";

      my $indent = length $1;

      if ( $2 eq "extension" ) {
        if ( $is_read_extension ) {
          $error_occured = 1;
          printf "Invalid syntax in line %d: 'extension:' detected twice in one file.\n", $idx;
          print "$line\n";
        }

        if ( ! &check_fst_indent($indent) ) {
          $error_occured = 1;
          printf "Indent error in line %d.\n", $idx;
          print "$line\n";
        }

        my $ext = $6;
        my ($ret, $valid_ext) = &validate_extension($ext);
        if ( !$ret ) {
          $error_occured = 1;
          printf "Invalid extension in line %d: %s\n", $idx, $valid_ext;
          print "$line\n";
        }
        $cur_store{"extension"} = $valid_ext;

        # ステートの更新
        $is_read_extension = 1;
        $is_read_env_vars = 0;
      }
      elsif ( $2 eq "env_vars" ) {
        $error_occured = 1;
        printf "Invalid syntax in line %d: 'env_vars' must not have value.\n", $idx;
        print "$line\n";
      }
      else {
        print "here\n";
        # 環境変数
        if ( $is_read_extension ) {
          $error_occured = 1;
          printf "Invalid syntax in line %d: 'extension' must not have leaves.\n", $idx;
          print "$line\n";
        }

        if ( ! $is_read_env_vars ) {
          $error_occured = 1;
          printf "Invalid syntax in line %d: unknown syntax (no 'env_vars:' but environment variable seems starting).\n", $idx;
          print "$line\n";
        }

        if ( ! &check_snd_indent($indent) ) {
          $error_occured = 1;
          printf "Indent error in line %d.\n", $idx;
          print "$line\n";
        }

        if ( exists($cur_env_vars{$2}) ) {
          $error_occured = 1;
          printf "Invalid syntax in line %d: you can't set same variable twice to one file.\n", $idx;
          print "$line\n";
        }

        print "HERE!!!!\n";
        $cur_env_vars{$2} = $6;
      }
    }
    elsif ( $line =~ m|^(\s*)([\w/\.\-]+)(\s*)(:)(\s*)(\R)$| ) {
      # パターン 2
      print "pattern 2\n";

      my $indent = length $1;

      if ( $2 eq "extension" ) {
        $error_occured = 1;
        printf "Invalid syntax in line %d: extension must have value.\n", $idx;
        print "$line\n";
      }
      elsif ( $2 eq "env_vars" ) {
        if ( !check_fst_indent($indent) ) {
          $error_occured = 1;
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
              $error_occured = 1;
              printf "Invalid syntax in line %d: you can't set variables twice to one file.\n", $idx;
              print "$line\n";
            }
            $is_read_filename = 1;
            $cur_filename = $2;
          }
          else {
            # 2つ目以降のファイル設定の開始

            # 今までのファイル設定をストア
            my %env_vars_buf = %cur_env_vars;
            $cur_store{"env_vars"} = \%env_vars_buf;
            my %store_buf = %cur_store;
            $replaced{$cur_filename} = \%store_buf;

            # バッファのリセット
            $is_read_extension = 0;
            $is_read_env_vars = 0;
            $fst_indent = 0;
            $snd_indent = 0;
            $cur_filename = $2;
            %cur_store = ();
            %cur_env_vars = ();
          }
        }
        elsif ( $indent > 0 ) {
          $error_occured = 1;
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
      $error_occured = 1;
      printf "Invalid syntax in line %d: unknown syntax.\n", $idx;
      print "$line\n";
    }

  }

  sub dump_replaced {
    foreach my $key (keys %replaced) {
      print "$key\n";
    }

    print (Dumper %replaced);
  }

  sub write_breath {
    foreach my $fname (keys %replaced) {
      #print "$fname\n";
      #print (Dumper $replaced{$fname});
      my $new_fname;
      if ( $fname =~ m|^([\w/\.\-]+)(.breath)$| ) {
        if ( exists($replaced{$fname}{"extension"}) ) {
          $new_fname = $1 . $replaced{$fname}{"extension"};
          print "$new_fname\n";
        }
        else {
          $new_fname = $1;
          print "$new_fname\n";
        }
      }
      else {
        if ( exists($replaced{$fname}{"extension"}) ) {
          $new_fname = $fname . $replaced{$fname}{"extension"};
          print "$new_fname\n";
        }
        else {
          $error_occured = 1;
          print "Error : cannot determine new file name.\n";
        }
      }

      my @buffer = ();
      if ( exists($replaced{$fname}{"env_vars"}) ) {
        my $file;
        open($file, $fname);
        my @content = <$file>;
        close($file);

        foreach my $line (@content) {
          #print $line;
          while ( $line =~ m|(\{\{\{)(.+?)(\}\}\})|g ) {
            print "seek", $2. "\n";
            if ( exists($replaced{$fname}{"env_vars"}{$2}) ) {
              # ここでもしも $replaced{$fname}{"env_vars"}{$2} が {{{ hoge }}} みたいな文字列だと
              # 無限ループになるので breath.yml の読み込みアルゴリズムとの整合性に注意すること。
              $line = $` . $replaced{$fname}{"env_vars"}{$2} . $';
            }
          }
          #print "-> $line";
          push(@buffer, $line);
        }
      }

      my $new_file;
      open($new_file, "> $new_fname");
      print $new_file @buffer;
      close($new_file);
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

    if ( $error_occured ) {
      print "Error: parse failed.\n";
      exit(1);
    }

    #print %replaced;
    #print "\n";

    &dump_replaced;

    print "---------------------\n";
    &write_breath;
  }
}

