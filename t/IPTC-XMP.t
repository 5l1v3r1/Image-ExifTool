# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/IPTC-XMP.t'

######################### We start with some black magic to print on failure.

# Change "1..N" below to so that N matches last test number

BEGIN { $| = 1; print "1..7\n"; }
END {print "not ok 1\n" unless $loaded;}

# test 1: Load ExifTool
use Image::ExifTool 'ImageInfo';
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

use t::TestLib;

my $testname = 'IPTC-XMP';
my $testnum = 1;

# test 2: Extract information from IPTC-XMP.jpg
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/IPTC-XMP.jpg', {Duplicates => 1});
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Test GetValue() in list context
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->ExtractInfo('t/images/IPTC-XMP.jpg', {JoinLists => 0});
    my @values = $exifTool->GetValue('Keywords','ValueConv');
    my $values = join '-', @values;
    my $expected = 'ExifTool-Test-XMP';
    unless ($values eq $expected) {
        warn "\n  Test $testnum differs with \"$values\"\n";
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 4: Test rewriting everything
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(Duplicates => 1, Binary => 1, List => 1);
    my $info = $exifTool->ImageInfo('t/images/IPTC-XMP.jpg');
    my $tag;
    foreach $tag (keys %$info) {
        my $group = $exifTool->GetGroup($tag);
        my $val = $info->{$tag};
        my @values;
        if (ref $val eq 'ARRAY') {
            @values = @$val;
        } elsif (ref $val eq 'SCALAR') {
            @values = ( $$val );
        } else {
            @values = ( $val );
        }
        foreach $val (@values) {
            # eat return values so warning don't get printed
            my @rtns = $exifTool->SetNewValue($tag,$val,Group=>$group);
        }
    }
    # also test out an IPTC Core tag
    $exifTool->SetNewValue(CreatorContactInfoCiAdrCtry => 'Canada');
    undef $info;
    my $image;
    $exifTool->WriteInfo('t/images/IPTC-XMP.jpg',\$image);
    
    my $exifTool2 = new Image::ExifTool;
    $exifTool2->Options(Duplicates => 1);
    $info = $exifTool2->ImageInfo(\$image);
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    if (check($exifTool2, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        # save bad file
        open(TESTFILE,">$testfile");
        binmode(TESTFILE);
        print TESTFILE $image;
        close(TESTFILE);
        print 'not ';
    }
    print "ok $testnum\n";
}

# tests 5/6: Test extracting then reading XMP data as a block
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/IPTC-XMP.jpg','XMP');
    print 'not ' unless $$info{XMP};
    print "ok $testnum\n";

    ++$testnum;
    my $pass;
    if ($$info{XMP}) {
        $info = $exifTool->ImageInfo($$info{XMP});
        $pass = check($exifTool, $info, $testname, $testnum);
    }
    print 'not ' unless $pass;
    print "ok $testnum\n";
}

# test 7: Test copying information to a new XMP data file
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValuesFromFile('t/images/IPTC-XMP.jpg');
    my $testfile = "t/${testname}_${testnum}_failed.xmp";
    unlink $testfile;
    $exifTool->WriteInfo(undef,$testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# end
