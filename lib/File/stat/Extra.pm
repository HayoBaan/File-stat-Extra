package File::stat::Extra;
use strict;
use warnings;
use warnings::register;

use 5.006;

# ABSTRACT: An extension of the File::stat module, provides additional methods.
# VERSION

=for test_synopsis
my ($st, $file);

=head1 SYNOPSIS

  use File::stat::Extra;

  $st = lstat($file) or die "No $file: $!";

  if ($st->isLink) {
      print "$file is a symbolic link";
  }

  if (-x $st) {
      print "$file is executable";
  }

  use Fcntl 'S_IRUSR';
  if ( $st->cando(S_IRUSR, 1) ) {
      print "My effective uid can read $file";
  }

  if ($st == stat($file)) {
      printf "%s and $file are the same", $st->file;
  }

=head1 DESCRIPTION

This module's default exports override the core stat() and lstat()
functions, replacing them with versions that return
C<File::stat::Extra> objects when called in scalar context. In list
context the same 13 item list is returned as with the original C<stat>
and C<lstat> functions.

C<File::stat::Extra> is an extension of the L<File::stat>
module.

=for :list
* Returns non-object result in list context.
* You can now pass in bare file handles to C<stat> and C<lstat> under C<use strict>.
* File tests C<-t> C<-T>, and C<-B> have been implemented too.
* Convenience functions C<filetype> and C<permissions> for direct access to filetype and permission parts of the mode field.
* Named access to common file tests (C<isRegular> / C<isFile>, C<isDir>, C<isLink>, C<isBlock>, C<isChar>, C<isFIFO> / C<isPipe>, C<isSocket>).
* Access to the name of the file / file handle used for the stat (C<file>, C<abs_file> / C<target>).

=head1 SEE ALSO

=for :list
* L<File::stat> for the module for which C<File::stat::Extra> is the extension.
* L<stat> and L<lstat> for the original C<stat> and C<lstat> functions.

=head1 COMPATIBILITY

As with L<File::stat>, you can no longer use the implicit C<$_> or the
special filehandle C<_> with this module's versions of C<stat> and
C<lstat>.

Currently C<File::stat::Extra> only provides an object interface, the
L<File::stat> C<$st_*> variables and C<st_cando> funtion are not
available. This may change in a future version of this module.

=head1 WARNINGS

When a file (handle) can not be (l)stat-ed, a warning C<Unable to
stat: %s>. To disable this warning, specify

    no warnings "File::stat::Extra";

The following warnings are inhereted from C<File::stat>, these can all
be disabled with

    no warnings "File::stat";

=over 4

=item File::stat ignores use filetest 'access'

You have tried to use one of the C<-rwxRWX> filetests with C<use
filetest 'access'> in effect. C<File::stat> will ignore the pragma, and
just use the information in the C<mode> member as usual.

=item File::stat ignores VMS ACLs

VMS systems have a permissions structure that cannot be completely
represented in a stat buffer, and unlike on other systems the builtin
filetest operators respect this. The C<File::stat> overloads, however,
do not, since the information required is not available.

=back

=cut

# Note: we are not defining File::stat::Extra as a subclass of File::stat
# as we need to add an additional field and can not rely on the fact that
# File::stat will always be implemented as an array (struct).

our @ISA = qw(Exporter);
our @EXPORT = qw(stat lstat);

use File::stat ();
use File::Spec ();
use Cwd ();
use Fcntl ();

require Carp;
$Carp::Internal{ (__PACKAGE__) }++; # To get warnings reported at correct caller level

=func stat( I<FILEHANDLE> )

=func stat( I<DIRHANDLE> )

=func stat( I<EXPR> )

=func lstat( I<FILEHANDLE> )

=func lstat( I<DIRHANDLE> )

=func lstat( I<EXPR> )

When called in list context, these functions behave as the original
C<stat> and C<lstat> functions, returning the 13 element C<stat> list.
When called in scalar context, a C<File::stat::Extra> object is
returned with the methods as outlined below.

=cut

# Runs stat or lstat on "file"
sub __stat_lstat {
    my $func = shift;
    my $file = shift;

    return $func eq 'lstat' ? CORE::lstat($file) : CORE::stat($file);
}

