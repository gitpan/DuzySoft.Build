#
#  Copyright 2008-02-25 DuzySoft.com, by Duzy Chan
#  All rights reserved by Duzy Chan<duzy@duzy.ws>
#
#  $Id$
#

=head1 NAME

DuzySoft::Build::Configure::Step::ScanSources - Scans sources and dependencies
for an target.

=head1 DESCRIPTION

Each source scanner corrisponds to one building target, and each has it's own
set of Makefile variables, such as CC, CXX, CFLAGS, CXXFLAGS.

=cut

#'

package DuzySoft::Build::Configure::Step::ScanSources;

use strict;
use warnings;

use base q{DuzySoft::Build::Configure::Step};

use Cwd;
use Carp;
use File::Spec;

sub new {
    my ( $class, $args ) = @_;

    $args->{-name} = q{ScanSources} if ! defined $args->{-name};

    my $this = $class->SUPER::new( $args );
    do {
        my $arg_array = sub {
            my $v = shift;
            #return [] if ! defined $v;
            return undef if ! defined $v;
            return $v if ref($v) eq 'ARRAY';
            return [ $v ] if ref($v) eq '';
            return [ $$v ] if ref($v) eq 'SCALAR';
        };
        $this->{recursive} = $args->{-recursive};
        $this->{recursive} = 0 if ! defined $this->{recursive};
        $this->{target} = $args->{-target};
        do { # try to use the current dir name as the target name
            my $dn = getcwd;
            $dn =~ m|[\\/]([^\\/]+)[\\/]?$|;
            $this->{target} = $1;
        } if ! $this->{target};
        $this->{type}   = $args->{-type}; # executable, static, dynamic
        $this->{type}   = 'executable' if ! $this->{type};
        $this->{language} = $args->{-language};
        $this->{language} = q[] if ! $this->{language};
        $this->{options}  = $args->{-options};
        $this->{'implib'} = $args->{'-implib'}; # --out-implib supports
        $this->{libs}   = &$arg_array( $args->{-libs} );
        $this->{lddirs} = &$arg_array( $args->{-lddirs} );
        # valid for cygwin/mingw under Windows, compiles the .rc files
        $this->{resources}= &$arg_array( $args->{-resources} );
        $this->{includes} = &$arg_array( $args->{-includes} );
        $this->{path}     = $args->{-path};
        $this->{path}     = '.' if ! $this->{path};
        $this->{outdir} = $args->{-outdir} ? $args->{-outdir} : 'build';
        $this->{objdir} = $args->{-objdir}; # objects output dir
        $this->{depdir} = $args->{-depdir}; # dependencies output dir
        $this->{bindir} = $args->{-bindir}; # binary output dir
        $this->{libdir} = $args->{-libdir}; # libraries output dir
        #$this->{incdir} = $args->{-incdir}; # include output dir

        # variant support: default, debug, release, etc. , could be empty ''
        $this->{variant} = $args->{-variant};
        $this->{variant} = 'default' if ! $this->{variant};

        # sources(not headers) suffixes, e.g.: cpp cxx CC C c
        $this->{suffixes} = &$arg_array( $args->{-suffixes} );

        # extra objects, extra sources, can be whilcard: *.o, *.cpp
        $this->{extobjs} = &$arg_array( $args->{-extobjs} );
        $this->{extsrcs} = &$arg_array( $args->{-extsrcs} );

        # for unit-tests: 'mode' tells how treat unit-test sources, could be:
        #       * perl-source test
        #       * <any other value>
        $this->{mode}   = $args->{-mode};
    } if defined $args;

    my $check_source_file_type = sub {
        my $filename = shift;
        my $specific_header_suffixes = shift;
        my $specific_source_suffixes = shift;
        my ( $suffix ) = ( $filename =~ m|^.+\.([^\.]+)$| );
        return undef if ! $suffix;
        do {
            my @user_defined_suffixes = @{ $this->{suffixes} };
            my @user_defined_header_suffixes = ();

            # clear the original suffix list, it will be replace later
            $this->{suffixes} = [];

            foreach ( @user_defined_suffixes ) {
                m[^(H:)?([^\.]+)$]; # REVISE: remove 'H:' magic prefix?
                croak "Invalid suffix, may be you add a "
                    . "'.' by mistake: $_" if !$2;
                do {
                    push @{ $this->{suffixes} }, $2;
                    #push @user_defined_source_suffixes, $2;
                } if ! $1;
                push @user_defined_header_suffixes, $2 if $1;
            }

            return 'source' if grep { $suffix eq $_ } @{$this->{suffixes}};
            return 'header' if grep { $suffix eq $_ }
                @user_defined_header_suffixes ;
            return undef;
        } if defined $this->{suffixes} and
            0 < scalar( @{ $this->{suffixes} } );

        return 'source' if grep { $suffix eq $_ }
            @{ $specific_source_suffixes }
            ; #qw{cpp cc cxx};
        return 'header' if grep { $suffix eq $_ }
            @{ $specific_header_suffixes }
            ; #qw{hpp hh hxx};
    };#my $check_source_file_type

    # Initializes the source file name matchers
    $this->{source_filename_matchers} = {
        'c'     => sub {
            # 'source' or 'header'
            return &$check_source_file_type
                ( shift,
                  [ 'h' ],
                  [ 'c' ] );
        },

        'c++'   => sub {
            return &$check_source_file_type
                ( shift,
                  [ 'hpp', 'hh', 'hxx', 'H' ],
                  [ 'cpp', 'cc', 'cxx', 'C' ] );
        },
    };

    bless $this, $class;
    return $this;
}

