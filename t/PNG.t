# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/PNG.t'

######################### We start with some black magic to print on failure.

# Change "1..N" below to so that N matches last test number

BEGIN { $| = 1; print "1..3\n"; }
END {print "not ok 1\n" unless $loaded;}

# test 1: Load ExifTool
use Image::ExifTool 'ImageInfo';
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

use t::TestLib;

my $testname = 'PNG';
my $testnum = 1;

# test 2: Extract information from PNG.png
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/PNG.png');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write a bunch of new information to the PNG
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValuesFromFile('t/images/IPTC-XMP.jpg');
    # must write image to memory because size is variable (depends on Zlib
    # availability), and images in memory don't generate a 'FileSize' tag.
    my $image;  
    my $rtnVal = $exifTool->WriteInfo('t/images/PNG.png', \$image);
    my $info = $exifTool->ImageInfo(\$image);
    my $testfile = "t/${testname}_${testnum}_failed.png";
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;   # erase results of any bad test
    } else {
        # save the bad image
        open(TESTFILE,">$testfile");
        binmode(TESTFILE);
        print TESTFILE $image;
        close(TESTFILE);
        print 'not ';
    }
    print "ok $testnum\n";
}

# end
