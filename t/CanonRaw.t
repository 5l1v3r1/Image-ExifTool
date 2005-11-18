# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/CanonRaw.t'

######################### We start with some black magic to print on failure.

# Change "1..N" below to so that N matches last test number

BEGIN { $| = 1; print "1..6\n"; }
END {print "not ok 1\n" unless $loaded;}

# test 1: Load ExifTool
use Image::ExifTool 'ImageInfo';
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

use t::TestLib;

my $testname = 'CanonRaw';
my $testnum = 1;

# test 2: Extract information from CRW
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/CanonRaw.crw');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Extract JpgFromRaw from CRW
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(PrintConv => 0, IgnoreMinorErrors => 1);
    my $info = $exifTool->ImageInfo('t/images/CanonRaw.crw','JpgFromRaw');
    print 'not ' unless ${$info->{JpgFromRaw}} eq '<Dummy JpgFromRaw image data>';
    print "ok $testnum\n";
}

# test 4: Write a whole pile of tags to a CRW
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    # set IgnoreMinorErrors option to allow invalid JpgFromRaw to be written
    $exifTool->Options(IgnoreMinorErrors => 1);
    $exifTool->SetNewValuesFromFile('t/images/ExifTool.jpg');
    $exifTool->SetNewValue(SerialNumber => 1234);
    $exifTool->SetNewValue(OwnerName => 'Phil Harvey');
    $exifTool->SetNewValue(JpgFromRaw => 'not a real image');
    $exifTool->SetNewValue(ROMOperationMode => 'CDN');
    $exifTool->SetNewValue(FocalPlaneXSize => '35mm');
    my $testfile = "t/${testname}_${testnum}_failed.crw";
    unlink $testfile;
    $exifTool->WriteInfo('t/images/CanonRaw.crw', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 5: Test verbose output
{
    ++$testnum;
    my ($ok, $skip) = testVerbose($testname, $testnum, 't/images/CanonRaw.crw', 1);
    print 'not ' unless $ok;
    print "ok $testnum$skip\n";
}

# test 6: Write to CR2 file
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    # set IgnoreMinorErrors option to allow invalid JpgFromRaw to be written
    $exifTool->SetNewValue(Keywords => 'CR2 test');
    $exifTool->SetNewValue(OwnerName => 'Phil Harvey');
    $exifTool->SetNewValue(FocalPlaneXSize => '35mm');
    my $testfile = "t/${testname}_${testnum}_failed.cr2";
    unlink $testfile;
    $exifTool->WriteInfo('t/images/CanonRaw.cr2', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    my $success = check($exifTool, $info, $testname, $testnum);
    # make sure file suffix was copied properly
    while ($success) {
        open(TESTFILE, $testfile) or last;
        binmode(TESTFILE);
        my $endStr = '<Dummy preview image data>Non-TIFF data test';
        my $len = length $endStr;
        seek(TESTFILE, -$len, 2) or last;
        my $buff;
        read(TESTFILE, $buff, $len) == $len or last;
        close(TESTFILE);
        if ($buff eq $endStr) {
            unlink $testfile;
            $success = 2;
        } else {
            warn "\n  Test $testnum failed to copy file suffix:\n";
            warn "    Test gave: '$buff'\n";
            warn "    Should be: '$endStr'\n";
            $success = 0;
        }
        last;
    }
    warn "\n  Test $testnum: Error reading file suffix\n" if $success == 1;
    print 'not ' unless $success == 2;
    print "ok $testnum\n";
}

# end
