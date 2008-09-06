#
#  Copyright 2008-02-25 DuzySoft.com, by Duzy Chan
#  All rights reserved by Duzy Chan<duzy@duzy.ws>
#
#  $Id$
#

package DuzySoft::Build::Configure::Step::GenerateMakefiles;

use strict;
use warnings;

use base q{DuzySoft::Build::Configure::Step};

use Carp;
use File::Spec;

sub new {
    my ( $class, $args ) = @_;

    $args->{-name} = q{GenerateMakefiles} if ! defined $args->{-name};

    my $this = $class->SUPER::new( $args );
    $this->{output} = $args->{-output};
    $this->{output} = 'GNUmakefile'
        if ! defined $this->{output} or $this->{output} eq '';

    bless $this, $class;

    $this->_init_variables( $args );

    return $this;
}

sub _init_variables {
    my ( $this, $args ) = @_;

    my %vars = ( # TODO: copy flags from $args
        CC      => 'gcc',
        CFLAGS  => '',
        CXX     => 'g++',
        CXXFLAGS=> '',
        LD      => 'ld',
        LDFLAGS => '',
        LIBS    => '',
        AR      => 'ar',
        ARFLAGS => 'rsv',

        # general commands
        RM      => 'rm',
        MKDIR   => 'mkdir',
    );

    $this->{$_} = $vars{$_} foreach keys %vars;
}

