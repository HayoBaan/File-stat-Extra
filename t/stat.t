#!perl
use strict;
use warnings;
use Test::More 0.96;

use File::stat::Extra;
use Cwd;
use File::Spec;

my $testfile = "corpus/testfile";
my $testlink;

if (eval { symlink('',''); 1 }) {
    # Create symlink
    $testlink = "corpus/testlink.tmp";
    symlink "testfile", "$testlink" or die "Couldn't create symlink $testlink for $testfile: $!";
}

END {
    # Remove symlink
    unlink("$testlink") or die "Unable to remove $testlink: $!" if $testlink && -l "$testlink";
}

sub diagnose {
    my $st = shift;

    my $txt = sprintf "File=%s, dev=%d, ino=%d,\nmode=%06o (type=%06o, perms=%06o),\nnlink=%d, uid=%s, gid=%s, rdev=%s, size=%d,\natime=%s, mtime=%s, ctime=%s,\nblksize=%d, blocks=%d\n", $st->file, $st->dev, $st->ino, $st->mode, $st->filetype, $st->permissions, $st->nlink,
        $st->uid, $st->gid, $st->rdev, $st->size,
        scalar localtime($st->atime), scalar localtime($st->mtime), scalar localtime($st->ctime),
        $st->blksize, $st->blocks;
    return diag ($txt, explain $st);
}

sub main_tests {
    my $file = shift;
    my $type = shift // "";

    plan skip_all => "Skipped: $type not supported by OS" if !$file;

    $type = " ($type)" if $type;

    open FH, "<$file" or die "Unable to open $file$type";

    my $st      = stat($file);
    my @st      = stat($file);
    my @_st     = CORE::stat($file);

    my $stfh    = stat(FH);
    my @stfh    = stat(FH);
    my @_stfh   = CORE::stat(FH);

    my $st_fh   = stat(*FH);
    my @st_fh   = stat(*FH);
    my @_st_fh  = CORE::stat(*FH);

    my $lst     = lstat($file);
    my @lst     = lstat($file);
    my @l_st    = CORE::lstat($file);

    is_deeply \@st,     \@_st,     "List context should return same result as original stat for file$type";
    is_deeply \@stfh,   \@_stfh,   "List context should return same result as original stat for file handle$type";
    is_deeply \@st_fh,  \@_st_fh,  "List context should return same result as original stat for *file handle$type";
    is_deeply \@lst,    \@l_st,    "List context should return same result as original lstat for file$type";
    is_deeply \@stfh,   \@st,      "List context should return same result for file handle as for file$type";
    is_deeply \@st_fh,  \@st,      "List context should return same result for *file handle as for file$type";

    is_deeply [
        $st->dev, $st->ino, $st->mode, $st->nlink,
        $st->uid, $st->gid, $st->rdev, $st->size,
        $st->atime, $st->mtime, $st->ctime,
        $st->blksize, $st->blocks
    ], \@_st, "Accessors should return same results as original stat of file$type";

    is_deeply [
        $lst->dev, $lst->ino, $lst->mode, $lst->nlink,
        $lst->uid, $lst->gid, $lst->rdev, $lst->size,
        $lst->atime, $lst->mtime, $lst->ctime,
        $lst->blksize, $lst->blocks
    ], \@l_st, "Accessors return same results as original lstat of file$type";

    is $st->permissions, $_st[2] & 07777, "Permissions Ok$type";
    is $st->filetype,  $_st[2] & 0770000, "Type Ok$type";

    is $st->file, File::Spec->rel2abs($file), "File$type points to same file (relative)";
    is $st->target, Cwd::abs_path($testfile), "Target$type points to same file (absolute)";
}

plan tests => 4;

subtest "Main tests on a file" => sub { main_tests($testfile); };

subtest "Additional tests on a file and directory" => sub {
    my $st  = stat($testfile);
    my $std = stat('corpus');

    ok(-f $testfile,   'testfile is a regular file (normal filetest)');
    ok($st->isRegular, 'testfile is a regular file (object)') or diagnose($st);
    ok(-f $st,         'testfile is a regular file (object filetest)') or diagnose($st);
    ok(-d "corpus",    'corpus is a directory (normal filetest)');
    ok($std->isDir,    'corpus is a directory') or diagnose($std);
    ok(-d $std,        'corpus is a directory (object filetest)') or diagnose($std);
};

subtest "Main tests on a link" => sub { main_tests($testlink, "symlink"); };

subtest "More link tetsts" => sub {
    plan skip_all => "Skipped: symlink not supported by OS" if !$testlink;

    my $st  = stat($testfile);
    my $lst = lstat($testfile);

    my $stl = stat($testlink);
    my $lstl = lstat($testlink);

    ok(!$st->isLink,  'testfile is not a link (stat)') or diagnose($st);
    ok(!$stl->isLink, 'testlink is not a link (stat)') or diagnose($stl);
    ok(!$lst->isLink, 'testfile is not a link for an lstat on file(lstat)') or diagnose($lst);
    ok(-l $testlink,  'testlink is a link (filetest)') or diagnose($lstl);
    ok($lstl->isLink, 'testlink is a link (lstat)') or diagnose($lstl);
    ok(-l $lstl,      'testlink is a link (lstat, object filetest)') or diagnose($lstl);

    ok($st == $stl,  'testfile and resolved testlink represent the same file (numeric test)');
    ok($st eq $stl,  'testfile and resolved testlink represent the same file (string test)');
    ok($st != $lstl, 'testfile and unresolved testlink do not represent the same file (numeric test)');
    ok($st ne $lstl, 'testfile and unresolved testlink do not represent the same file (string test)');
};

