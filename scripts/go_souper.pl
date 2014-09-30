#!/usr/bin/perl

use strict;
use warnings;

my $SOUPER_BASE = "/home/yangchen/Programs/souper";
my $SOUPER_BIN = "$SOUPER_BASE/build/souper";
my $CLANG_BIN = "$SOUPER_BASE/third_party/llvm/Debug/bin/clang";
my $LLVM_OPT = "$SOUPER_BASE/third_party/llvm/Debug/bin/opt";
my $LLVM_DIS = "$SOUPER_BASE/third_party/llvm/Debug/bin/llvm-dis";
my $SOLVER_BASE = "/home/yangchen/tool_installations";
my $APPLY_MODE = "none";
my $SAVE_SOLVER_TEMP = "-keep-solver-inputs -dump-klee-exprs";
my $CLANG_OPT_LEVEL = "-O0";

my %SOLVERS = (
  "stp" => ["$SOLVER_BASE/bin/stp", "LD_LIBRARY_PATH=$SOLVER_BASE/lib "],
  "z3" => ["$SOLVER_BASE/bin/z3", ""]
);

sub runit($) {
  my $cmd = shift;
  print "$cmd\n";
  system "$cmd";
  if ($? == -1) {
    die "FAILED: system '$cmd': $?";
  }
  elsif ($? & 127) {
    die "cmd died with signal (" . ($?&127). ") with coredump";
  }
  elsif ($? & 127) {
    die "cmd died with signal (" . ($?&128). ") without coredump";
  }
  my $exit_value  = $? >> 8;
  return $exit_value;
}

sub abort_if_fail($) {
  my ($cmd) = @_;
  die "failed to exec: $cmd" if (runit($cmd));
}

my $usage = '
go_souper.pl --solver=[z3|stp] --apply=[none|clang|opt] cfile|bc_file
where:
  * the default value for solver is z3
  * the default apply mode is none, which means that we will not
    let souper to modify the bitcode and apply the missed optimization.
    --apply=clang: invoke souper through clang.
    --apply=opt: invoke souper with opt
  * --no-save-solver-temp: do not pass -keep-solver-inputs -dump-klee-exprs to souper
  * --opt-level=[O0|O1|O2|O3|Os]: default is O0
';

sub go($$) {
  my ($cfile, $solver) = @_;

  my $solver_config = $SOLVERS{$solver};
  die "unsupported solver:$solver" unless (defined $solver_config);
  my $solver_bin = @$solver_config[0];
  my $prefix = @$solver_config[1];

  if ($APPLY_MODE eq "clang") {
    abort_if_fail("$prefix$CLANG_BIN $CLANG_OPT_LEVEL -mllvm -debug-souper -Xclang -load -Xclang $SOUPER_BASE/build/libsouperPass.so -mllvm -$solver-path=$solver_bin -c $cfile -S -o - -emit-llvm"); 
  }
  else {
    my $bc_file = $cfile;
    my $do_generate_bc = 1;
    if ($cfile =~ m/\.c$/) {
      $bc_file =~ s/\.c$/\.bc/;
    }
    elsif ($cfile =~ m/\.i$/) {
      $bc_file =~ s/\.i$/\.bc/;
    }
    elsif ($cfile =~ m/\.cpp$/) {
      $bc_file =~ s/\.cpp$/\.bc/;
    }
    elsif ($cfile =~ m/\.cc$/) {
      $bc_file =~ s/\.cc$/\.bc/;
    }
    elsif ($cfile =~ m/\.ii$/) {
      $bc_file =~ s/\.ii$/\.bc/;
    }
    elsif ($cfile =~ m/\.bc$/) {
      # we are start from a bc file
      $do_generate_bc = 0;
    }
    else {
      die "Invalid file: $cfile";
    }
    if ($do_generate_bc) {
      abort_if_fail("$CLANG_BIN $CLANG_OPT_LEVEL -emit-llvm -c -o $bc_file $cfile");
      abort_if_fail("$LLVM_DIS $bc_file");
    }
    abort_if_fail("$prefix$SOUPER_BIN $SAVE_SOLVER_TEMP -$solver-path=$solver_bin $bc_file");

    if ($APPLY_MODE eq "opt") {
      my $opt_bc_file = $cfile;
      $opt_bc_file =~ s/\.c$/\.opt\.bc/;
      abort_if_fail("$LLVM_OPT -load $SOUPER_BASE/build/libsouperPass.so -$solver-path=$solver_bin -o $opt_bc_file $bc_file");
    }
    elsif ($APPLY_MODE eq "none") {
      # nothing to do
    }
    else {
      die "invalid apply mode:$APPLY_MODE"
    }
  }
  print "\n**************\nAll Done!\n";
}

sub check_prereqs($) {
}

sub main() {
  my $opt;
  my @unused = ();
  my $cfile;
  my $solver = "z3";

  while(defined ($opt = shift @ARGV)) {
    if ($opt =~ m/^--(.+)=(.+)$/) {
      if ($1 eq "solver") {
        $solver = $2;
      }
      elsif ($1 eq "apply") {
        $APPLY_MODE = $2;
      }
      elsif ($1 eq "opt-level") {
        $CLANG_OPT_LEVEL = "-$2";
      }
      else {
        die "Invalid option [$opt]";
      }
    }
    elsif ($opt =~ m/^--(.+)$/) {
      if ($1 eq "help") {
        print "$usage\n";
        exit 0;
      }
      elsif ($1 eq "no-save-solver-temp") {
        $SAVE_SOLVER_TEMP = "";
      }
      else {
        die "Invalid option [$opt]";
      }
    }
    else {
      push @unused, $opt;
    }
  }

  if (@unused != 1) {
    die $usage;
  }
  $cfile = $unused[0];
  go($cfile, $solver);
}

main();