# Wrapper around stat/lstat, handles passing of file as a bare handle too
sub _stat_lstat {
    my $func = shift;
    my $file = shift;

    my @stat = __stat_lstat($func, $file);

    if (@stat) {
        # We have a file, so make it absolute (NOT resolving the symlinks)
        $file = File::Spec->rel2abs($file) if !ref $file;
    } else {
        # Try again, interpretting $file as handle
        no strict 'refs'; ## no critic (TestingAndDebugging::ProhibitNoStrict)
        local $! = undef;
        require Symbol;
        my $fh = \*{ Symbol::qualify($file, caller(1)) };
        if (defined fileno $fh) {
            @stat = __stat_lstat($func, $fh);
        }
        if (!@stat) {
            warnings::warnif("Unable to stat: $file");
            return;
        }
        # We have a (valid) file handle, so we make file point to it
        $file = $fh;
    }

    if (wantarray) {
        return @stat;
    } else {
        return bless [ File::stat::populate(@stat), $file ], 'File::stat::Extra';
    }
}

sub stat(*) { ## no critic (Subroutines::ProhibitSubroutinePrototypes)
    return _stat_lstat('stat', shift);
}

sub lstat(*) { ## no critic (Subroutines::ProhibitSubroutinePrototypes)
    return _stat_lstat('lstat', shift);
}

=method dev

=method ino

=method mode

=method nlink

=method uid

=method gid

=method rdev

=method size

=method atime

=method mtime

=method ctime

=method blksize

=method blocks

These methods provide named acced to the same fields in the original
C<stat> result. Just like the original L<File::stat>.

=method cando( I<ACCESS>, I<EFFECTIVE> )

Interprets the C<mode>, C<uid> and C<gid> fields, and returns whether
or not the current process would be allowed the specified access.

I<ACCESS> is one of C<S_IRUSR>, C<S_IWUSR> or C<S_IXUSR> from the
L<Fcntl|Fcntl> module, and I<EFFECTIVE> indicates whether to use
effective (true) or real (false) ids.

=cut

BEGIN {
    no strict 'refs'; ## no critic (TestingAndDebugging::ProhibitNoStrict)

    # Define the main field accessors and the cando method using the File::stat version
    for my $f (qw(dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks cando)) {
        *{$f} = sub { $_[0][0]->$f; }
    }

=for Pod::Coverage S_ISBLK S_ISCHR S_ISDIR S_ISFIFO S_ISLNK S_ISREG S_ISSOCK

=cut

    # Create own versions of these functions as they will croak on use
    # if the platform doesn't define them. It's important to avoid
    # inflicting that on the user.
    # Note: to stay (more) version independent, we do not rely on the
    # implementation in File::stat, but rather recreate here.
    for (qw(BLK CHR DIR LNK REG SOCK)) {
        *{"S_IS$_"} = defined eval { &{"Fcntl::S_IF$_"} } ? \&{"Fcntl::S_IS$_"} : sub { '' };
    }
    # FIFO flag and macro don't quite follow the S_IF/S_IS pattern above
    *{'S_ISFIFO'} = defined &Fcntl::S_IFIFO ? \&Fcntl::S_ISFIFO : sub { '' };
}

=method file

Returns the full path to the original file (or the filehandle) on which
C<stat> or C<lstat> was called.

Note: Symlinks are not resolved. And, like C<rel2abs>, neither are
C<x/../y> constructs. Use the C<abs_file> / C<target> methods to
resolve these too.

=cut

sub file {
    return $_[0][1];
}

=method abs_file

=method target

Returns the absolute path of the file. In case of a file handle, this is returned unaltered.

=cut

sub abs_file {
    return ref $_[0]->file ? $_[0]->file : Cwd::abs_path($_[0]->file);
}

*target = *abs_file;

=method permissions

Returns just the permissions (including setuid/setgid/sticky bits) of the C<mode> stat field.

=cut

sub permissions {
    return Fcntl::S_IMODE($_[0]->mode);
}

=method filetype

Returns just the filetype of the C<mode> stat field.

=cut

sub filetype {
    return Fcntl::S_IFMT($_[0]->mode);
}

=method isFile

=method isRegular

Returns true if the file is a regular file (same as -f file test).

=cut

sub isFile {
    return S_ISREG($_[0]->mode);
}

*isRegular = *isFile;

=method isDir

Returns true if the file is a directory (same as -d file test).

=cut

sub isDir {
    return S_ISDIR($_[0]->mode);
}

=method isLink

Returns true if the file is a symbolic link (same as -l file test).

Note: Only relevant when C<lstat> was used!

=cut

sub isLink {
    return S_ISLNK($_[0]->mode);
}

=method isBlock

Returns true if the file is a block special file (same as -b file test).

=cut

sub isBlock {
    return S_ISBLK($_[0]->mode);
}

=method isChar

Returns true if the file is a character special file (same as -c file test).

=cut

sub isChar {
    return S_ISCHR($_[0]->mode);
}

=method isFIFO

=method isPipe

Returns true if the file is a FIFO file or, in case of a file handle, a pipe  (same as -p file test).