sub run {
    my ( $this, $config ) = @_;
    my $mf;

    #croak "I don't known where to output: $?";
    $this->{output} = q{Makefile} if ! defined $this->{output};

    open $mf, q{>}, $this->{output}
        or die "I can't open the output: $!";

    my $join_array = sub {
        my $arr = shift;
        my $str = shift( @{ $arr } );
        $str = q[] if ! $str;
        do {
            $str .= " \\\n";
            $str .= join '', map { "\t$_ \\\n" } @{ $arr };
            $str =~ s| \\\n$||;
        } if $str && 0 < scalar @{ $arr };
        $str .= "\n" if !( $str =~ m|\n$| );
        $str
    };
    my $target_compile_flags = sub {
        my $target_config = shift;
        my $flags = '';
        my $flag_name = '';
        $flag_name = 'CFLAGS' if $target_config->{language} eq 'c';
        $flag_name = 'CXXFLAGS' if $target_config->{language} eq 'c++';
        $flags .= $target_config->{options}->{$flag_name}
            if $target_config->{options}->{$flag_name};
        $flags .= " \\\n\t-I$_" foreach @{ $target_config->{includes} };
        $flags
    };
    my $target_compiler = sub {
        my $target_config = shift;
        my $str = '';
        if ( $target_config->{language} eq 'c' ) {
            $str = $target_config->{options}->{CC}
                ? $target_config->{options}->{CC}.' -c $(CFLAGS)'
                : '$(COMPILE.c)' ;
        }
        elsif ( $target_config->{language} eq 'c++' ) {
            $str = $target_config->{options}->{CXX}
                ? $target_config->{options}->{CXX}.' -c $(CXXFLAGS)'
                : '$(COMPILE.cpp)' ;
        }
        $str
    };
    my $target_linker = sub {
        my $target_config = shift;
        my ( $linker, $flags );
        if ( $target_config->{type} eq 'static') {
            $linker = $target_config->{options}->{AR};
            $linker = '$(AR)' if ! $linker;
        }
        else {
            # for executable and dynamic
            $linker = $target_config->{options}->{LD};
            do {
                $linker = '$(CC)' if $target_config->{language} eq 'c';
                $linker = '$(CXX)' if $target_config->{language} eq 'c++';
            } if ! $linker && $target_config->{language};
            $linker = '$(LINK.o)' if ! $linker;
        }
        $linker
    };
    my $target_link_flags = sub {
        my $target_config = shift;
        my ( $sflags, $flags ) = ( '', '' );
        if ( $target_config->{type} eq 'static') {
            $sflags = $target_config->{options}->{ARFLAGS};
            $flags .= $sflags if $sflags;
            $flags .= '$(ARFLAGS)' if ! $flags;
        }
        else {
            my $is_dynamic = $target_config->{type} eq 'dynamic';
            $sflags = $target_config->{options}->{LDFLAGS};
            $flags .= $sflags if $sflags;
            $flags = '-shared '.$flags
                if $is_dynamic and ( !$flags or !( $flags =~ m|-shared| ) );
            #do {# guess -x flag if not an known suffix
            #    # gcc -x supports: c c++ assembler none
            #} if $target_config->{type} eq q[unit-tests];
            $target_config->{'implib-dir'} = '';
            do {
                my $implib =
                    $target_config->{libdir}.'/'.$target_config->{'implib'};
                $flags .= " \\\n\t-Wl,--out-implib,$implib";

                my ($v, $d, $f) = File::Spec->splitpath($implib);
                # to generate mkdir command
                $target_config->{'implib-dir'} = "$v$d";

            } if $is_dynamic and $target_config->{'implib'} and $is_dynamic;

            do { # unit-tests: one test per source mode
                $target_config->{mode} = '' if !defined $target_config->{mode};
                if ( $target_config->{mode} eq q[per-source] or
                     $target_config->{mode} eq q[one test per source] ) {
                    $target_config->{mode} = q[per-source];
                    #$flags =~ s/-c//; # get rid of all '-c' flags
                }
            } if $target_config->{type} eq q[unit-tests];

            do { $flags .= " \\\n\t-L$_" if $_; }
                foreach @{ $target_config->{lddirs} };
        }
        $flags
    };
    my $target_dependent_libs = sub {
        my $target_config = shift;
        my $libs = '';
        $libs .= " -l$_" foreach @{ $target_config->{libs} };
        $libs
    };
    my $list_to_per_suffix_objs = sub {
        # convert a list to a per-suffix hash
        #       list:[...] ===> hash:{ suffix => [...] }
        my $list = shift;   $list = [] if ! $list;
        my $hash = {};
        do {
            my ( $pre, $suf ) = ( m[(^.+)\.([^\.]+?)$] );
            next if ! $pre or !$suf;
            $hash->{$suf} = [] if ! $hash->{$suf};
            push @{ $hash->{$suf} }, "$pre.o";
        } foreach sort @{ $list };
        $hash
    };
    my $mf_cmds = sub { # helper to generate action shell command in Makefile
        my ( $str, $break ) = ( '', 0 );
        do {
            my $v = $_;

            do { $break = 1; $str =~ s| \\\n$|\n|; next; } if ! defined $v;
            next if $_ eq[];

            if ( q[ARRAY] eq ref $v ) {
                do { my $t = shift @{ $v }; $str .= "$t\n" if $t; } if $break;
                do { $str .= "\t$_ \\\n" if $_ } foreach @{ $v }; $break = 0; }
            else { $str .= "\t$v \\\n" if $v }
        } foreach @_;
        $str =~ s| \\\n$||;
        $str
    };
    my ( $target_names, $target_sources, $target_objects,
         $target_build_rules, $target_objects_build_rules );
    my $test_targets = '';
    my $dependencies = '';
    my $target_unit_test_build_rules = '';
    my $target_specified_linkers = '';
    my $target_specified_compilers = '';
    my $clean_command = "\$(RM) -v \$(TARGETS)";
    my ( $out_dir, $obj_dir, $dep_dir, $bin_dir, $lib_dir );
    my %dirs = (); # used to help making an unique dir list
    my $calculate_dirs = sub {
        # TODO: uses File::Spec to cat path
        my $name        = shift;
        my $target_config = shift;
        my $variant     = $target_config->{variant};
        $variant = 'default' if ! $variant;

        $out_dir = $target_config->{outdir};
        $obj_dir = $target_config->{objdir};
        $dep_dir = $target_config->{depdir};
        $bin_dir = $target_config->{bindir};
        $lib_dir = $target_config->{libdir};

        $out_dir = 'build' if ! $out_dir;
        $out_dir .= '/'.$name.'/'.$variant;

        $obj_dir = $out_dir.'/objs' if ! $obj_dir;
        $dep_dir = $out_dir.'/deps' if ! $dep_dir;
        $bin_dir = $out_dir.'/bin' if ! $bin_dir;
        $lib_dir = $out_dir.'/lib' if ! $lib_dir;

        $target_config->{outdir} = $out_dir;
        $target_config->{objdir} = $obj_dir;
        $target_config->{depdir} = $dep_dir;
        $target_config->{bindir} = $bin_dir;
        $target_config->{libdir} = $lib_dir;

        $dirs{$out_dir} += 0;
        $dirs{$obj_dir} += 0;
        $dirs{$dep_dir} += 0;
        $dirs{$bin_dir} += 0;
        $dirs{$lib_dir} += 0;
    };

    my $target_redirect_rules = q[];
    foreach my $name ( $config->targets ) {
        my $target_config = $config->get_target_config( $name );
        do { carp "Invalid target config found."; next; }
            if ! defined $target_config;
        do { # validate the target type, should be: executable, dynamic, static
            croak "Invalid target type: '".$target_config->{type}."' ";
            return;
        } if defined $target_config->{type} and
            !grep { $_ eq $target_config->{type} }
                qw( executable dynamic static unit-tests );

        &$calculate_dirs( $name, $target_config );

        $name =~ s| |_|;

        my ( $depts, $to_dir, $oflag ) = ( q[], q[], q[] );
        if ( $target_config->{type} eq q[static] ) {
            $oflag      = q[]; # out-flag helps the linker to name the output
            $to_dir     = $lib_dir; # location to place the output
            $depts      = q[]; # target dependencies
        }
        else {
            $oflag      = q[-o]; # out-flag helps the linker to name the output
            $to_dir     = $bin_dir; # location to place the output
            $depts      = "\$(LIBS.$name) \$(LIBS)"; # target dependencies
        }

        my $is_test_target = $target_config->{type} eq q[unit-tests];

        $target_names           .= "$name ";
        $target_redirect_rules  .= "$name:$to_dir/$name\n";
        do {
            $test_targets       .= " \\\n" if $test_targets;
            $test_targets       .= "\t$to_dir/$name";
        } if $is_test_target;

        $target_config->{extsrcs} = [] if ! $target_config->{extsrcs};
        $target_config->{extobjs} = [] if ! $target_config->{extobjs};

        my @srcs = # sources belongs to the target itself
            sort keys %{ $target_config->{sources} };
        my @srcs_extra = # extra sources specified by the user
            sort @{ $target_config->{extsrcs} };
        my @objs = # objects calculate from @srcs
            sort( map { my $s = $_; $s =~ s/\.[^\.]+$/\.o/; $s } @srcs );
        my @objs_extra = # precompiled extra objects specified by the user
            sort @{ $target_config->{extobjs} };
        my @objs_esrcs = # objects from extra sources, requires compilation
            sort( map { my $s = $_; $s =~ s/\.[^\.]+$/\.o/; $s } @srcs_extra );

        my $per_suffix_objs = &$list_to_per_suffix_objs( \@srcs );
        my $per_suffix_objs_esrcs = &$list_to_per_suffix_objs( \@srcs_extra );

        # append source Makefile variables
        $target_sources # sources belongs to target itself
            .= "SRCS.$name = ".&$join_array( \@srcs );
        $target_sources # extra sources specified by user
            .= "SRCS.EXTRA.$name = ".&$join_array( \@srcs_extra );

        # append objects Makefile variables
        $target_objects # append objects belongs only to target itselft
            .= "OBJS.$name = ".&$join_array( \@objs );
        $target_objects # append per-suffix objects: OBJS.suffix.$name
            .= "OBJS.$_.$name = ".&$join_array( $per_suffix_objs->{$_} )
            foreach keys %{ $per_suffix_objs } ;
        $target_objects # append extra objects, which needs no compilation
            .= "OBJS.EXTRA.$name = ".&$join_array( \@objs_extra );
        $target_objects # append extra-sources' objects, needs compiliation
            .= "OBJS.ESRCS.$name = ".&$join_array( \@objs_esrcs );
        $target_objects # append per-suffix objects: OBJS.suffix.$name
            .= "OBJS.ESRCS.$_.$name = "
            . &$join_array( $per_suffix_objs_esrcs->{$_} )
            foreach keys %{ $per_suffix_objs_esrcs } ;

        # append compiler relative Makefile variables
        my $compiler = &$target_compiler( $target_config );
        croak "Can't find compiler for target: $name"
            if !$compiler;
        $target_specified_compilers
            .= "CFLAGS.$name = ".&$target_compile_flags( $target_config )."\n"
            .= "COMPILE.$name = $compiler \$(CFLAGS.$name)\n";

        # append linker relative Makefile variables
        my $linker = &$target_linker( $target_config );
        $target_specified_linkers
            .= "LIBS.$name = ".&$target_dependent_libs( $target_config )."\n"
            .= "LFLAGS.$name = ".&$target_link_flags( $target_config )."\n"
            .= "LINK.$name = $linker \$(LFLAGS.$name)\n" ;

        # append resources(.rc files) relative Makefile variables
        my ($resource_objs, $resource_objs_d, $resource_objs_v) = ('', '', '');
        do {
            $resource_objs .= "$_.o" foreach @{ $target_config->{resources} };
            $resource_objs_d = "OBJS.rc.$name = $resource_objs\n";
            $resource_objs_v = "\$(OBJS.rc.$name:%=$obj_dir/%)";
        } if ( $target_config->{resources} and
                   ref( $target_config->{resources} ) eq 'ARRAY'
               );

        my $is_unit_test_per_source = (
            $is_test_target and $target_config->{mode} eq q[per-source] );
        my $implib_dir = $target_config->{'implib-dir'};
        $implib_dir = q[] if $is_test_target;

        $target_build_rules
            .= "$resource_objs_d"
            . (
                $is_unit_test_per_source
                ? "$to_dir/$name: \$(OBJS.$name:%.o=$to_dir/%.test)\n"
                : "$to_dir/$name: \$(OBJS.$name:%=$obj_dir/%) \\\n"
                  . "    \$(OBJS.ESRCS.$name:%=$obj_dir/extsrcs/%) "
                      . "\$(OBJS.EXTRA.$name) "
                      . "$resource_objs_v\n"
              )
            . &$mf_cmds(
                '@tmpvar_target_dirname=`dirname $@`;',
                #'$(call prepare-path,$$$$tmpvar_target_dirname);',
                '$(call prepare-path,$$tmpvar_target_dirname);',
                $implib_dir ? [
                    # dynamic:
                    #   'mkdir' command for --out-implib output
                    '$(call prepare-path,'.$implib_dir.');',
                ] : '' ,
                $is_unit_test_per_source ? [
                    # unit-tests:
                    #   generate 'tests' script for 'per-source' mode
                    'echo "#!bash" > $@;',
                    'for test in $^; do',
                    '  if [ -f $$test ]; then',
                    '    echo "./$$test " >> $@;',
                    '  else',
                    '    echo "echo NO: $$test " >> $@;',
                    '  fi;',
                    'done;',
                ] : [
                    # executible, dynamic, static
                    #   linking
                    'echo',
                    "\$(LINK.$name) $oflag \$@ \$(OBJS.$name:%=$obj_dir/%)",
                    "    \$(OBJS.ESRCS.$name:%=$obj_dir/extsrcs/%)"
                        . " \$(OBJS.EXTRA.$name)"
                        . " $resource_objs_v $depts;",
                    "\$(LINK.$name) $oflag \$@ \$(OBJS.$name:%=$obj_dir/%)",
                    "    \$(OBJS.ESRCS.$name:%=$obj_dir/extsrcs/%)"
                        . " \$(OBJS.EXTRA.$name)"
                        . " $resource_objs_v $depts;",
                  ] ,
                undef,
                $is_unit_test_per_source ? [
                    # unit-tests:
                    #   make each unit test
                    "\$(OBJS.$name:%.o=$to_dir/%.test): \\\n"
                    . "    $to_dir/%.test:$obj_dir/%.o \\\n"
                    . "    \$(OBJS.ESRCS.$name:%=$obj_dir/extsrcs/%)"
                        . " \$(OBJS.EXTRA.$name)"
                        . " $resource_objs_v",
                    '@tmpvar_target_dirname=`dirname $@`;',
                    #'$(call prepare-path,$$$$tmpvar_target_dirname);',
                    '$(call prepare-path,$$tmpvar_target_dirname);',
                    'echo',
                    "    \$(LINK.$name) $oflag \$\@",
                    "    \$^",
                    "    $depts;",
                    "if \$(LINK.$name) $oflag \$\@",
                    "    \$^",
                    "    $depts; then",
                    '  true;',
                    'else',
                    '  echo "$@:0:  FAILED";',
                    '  echo;',
                    '  false;',
                    'fi;',
                ] : '' ,
                undef,
                $resource_objs_v ? [
                    # executible, dynamic:
                    #   compile resources( .rc files )
                    "$resource_objs_v:$obj_dir/%.rc.o:%.rc",
                    '@tmpvar_target_dirname=`dirname $@`;',
                    #'$(call prepare-path,$$$$tmpvar_target_dirname);',
                    '$(call prepare-path,$$tmpvar_target_dirname);',
                    'echo ',
                    '$(WINDRES) -o $@ -i $<;',
                    '$(WINDRES) -o $@ -i $<;',
                ] : '' ,
            )
            ;

        # .o compile command declaration
        $target_objects_build_rules
            .= "OBJS.COMPILE.$name = \\\n" # object compilation command
            . &$mf_cmds(
                'tmpvar_target_dirname=`dirname $@`;',
                #'$(call prepare-path,$$$$tmpvar_target_dirname);',
                '$(call prepare-path,$$tmpvar_target_dirname);',
                'echo',
                "\$(COMPILE.$name) -o \$@ \$<;",
                "\$(COMPILE.$name) -o \$@ \$<;",
            )."\n"
            . "MAKEDEPEND.$name = \\\n" # dependency generation command
            . &$mf_cmds(
                'tmpvar_target_dirname=`dirname $@`;',
                #'$(call prepare-path,$$$$tmpvar_target_dirname);',
                '$(call prepare-path,$$tmpvar_target_dirname);',
                "echo Generate \$@ ...;",
                "\$(COMPILE.$name) -MM -MP -MF \$@ ",
                "  -MT \$(patsubst %.\$1,$obj_dir/%.o,\$<) \$<;",
            )."\n"
            ;
        # per-suffix compile rules for sources
        $target_objects_build_rules
            # Objects compilation rule
            .= "\$(OBJS.$_.$name:%=$obj_dir/%):$obj_dir/%.o:%.$_\n"
            . "\t\@\$(OBJS.COMPILE.$name)\n"
            # Dependencies generation rule
            . "\$(OBJS.$_.$name:%.o=$dep_dir/%.d):$dep_dir/%.d:%.$_\n"
            . "\t\@\$(call MAKEDEPEND.$name,$_)\n"
                foreach keys %{ $per_suffix_objs };
        $target_objects_build_rules
            .= "\$(OBJS.ESRCS.$_.$name:%=$obj_dir/extsrcs/%): \\\n"
                . "    $obj_dir/extsrcs/%.o:%.$_\n"
            . "\t\@\$(OBJS.COMPILE.$name)\n"
            . "\$(OBJS.ESRCS.$_.$name:%.o=$dep_dir/extsrcs/%.d): \\\n"
                . "    $dep_dir/extsrcs/%.d:%.$_\n"
            . "\t\@\$(call MAKEDEPEND.$name,$_)\n"
                foreach keys %{ $per_suffix_objs_esrcs };
        $dependencies
            .= "\\\n"
            . "\t\$(OBJS.$name:%.o=$dep_dir/%.d) "
            . "\\\n"
            . "\t\$(OBJS.ESRCS.$name:%.o=$dep_dir/extsrcs/%.d) "
            ;

        $clean_command .= " \\\n\t\$(OBJS.$name:%=$obj_dir/%)";
        $clean_command .= " \\\n\t\$(OBJS.ESRCS.$name:%=$obj_dir/extsrcs/%)";
        $clean_command .= " \\\n\t$resource_objs_v " if $resource_objs_v;
    }
    #$clean_command =~ s| \\\n$||;
    $target_sources =~ s|\n$||;
    $target_objects =~ s|\n$||;
    $target_build_rules         =~ s|\n$||;
    $target_objects_build_rules =~ s|\n$||;

    my @dirs = sort keys %dirs;
    my $dirs_build_rule = "DIRS = ".&$join_array( \@dirs )
        . '$(DIRS):%:' . "\n"
        . &$mf_cmds(
            '$(MKDIR) $@',
        )
        ;

    print $mf <<END_OF_MAKEFILE;
#-*- mode: GNUmakefile -*-
# WARNING: Donot edit this file, it's generated by DuzySoft::Build system,
#          any changes you made will be overwrite.
#
#  By Duzy Chan, DuzySoft.com
#
CC = $this->{CC}
CFLAGS = $this->{CFLAGS}
CXX = $this->{CXX}
CXXFLAGS = $this->{CXXFLAGS}
WINDRES = windres
LD = $this->{LD}
LDFLAGS = $this->{LDFLAGS}
LIBS = $this->{LIBS}
AR = $this->{AR}
ARFLAGS = $this->{ARFLAGS}
RM = $this->{RM} -f
MKDIR = $this->{MKDIR} -p
COPY = cp -rvu

# \$(call prepare-path,path)
define prepare-path
if [ -f \$1 ] ; then \\
  echo "Error: \$1 is a existed file, can't create as dir!"; \\
  exit 0; \\
fi; \\
if [ ! -d \$1 ]; then \\
  echo \$(MKDIR) \$1 ; \\
  \$(MKDIR) \$1 ; \\
fi
endef

$target_specified_compilers
$target_specified_linkers
TARGETS = $target_names
TEST_TARGETS = $test_targets

$target_sources

$target_objects

STAGE_DIR = stage
MAKECOMMANDS = all clean help
PHONY = \$(MAKECOMMANDS) \$(TARGETS)

all: \$(TARGETS)

help:
\t\@echo "Possible make options are:"
\t\@echo "    commands: \$(MAKECOMMANDS)"
\t\@echo "    targets: \$(TARGETS)"

clean:\n\t\@$clean_command

run-tests: \$(TEST_TARGETS)
\t\@for test in \$(TEST_TARGETS); do \\
\t  ./\$\$test ; echo ; \\
\tdone;

$target_redirect_rules
$target_build_rules
$target_objects_build_rules
$target_unit_test_build_rules

dependencies = $dependencies
include \$(dependencies)

$dirs_build_rule

PHONY += stage
stage: $target_names $test_targets
\t\$(MKDIR) \$(STAGE_DIR)
\t\$(COPY) \$^ \$(STAGE_DIR)

.PHONY: \$(PHONY)

END_OF_MAKEFILE

    close $mf;

    return "Makefile wrote";
}

1;