sub run {
    my ( $this, $config ) = @_;

    if ( ! defined $this->{path} ) {
        $this->{path} = q{.}; #$this->{path} = cwd;
    }
    elsif ( ! -d $this->{path} ) {
        carp q{Directory }.$this->{path}.q{ not exist, scans the cwd.};
        $this->{path} = q{.}; #$this->{path} = cwd;
    }

    my $scan = sub {
        my ( $scan, $path ) = @_;
	my $globPat
            = $path eq q{} || $path eq q{.} || $path eq q{./}
	    ? q{*} : qq{$path/*};
        my @entries = glob $globPat;
        foreach ( @entries ) {
            s|\.[\\/]||;
            next if $this->_add_source_if_valid_source_file( $_ );
            # TODO: should ignore some dirs, such as build output dirs
            &$scan( $scan, qq{$path/$_} ) # do recursive if dir found
                if $this->{recursive} && -d qq{$path/$_};
        }
    };
    &$scan( $scan, $this->{path} );

    # wildcard extra sources and extra objects
    my $wildcard = sub {
        my $arg = shift; return if ! $arg; my @r = ();
        do { my @a = glob( $_ ); push @r, $_ foreach @a; } foreach @{ $arg };
        \@r
    };
    $this->{extsrcs} = &$wildcard( $this->{extsrcs} );
    $this->{extobjs} = &$wildcard( $this->{extobjs} );
    do {
        m[\.([^\.]+?)$]; next if ! $1; my $suf = $1;
        push @{ $this->{suffixes} }, $suf
            if ! grep { $suf eq $_ } @{ $this->{suffixes} };
    } foreach @{ $this->{extsrcs} };

    # type              # target type: static, dynamic or executable
    # language          # e.g. : C, C++
    # suffixes          # used source code(not header) suffixes
    # path              # the location where sources are settled(scan path)
    # outdir            # where the build result will be placed in
    # objdir            # the location where compiled object will be settled
    # depdir            # the location where the dependency files will be settled
    # bindir            # location in which the compiled binary files are settled
    # libdir            # ...
    # lddirs           # search directories for "-l"
    # libs              # dependent linkage
    # includes          # addition include directory
    # resources         # under Windows, .rc file list
    # options           # HASH, a set of Makefile variables: CC, CFLAGS...
    # sources           # HASH, filename of all sources and their dependencies
    # headers           # header list
    # extobjs           # extra object files (.o files)
    # extsrcs           # extra source files (eg: .cpp files)
    # variant           # such as: debug, release, default, etc.
    # mode              # for unit-tests, used to tell how to treat ut source
    my @settings = qw( type
                       language
                       suffixes
                       path
                       outdir
                       objdir
                       depdir
                       bindir
                       libdir
                       implib
                       libs
                       lddirs
                       includes
                       resources
                       options
                       sources
                       headers
                       extobjs
                       extsrcs
                       variant
                       mode
                 );
    my $conf = {};
    $conf->{$_} = $this->{$_} foreach @settings;

    return "Target $this->{target} ignored" if ! $config->add_target(
        -target         => $this->{target},
        -config         => $conf,
    );
    return "Scan finished";
}

sub _calculate_source_code_dependencies {
    my ( $this, $filename ) = @_; # filename is a full path name
    my $denpendencies = [];

    # TODO: calculates the dependencies

    return $denpendencies;
}

sub _add_source_if_valid_source_file {
    my ( $this, $filename ) = @_;
    my ( $suffix ) = ( $filename =~ m|\.([^\.]+?)$| );
    my $language = $this->{language};
    do { # guess language according the filename extension
        if ( $suffix ) {
            my $guess_language = sub {
                my ( $lang, @suffixes ) = @_;
                do {
                    $language = $lang;
                    push @{ $this->{suffixes} }, $suffix # add as a new suffix
                        if ! grep { $suffix eq $_ } @{ $this->{suffixes} };
                    #last;
                } if grep { $suffix eq $_ } @suffixes;
            };

            &$guess_language( 'c++', qw(cpp cxx cc CC) );
            &$guess_language( 'c', qw(c) ) if ! defined $language;

            $this->{language} = $language;
        }
        return 0 if ! $language;
    } if ! $language;

    my $filenameMatcher = $this->{source_filename_matchers}->{$language};
    do {
        #carp "Unknown language '$language'";
        croak "Unknown language '$language'";
        return 0;
    } if ! defined $filenameMatcher;

    my $fileType = &$filenameMatcher( $filename );
    return 0 if ! $fileType;

    do {
        $this->{sources}->{$filename} =
            $this->_calculate_source_code_dependencies( $filename );

        push @{ $this->{suffixes} }, $suffix # add as a new suffix
            if ! grep { $suffix eq $_ } @{ $this->{suffixes} };

        return 1;
    } if $fileType eq 'source';

#     do { # REVISE: headers are unused currently
#         $this->{headers}->{$filename} += 1;
#         return 1;
#     } if $fileType eq 'header';

    return 0;
}

1;