=cut

sub isFIFO {
    return S_ISFIFO($_[0]->mode);
}

*isPipe = *isFIFO;

=method isSocket

Returns true if the file is a socket file (same as -S file test).

=cut

sub isSocket {
    return S_ISSOCK($_[0]->mode);
}

=method -X operator

You can use the file test operators on the C<File::stat::Extra> object
just as you would on a file (handle). However, instead of querying the
file system, these operators will use the information from the
object itself.

The overloaded filetests are only supported from Perl version 5.12 and
higer. The named access to these tests can still be used though.

Note: in case of the special file tests C<-t>, C<-T>, and C<-B>, the
file (handle) I<is> tested the I<first> time the operator is
used. After the first time, the initial result is re-used.

=method Unary C<""> (stringification)

The unary C<""> (stringification) operator is overloaded to return the the device and inode
numbers separated by a C<.> (C<I<dev>.I<ino>>). This yields a uniqe file identifier (as string).

=method Comparison operators C<< <=> >>, C<cmp>, and C<~~>

The comparison operators use the string representation of the
C<File::stat::Extra> object. So, to see if two C<File::stat::Extra>
object point to the same (hardlinked) file, you can simply say
something like this:

    print 'Same file' if $ob1 == $ob2;

For objects created from an C<stat> of a symbolic link, the actual
I<destination> of the link is used in the comparison! If you want to
compare the actual symnlink file, use C<lstat> instead.

Note: All comparisons (also the numeric versions) are performed on the
full stringified versions of the object. This to prevent files on the
same device, but with an inode number ending in a zero to compare
equally while they aren't (e.g., 5.10 and 5.100 compare equal
numerically but denote a different file).

Note: the smartmatch C<~~> operator is obly overloaded on Perl version
5.10 and above.

=method Other operators

As the other operators (C<+>, C<->, C<*>, etc.) are meaningless, they
have not been overloaded and will cause a run-time error.

=cut

my %op = (
    # Use the named version of these tests
    f => sub { $_[0]->isRegular },
    d => sub { $_[0]->isDir },
    l => sub { $_[0]->isLink },
    p => sub { $_[0]->isFIFO },
    S => sub { $_[0]->isSocket },
    b => sub { $_[0]->isBlock },
    c => sub { $_[0]->isChar },

    # Defer implementation of rest to File::stat
    r => sub { -r $_[0][0] },
    w => sub { -w $_[0][0] },
    x => sub { -x $_[0][0] },
    o => sub { -o $_[0][0] },

    R => sub { -R $_[0][0] },
    W => sub { -W $_[0][0] },
    X => sub { -X $_[0][0] },
    O => sub { -O $_[0][0] },

    e => sub { -e $_[0][0] },
    z => sub { -z $_[0][0] },
    s => sub { -s $_[0][0] },

    u => sub { -u $_[0][0] },
    g => sub { -g $_[0][0] },
    k => sub { -k $_[0][0] },

    M => sub { -M $_[0][0] },
    C => sub { -C $_[0][0] },
    A => sub { -A $_[0][0] },

    # Implement these operators by testing the underlying file, caching the result
    t => sub { defined $_[0][2] ? $_[0][2] : $_[0][2] = (-t $_[0]->file) || 0 }, ## no critic (InputOutput::ProhibitInteractiveTest)
    T => sub { defined $_[0][3] ? $_[0][3] : $_[0][3] = (-T $_[0]->file) || 0 },
    B => sub { defined $_[0][4] ? $_[0][4] : $_[0][4] = (-B $_[0]->file) || 0 },
);

sub _filetest {
    my ($s, $op) = @_;
    if ($op{$op}) {
        return $op{$op}->($s);
    } else {
        # We should have everything covered so this is just a safegauard
        Carp::croak "-$op is not implemented on a File::stat::Extra object";
    }
}

sub _dev_ino {
    return $_[0]->dev . "." . $_[0]->ino;
}

sub _compare {
    my $va = shift;
    my $vb = shift;
    my $swapped = shift;
    ($vb, $va) = ($va, $vb) if $swapped;

    return "$va" cmp "$vb"; # Force stringification when comparing
}

use overload
    # File test operators (as of Perl v5.12)
    $^V >= 5.012 ? (-X => \&_filetest) : (),

    # Unary "" returns the object as "dev.ino", this should be a
    # unique string for each file.
    '""' => \&_dev_ino,

    # Comparison is done based on the unique string created with the stringification
    '<=>' => \&_compare,
    'cmp' => \&_compare,

    # Smartmatch as of Perl v5.10
    $^V >= 5.010 ? ('~~' => \&_compare) : (),

    ;

1;
