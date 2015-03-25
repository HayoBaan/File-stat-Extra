#!perl
use strict;
use warnings;
use Test::More 0.96;

use File::stat::Extra;
use Cwd;
use File::Spec;

my $testfile = "corpus/testfile";
my $testlink = "corpus/testlink.tmp";

symlink "testfile", "$testlink"
    or die "Couldn't create symlink for $testlink: $!";

END {
    unlink("$testlink") or die "Unable to remove $testlink: $!" if $testlink && -l "$testlink";
}

plan tests => 29;

open FH, "<$testfile";
open FHL, "<$testlink";

my $st      = stat($testfile);
my @st      = stat($testfile);
my @_st     = CORE::stat($testfile);
my $stl     = stat($testlink);
my @stl     = stat($testlink);
my @_stl    = CORE::stat($testlink);
my $stfh    = stat(FH);
my @stfh    = stat(FH);
my @_stfh   = CORE::stat(FH);
my $stfhl   = stat(FHL);
my @stfhl   = stat(FHL);
my @_stfhl  = CORE::stat(FHL);
my $st_fh   = stat(*FH);
my @st_fh   = stat(*FH);
my @_st_fh  = CORE::stat(*FH);
my $st_fhl  = stat(*FHL);
my @st_fhl  = stat(*FHL);
my @_st_fhl = CORE::stat(*FHL);

my $lst     = lstat($testfile);
my @lst     = lstat($testfile);
my @l_st    = CORE::lstat($testfile);
my $lstl    = lstat($testlink);
my @lstl    = lstat($testlink);
my @l_stl   = CORE::lstat($testlink);

is_deeply \@st,     \@_st,     'List context should return same result as original stat for file';
is_deeply \@stl,    \@_stl,    'List context should return same result as original stat for link';
is_deeply \@stfh,   \@_stfh,   'List context should return same result as original stat for file handle';
is_deeply \@stfhl,  \@_stfhl,  'List context should return same result as original stat for link file handle';
is_deeply \@st_fh,  \@_st_fh,  'List context should return same result as original stat for *file handle';
is_deeply \@st_fhl, \@_st_fhl, 'List context should return same result as original stat for *link file handle';

is_deeply \@lst,    \@l_st,    'List context should return same result as original lstat for file';
is_deeply \@lstl,   \@l_stl,   'List context should return same result as original lstat for link';

is_deeply \@stfh,   \@st,      'File handle returns same as normal file';
is_deeply \@st_fh,  \@st,      '*File handle returns same as normal file';
is_deeply \@stfhl,  \@st,      'Link file handle returns same as normal file';
is_deeply \@st_fhl, \@st,      '*Link file handle returns same as normal file';

is_deeply [
    $st->dev, $st->ino, $st->mode, $st->nlink,
    $st->uid, $st->gid, $st->rdev, $st->size,
    $st->atime, $st->mtime, $st->ctime,
    $st->blksize, $st->blocks
], \@_st, 'Accessors return same results as original stat';

is_deeply [
    $lst->dev, $lst->ino, $lst->mode, $lst->nlink,
    $lst->uid, $lst->gid, $lst->rdev, $lst->size,
    $lst->atime, $lst->mtime, $lst->ctime,
    $lst->blksize, $lst->blocks
], \@l_st, 'Accessors return same results as original lstat of file';

ok(!$st->isLink,  'Not a link for a stat on file');
ok(!$stl->isLink, 'Not a link for a stat on link');
ok(!$lst->isLink, 'Not a link for an lstat on file');
ok($lstl->isLink, 'Is a link for an lstat on link');

is $st->permissions, $_st[2] & 07777, 'Permissions Ok';
is $st->filetype, $_st[2] & 0770000, 'Type Ok';
is $st->file, File::Spec->rel2abs($testfile), 'File is testfile';
is $lst->target, Cwd::abs_path($testfile), 'Link target is testfile';
is $st->target, $st->file, 'File target same as file';
ok($st->isRegular, 'Testfile a regular file');
ok((stat('corpus'))->isDir, 'Corpus is a directory');

ok($st == $stl, 'testfile and resolved testlink represent the same file (numeric test)');
ok($st eq $stl, 'testfile and resolved testlink represent the same file (string test)');
ok($st != $lstl, 'testfile and unresolved testlink do not represent the same file (numeric test)');
ok($st ne $lstl, 'testfile and unresolved testlink do not represent the same file (string test)');
